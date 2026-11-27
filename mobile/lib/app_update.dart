import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'blog_surface.dart';
import 'delayed_loading.dart';
import 'update_transport.dart';
import 'wiki_motion.dart';

enum UpdatePhase {
  idle,
  checking,
  current,
  available,
  downloading,
  verifying,
  ready,
  installing,
  permission,
  checkFailed,
  downloadFailed,
  installFailed,
  invalidPackage,
  unsupported,
  differentSignature,
}

enum UpdateIneligible implements Exception { architecture, signature }

class UpdateArtifact {
  const UpdateArtifact({
    required this.name,
    required this.versionCode,
    required this.size,
    required this.uri,
    required this.sha256,
    required this.notes,
  });

  final String name;
  final int versionCode;
  final int size;
  final Uri uri;
  final String sha256;
  final String notes;

  static UpdateArtifact? select(
    Object? decoded,
    Uri manifest,
    String packageName,
    List<String> abis,
    int sdk,
    int installedVersion,
    String installedSigner,
  ) {
    if (decoded is! Map ||
        decoded['schemaVersion'] != 1 ||
        decoded['packageName'] != packageName ||
        decoded['signerSha256'] is! String ||
        decoded['versionName'] is! String ||
        decoded['notes'] is! String ||
        decoded['artifacts'] is! Map) {
      throw const FormatException('Invalid update manifest');
    }
    final signer = decoded['signerSha256'] as String;
    final name = decoded['versionName'] as String;
    final notes = decoded['notes'] as String;
    if (name.isEmpty ||
        name.length > 50 ||
        notes.length > 6000 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(signer)) {
      throw const FormatException('Invalid release metadata');
    }
    final artifacts = decoded['artifacts'] as Map;
    for (final abi in abis) {
      if (!artifacts.containsKey(abi)) continue;
      final entry = artifacts[abi];
      if (entry is! Map) throw const FormatException('Invalid APK entry');
      final version = entry['versionCode'];
      final minSdk = entry['minSdk'];
      final size = entry['size'];
      final hash = entry['sha256'];
      final url = entry['url'];
      final uri = url is String ? Uri.tryParse(url) : null;
      if (version is! int ||
          version <= 0 ||
          version > 2100000000 ||
          minSdk is! int ||
          minSdk <= 0 ||
          size is! int ||
          size <= 0 ||
          size > 512 * 1024 * 1024 ||
          hash is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
          uri == null ||
          !uri.hasAuthority ||
          uri.scheme != manifest.scheme ||
          uri.authority != manifest.authority ||
          uri.hasQuery ||
          uri.hasFragment ||
          !uri.path.startsWith(manifest.resolve('.').path) ||
          !uri.path.endsWith('.apk')) {
        throw const FormatException('Invalid APK metadata');
      }
      if (minSdk > sdk) continue;
      if (version < installedVersion) return null;
      if (signer != installedSigner) {
        throw UpdateIneligible.signature;
      }
      if (version == installedVersion) return null;
      return UpdateArtifact(
        name: name,
        versionCode: version,
        size: size,
        uri: uri,
        sha256: hash,
        notes: notes.trim(),
      );
    }
    throw UpdateIneligible.architecture;
  }
}

class WikiUpdater extends ChangeNotifier {
  WikiUpdater({Uri? manifest, HttpClient Function()? client})
    : _manifest =
          manifest ?? Uri.parse('https://download.wust.club/wiki/latest.json'),
      _newClient = client ?? HttpClient.new;

  static const _platform = MethodChannel('wiki/native');
  static final _partialName = RegExp(
    r'[/\\]wiki-update(?:-[a-f0-9]{64})?\.part$',
  );
  final Uri _manifest;
  final HttpClient Function() _newClient;
  Future<Map<String, dynamic>?>? _device;
  HttpClient? _download;
  bool _cancelled = false;
  bool _disposed = false;
  bool _autoStarted = false;
  UpdatePhase phase = UpdatePhase.idle;
  UpdateArtifact? release;
  String? installedName;
  int received = 0;

