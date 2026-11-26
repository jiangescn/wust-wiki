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
      release = UpdateArtifact.select(
        jsonDecode(utf8.decode(body.takeBytes())),
        _manifest,
        device['packageName'] as String,
        (device['abis'] as List).cast<String>(),
        device['sdk'] as int,
        device['versionCode'] as int,
        device['signerSha256'] as String,
      );
      _set(release == null ? UpdatePhase.current : UpdatePhase.available);
      return !_disposed && release != null;
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
        _download != null ||
        !const {
          UpdatePhase.available,
          UpdatePhase.downloadFailed,
          UpdatePhase.invalidPackage,
        }.contains(phase)) {
      return;
    }
    received = 0;
    _cancelled = false;
    _set(UpdatePhase.downloading);
    final client = _newClient()..connectionTimeout = updateNetworkTimeout;
    _download = client;
    File? partial;
    try {
      final device = (await _device)!;
      final directory = Directory(device['cacheDirectory'] as String);
      await directory.create(recursive: true);
      if (_cancelled || _disposed) return;
      partial = File('${directory.path}/wiki-update.part');
      final response = await openUpdateResponse(client, artifact.uri);
      if (response.contentLength >= 0 &&
          response.contentLength != artifact.size) {
        throw const FormatException('APK size mismatch');
      }
      final output = await partial.open(mode: FileMode.write);
      var lastProgress = 0;
      try {
        await for (final chunk in response.timeout(updateNetworkTimeout)) {
          if (_cancelled) break;
          received += chunk.length;
          if (received > artifact.size) {
            throw const FormatException('APK is too large');
          }
          await output.writeFrom(chunk);
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
      if (_cancelled || _disposed) return;
      _set(UpdatePhase.verifying);
      if (received != artifact.size ||
          (await sha256.bind(partial.openRead()).first).toString() !=
              artifact.sha256) {
        _set(UpdatePhase.invalidPackage);
        return;
      }
      await partial.rename('${directory.path}/wiki-update.apk');
      _set(UpdatePhase.ready);
    } on FormatException {
      _set(UpdatePhase.invalidPackage);
    } on Exception {
      if (!_cancelled) _set(UpdatePhase.downloadFailed);
    } finally {
      _download = null;
      client.close(force: true);
      if (partial != null) {
        try {
          await partial.delete();
        } on FileSystemException {
          // Successful downloads already moved the temporary file.
        }
      }
      if (_cancelled) _set(UpdatePhase.available);
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
      final title = switch (phase) {
        UpdatePhase.checking => '检查更新',
        UpdatePhase.current => '已是最新版本',
        UpdatePhase.checkFailed => '检查失败',
        UpdatePhase.unsupported => '暂无适配当前设备的新版本',
        UpdatePhase.differentSignature => '当前版本需要手动升级',
        _ => release == null ? '检查更新' : '新版 ${release.name}',
      };
      final status = switch (phase) {
        UpdatePhase.downloading => '正在下载',
        UpdatePhase.ready => '下载完成',
        UpdatePhase.installing => '正在打开安装程序',
        UpdatePhase.permission => '允许 Wiki 安装应用后即可继续',
        UpdatePhase.differentSignature => '新版使用了不同的签名，需要手动安装。',
        UpdatePhase.downloadFailed => '下载失败',
        UpdatePhase.installFailed => '无法打开安装程序',
        UpdatePhase.invalidPackage => '安装包校验失败',
        _ => null,
      };
      final (label, action) = switch (phase) {
        UpdatePhase.available => ('下载更新', updater.download),
        UpdatePhase.ready => ('安装更新', updater.install),
        UpdatePhase.permission => (
          '前往设置',
          () => updater.install(openSettings: true),
        ),
        UpdatePhase.checkFailed => ('重试', updater.check),
        UpdatePhase.downloadFailed ||
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
                      if (phase == UpdatePhase.downloading &&
                          release != null) ...[
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
                        if (phase == UpdatePhase.downloading) updater.cancel();
                        Navigator.pop(context);
                      },
                      child: Text(switch (phase) {
                        UpdatePhase.downloading => '取消下载',
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
