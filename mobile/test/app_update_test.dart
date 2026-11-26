import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/app_update.dart';

class _HttpFixture extends HttpOverrides {}

const _signer =
    '1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a';
const _package = 'com.wustacm.wiki';
const _channel = MethodChannel('wiki/native');
final _payload = utf8.encode('test APK contents');

Map<String, Object> manifest(Uri uri) {
  Map<String, Object> entry(String abi, int version) => {
    'versionCode': version,
    'minSdk': 24,
    'size': _payload.length,
    'url': uri.resolve('0.6.11/$abi.apk').toString(),
    'sha256': sha256.convert(_payload).toString(),
  };
  return {
    'schemaVersion': 1,
    'packageName': _package,
    'versionName': '0.6.11',
    'signerSha256': _signer,
    'notes': '测试版本',
    'artifacts': {
      'arm64-v8a': entry('arm64-v8a', 2036),
      'x86_64': entry('x86_64', 4036),
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compares the installed version with the matching ABI', () {
    final uri = Uri.parse('https://download.wust.club/wiki/latest.json');
    final metadata = manifest(uri);
    expect(
      UpdateArtifact.select(
        metadata,
        uri,
        _package,
        ['arm64-v8a'],
        36,
        2035,
        _signer,
      )?.versionCode,
      2036,
    );
    expect(
      UpdateArtifact.select(
        metadata,
        uri,
        _package,
        ['x86_64', 'arm64-v8a'],
        36,
        4036,
        _signer,
      ),
      isNull,
    );
    expect(
      () => UpdateArtifact.select(
        metadata,
        uri,
        _package,
        ['arm64-v8a'],
        36,
        2036,
        'other',
      ),
      throwsA(UpdateIneligible.signature),
    );
    expect(
      () => UpdateArtifact.select(
        metadata,
        uri,
        _package,
        ['armeabi-v7a'],
        36,
        1000,
        _signer,
      ),
      throwsA(UpdateIneligible.architecture),
    );
  });

  test('downloads, verifies, and hands off only a complete APK', () async {
    final directory = await Directory.systemTemp.createTemp('wiki-update-test');
    addTearDown(() => directory.delete(recursive: true));
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final uri = Uri.parse('http://127.0.0.1:${server.port}/wiki/latest.json');
    var corrupt = true;
    var checks = 0;
    final delayedDownload = Completer<void>();
    var delayPackage = false;
    server.listen((request) async {
      if (request.uri.path.endsWith('latest.json')) {
        request.response.write(jsonEncode(manifest(uri)));
      } else {
        if (delayPackage) await delayedDownload.future;
        final body = [..._payload];
        if (corrupt) body[0] ^= 1;
        request.response.contentLength = body.length;
        request.response.add(body);
      }
      await request.response.close();
    });

    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (call.method == 'recordWikiUpdateCheck') checks++;
      return switch (call.method) {
        'wikiUpdateInfo' => {
          'packageName': _package,
          'versionName': '0.6.10',
          'versionCode': 2035,
          'signerSha256': _signer,
          'autoCheckDue': true,
          'sdk': 36,
          'abis': ['arm64-v8a'],
          'cacheDirectory': directory.path,
        },
        'recordWikiUpdateCheck' => null,
        'installWikiUpdate' =>
          call.arguments['openSettings'] == true ? 'opened' : 'permission',
        _ => throw MissingPluginException(call.method),
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
    final updater = WikiUpdater(
      manifest: uri,
      client: () => _HttpFixture().createHttpClient(null),
    );
    addTearDown(updater.dispose);

    expect(await updater.checkAutomatically(), isTrue);
    expect(await updater.checkAutomatically(), isFalse);
    expect(checks, 1);
    expect(updater.phase, UpdatePhase.available);
    expect(updater.installedName, '0.6.10');

    delayPackage = true;
    final downloading = updater.download();
    expect(updater.phase, UpdatePhase.downloading);
    updater.cancel();
    delayedDownload.complete();
    await downloading;
    expect(updater.phase, UpdatePhase.available);
    delayPackage = false;

    await updater.download();
    expect(updater.phase, UpdatePhase.invalidPackage);
    expect(await File('${directory.path}/wiki-update.apk').exists(), isFalse);
    expect(await File('${directory.path}/wiki-update.part').exists(), isFalse);

    corrupt = false;
    await updater.download();
    expect(updater.phase, UpdatePhase.ready);
    expect(
      await File('${directory.path}/wiki-update.apk').readAsBytes(),
      _payload,
    );
    await updater.install();
    expect(updater.phase, UpdatePhase.permission);
    await updater.install(openSettings: true);
    expect(updater.phase, UpdatePhase.ready);
    final installCalls = calls.where(
      (call) => call.method == 'installWikiUpdate',
    );
    expect(installCalls.map((call) => call.arguments['versionCode']), [
      2036,
      2036,
    ]);
  });
}