  static File _partialFile(Directory directory, UpdateArtifact artifact) =>
      File.fromUri(
        directory.uri.resolve('wiki-update-${artifact.sha256}.part'),
      );

  static Future<int> _savedLength(File partial, int size) async {
    final stat = await partial.stat();
    return stat.type == FileSystemEntityType.file && stat.size <= size
        ? stat.size
        : 0;
  }

  Future<Map<String, dynamic>?> _loadDevice() async {
    try {
      final device = await _platform.invokeMapMethod<String, dynamic>(
        'wikiUpdateInfo',
      );
      installedName = device?['versionName'] as String?;
      if (!_disposed) notifyListeners();
      return device;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void _set(UpdatePhase next) {
    if (_disposed) return;
    phase = next;
    notifyListeners();
  }

  Future<bool> checkAutomatically() async {
    if (_autoStarted) return false;
    _autoStarted = true;
    final device = await (_device ??= _loadDevice());
    if (_disposed ||
        device?['autoCheckDue'] != true ||
        phase != UpdatePhase.idle) {
      return false;
    }
    return check(quiet: true);
  }

  Future<bool> check({bool quiet = false}) async {
    if (phase == UpdatePhase.checking ||
        phase == UpdatePhase.downloading ||
        phase == UpdatePhase.verifying ||
        phase == UpdatePhase.installing ||
        _disposed) {
      return false;
    }
    _set(UpdatePhase.checking);
    final device = await (_device ??= _loadDevice());
    if (device == null || _disposed) {
      _set(quiet ? UpdatePhase.idle : UpdatePhase.checkFailed);
      return false;
    }
    final client = _newClient()..connectionTimeout = updateNetworkTimeout;
    try {
      await _platform.invokeMethod<void>('recordWikiUpdateCheck');
      final response = await openUpdateResponse(client, _manifest);
      final body = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(updateNetworkTimeout)) {
        if (body.length + chunk.length > 32 * 1024) {
          throw const FormatException('Manifest is too large');
        }
        body.add(chunk);
      }
      final artifact = UpdateArtifact.select(
        jsonDecode(utf8.decode(body.takeBytes())),
        _manifest,
        device['packageName'] as String,
        (device['abis'] as List).cast<String>(),
        device['sdk'] as int,
        device['versionCode'] as int,
        device['signerSha256'] as String,
      );
      received = artifact == null
          ? 0
          : await _savedLength(
              _partialFile(
                Directory(device['cacheDirectory'] as String),
                artifact,
              ),
              artifact.size,
            );
      release = artifact;
      _set(artifact == null ? UpdatePhase.current : UpdatePhase.available);
      return !_disposed && artifact != null;
    } on UpdateIneligible catch (reason) {
      _set(
        quiet
            ? UpdatePhase.idle
            : switch (reason) {
                UpdateIneligible.architecture => UpdatePhase.unsupported,
                UpdateIneligible.signature => UpdatePhase.differentSignature,
              },
      );
      return false;
    } on Exception {
      _set(quiet ? UpdatePhase.idle : UpdatePhase.checkFailed);
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> download() async {
    final artifact = release;
    if (artifact == null ||
        _disposed ||
        _download != null ||
        !const {
          UpdatePhase.available,
          UpdatePhase.downloadFailed,
          UpdatePhase.invalidPackage,
        }.contains(phase)) {
      return;
    }
    final restart = phase == UpdatePhase.invalidPackage;
    if (restart) received = 0;
    _cancelled = false;
    final client = _newClient()..connectionTimeout = updateNetworkTimeout;
    _download = client;
    _set(UpdatePhase.downloading);
    File? partial;
    var outcome = UpdatePhase.downloadFailed;
    try {
      final device = (await _device)!;
      final directory = Directory(device['cacheDirectory'] as String);
      await directory.create(recursive: true);
      partial = _partialFile(directory, artifact);
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is File &&
            entry.path != partial.path &&
            _partialName.hasMatch(entry.path)) {
          await entry.delete();
        }
      }
      received = restart ? 0 : await _savedLength(partial, artifact.size);
      if (_cancelled || _disposed) return;
      if (received < artifact.size) {
        await _writeApk(client, partial, artifact);
      }
      if (_cancelled || _disposed) return;
      if (received != artifact.size) {
        throw const HttpException('APK download interrupted');
      }
      _set(UpdatePhase.verifying);
      if ((await sha256.bind(partial.openRead()).first).toString() !=
          artifact.sha256) {
        throw const FormatException('APK digest mismatch');
      }
      await partial.rename('${directory.path}/wiki-update.apk');
      outcome = UpdatePhase.ready;
    } on FormatException {
      outcome = UpdatePhase.invalidPackage;
      received = 0;
      if (partial != null) {
        try {
          await partial.delete();
        } on FileSystemException {
          // A subsequent retry starts from zero even if deletion failed.
        }
      }
    } on Exception {
      outcome = UpdatePhase.downloadFailed;
    } finally {
      client.close(force: true);
      _download = null;
      _set(_cancelled ? UpdatePhase.available : outcome);
    }
  }

  Future<void> _writeApk(
    HttpClient client,
    File partial,
    UpdateArtifact artifact,
  ) async {
    final (:response, :start) = await openApkResponse(
      client,
      artifact.uri,
      offset: received,
      size: artifact.size,
    );
    if (_cancelled || _disposed) return;
    final output = await partial.open(
      mode: start == 0 ? FileMode.write : FileMode.append,
    );
    try {
      received = start;
      var lastProgress = received;
      if (!_disposed) notifyListeners();
      await for (final chunk in response.timeout(updateNetworkTimeout)) {
        if (_cancelled || _disposed) break;
        if (received + chunk.length > artifact.size) {
          throw const FormatException('APK is too large');
        }
        await output.writeFrom(chunk);
        received += chunk.length;
        if (!_disposed &&
            (received - lastProgress >= 256 * 1024 ||
                received == artifact.size)) {
          lastProgress = received;
          notifyListeners();
        }
      }
    } finally {
      await output.close();
    }
  }

  void cancel() {
    if (phase != UpdatePhase.downloading) return;
    _cancelled = true;
    _download?.close(force: true);
  }

  Future<void> install({bool openSettings = false}) async {
    final artifact = release;
    if (artifact == null ||
        !const {
          UpdatePhase.ready,
          UpdatePhase.permission,
          UpdatePhase.installFailed,
        }.contains(phase)) {
      return;
    }
    _set(UpdatePhase.installing);
    try {
      final result = await _platform.invokeMethod<String>('installWikiUpdate', {
        'versionCode': artifact.versionCode,
        'openSettings': openSettings,
      });
      _set(switch (result) {
        'opened' => UpdatePhase.ready,
        'permission' => UpdatePhase.permission,
        'invalidPackage' => UpdatePhase.invalidPackage,
        _ => UpdatePhase.installFailed,
      });
    } on Exception {
      _set(UpdatePhase.installFailed);
    }
  }

  @override
  void dispose() {
    _download?.close(force: true);
    _disposed = true;
    super.dispose();
  }
}

class AppUpdateTile extends StatelessWidget {
  const AppUpdateTile(this.updater, {super.key});

  final WikiUpdater updater;

  static void open(BuildContext context, WikiUpdater updater) {
    if (updater.release == null && updater.phase != UpdatePhase.checking) {
      unawaited(updater.check());
    }
    showWikiSheet<void>(context, (_) => _AppUpdateSheet(updater));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updater,
    builder: (context, _) => WikiMenuTile(
      leading: const BlogIcon(Icons.system_update_outlined),
      label: '检查更新',
      detail: switch ((updater.release, updater.installedName)) {
        (final release?, _) => Text(
          '新版 ${release.name}',
          style: TextStyle(color: blogTint(context, 220)),
        ),
        (_, final name?) => Text(
          name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        _ => null,
      },
      onTap: () => open(context, updater),
    ),
  );
}

class _AppUpdateSheet extends StatelessWidget {
  const _AppUpdateSheet(this.updater);

  final WikiUpdater updater;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updater,
    builder: (context, _) {
      final phase = updater.phase;
      final release = updater.release;
      final theme = Theme.of(context);
      final hasProgress = release != null && updater.received > 0;
      final showProgress =
          phase == UpdatePhase.downloading ||
          (hasProgress &&
              (phase == UpdatePhase.available ||
                  phase == UpdatePhase.downloadFailed));
      final title = switch (phase) {
        UpdatePhase.checking => '检查更新',
        UpdatePhase.current => '已是最新版本',
        UpdatePhase.checkFailed => '检查失败',
        UpdatePhase.unsupported => '暂无适配当前设备的新版本',
        UpdatePhase.differentSignature => '当前版本需要手动升级',
        _ => release == null ? '检查更新' : '新版 ${release.name}',
      };
      final status = switch (phase) {
        UpdatePhase.available when hasProgress => '下载已暂停',
        UpdatePhase.downloading => '正在下载',
        UpdatePhase.ready => '下载完成',
        UpdatePhase.installing => '正在打开安装程序',
        UpdatePhase.permission => '允许 Wiki 安装应用后即可继续',
        UpdatePhase.differentSignature => '新版使用了不同的签名，需要手动安装。',
        UpdatePhase.downloadFailed => hasProgress ? '下载中断' : '下载失败',
        UpdatePhase.installFailed => '无法打开安装程序',
        UpdatePhase.invalidPackage => '安装包校验失败',
        _ => null,
      };
      final (label, action) = switch (phase) {
        UpdatePhase.available || UpdatePhase.downloadFailed when hasProgress =>
          ('继续下载', updater.download),
        UpdatePhase.available => ('下载更新', updater.download),
        UpdatePhase.ready => ('安装更新', updater.install),
        UpdatePhase.permission => (
          '前往设置',
          () => updater.install(openSettings: true),
        ),
        UpdatePhase.checkFailed => ('重试', updater.check),
        UpdatePhase.downloadFailed => ('重试下载', updater.download),
        UpdatePhase.invalidPackage => ('重新下载', updater.download),
        UpdatePhase.installFailed => ('重试安装', updater.install),
        _ => (null, null),
      };
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (release != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${(release.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (release.notes.isNotEmpty &&
                    phase == UpdatePhase.available) ...[
                  const SizedBox(height: 16),
                  Text(release.notes),
                ],
              ] else if (updater.installedName case final name?) ...[
                const SizedBox(height: 8),
                Text('当前版本 ${name}'),
              ],
              if (phase == UpdatePhase.checking ||
                  phase == UpdatePhase.verifying)
                DelayedLoading(
                  key: ValueKey(phase),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(
                      semanticsLabel: phase == UpdatePhase.checking
                          ? '正在检查更新'
                          : '正在校验安装包',
                    ),
                  ),
                ),
              if (status != null) ...[
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: WikiMotion.reduced(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  child: Column(
                    key: ValueKey(phase),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status, semanticsLabel: status),
                      if (showProgress && release != null) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (updater.received / release.size).clamp(
                            0.0,
                            1.0,
                          ),
                          semanticsLabel: '下载进度',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (phase == UpdatePhase.downloading) {
                          updater.cancel();
                          return;
                        }
                        Navigator.pop(context);
                      },
                      child: Text(switch (phase) {
                        UpdatePhase.downloading => '暂停下载',
                        UpdatePhase.available => '稍后',
                        _ => '关闭',
                      }),
                    ),
                    if (label != null && action != null)
                      FilledButton(onPressed: action, child: Text(label)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
