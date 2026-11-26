import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/foundation/auth.dart';
import 'package:wust_wiki/foundation/platform.dart';
import 'package:wust_wiki/foundation/transport.dart';

class MemoryPlatform implements FoundationPlatform {
  final values = <String, String>{};
  final loads = <String>[];
  @override
  Future<String?> load(String key) async {
    loads.add(key);
    return values[key];
  }

  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> clear(String key) async {
    values.remove(key);
  }

  @override
  Future<Map<String, dynamic>> invoke(
    String operation, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    if (operation == 'saveAccount') {
      values['password:${arguments['username']}'] = arguments['password'];
      values['active-account'] = arguments['username'];
    } else if (operation == 'clearAccount') {
      final account = arguments['username'];
      for (final prefix in [
        'password:',
        'session:',
        'dart-session:',
        'tgt:',
        'union-session:',
        'auth-blocked:',
        'business-session:library:',
        'business-session:shuttle:',
        'business-session:second-class:',
      ]) {
        values.remove('$prefix$account');
      }
      if (values['active-account'] == account) values.remove('active-account');
    } else {
      throw UnimplementedError();
    }
    return {};
  }

  void seed({bool expired = false}) {
    values['active-account'] = 'synthetic-account';
    values['password:synthetic-account'] = 'synthetic-password';
    values['session:synthetic-account'] = base64Encode(
      utf8.encode(
        jsonEncode([
          {
            'name': 'bzb_jsxsd',
            'value': 'synthetic-cookie',
            'domain': 'bkjx.wust.edu.cn',
            'path': '/jsxsd',
            'secure': true,
            'expires': expired
                ? -1000000000
                : (DateTime.now().millisecondsSinceEpoch / 1000 -
                      978307200 +
                      3600),
          },
        ]),
      ),
    );
  }
}

class ProtocolState {
  int logins = 0;
  bool offline = false;
  Future<SchoolResponse> respond(Uri uri) async {
    if (offline)
      throw const FoundationException('network_error', 'Synthetic offline');
    final login = uri.host == 'auth.wust.edu.cn';
    if (login) {
      logins++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    var body = '';
    if (uri.path == '/jsxsd/grxx/xsxx')
      body =
          '<table id="xjkpTable"><tbody><tr><td></td></tr><tr><td></td></tr><tr><td>院系：合成</td><td>专业：合成</td><td></td><td>班级：合成</td><td>学号：synthetic-account</td></tr></tbody></table>';
    return SchoolResponse(
      status: login ? 503 : 200,
      uri: uri,
      bytes: Uint8List.fromList(utf8.encode(body)),
    );
  }
}

class ProtocolTransport extends SchoolTransport {
  ProtocolTransport(this.state);
  final ProtocolState state;
  @override
  Future<SchoolResponse> send(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
    List<MapEntry<String, String>>? formFields,
    Object? jsonBody,
    Map<String, String> headers = const {},
    bool followRedirects = true,
  }) => state.respond(uri);
}

void main() {
  test('旧 Swift 日期会话迁移并跨重启复用，不读取密码', () async {
    final store = MemoryPlatform()..seed();
    final protocol = ProtocolState();
    final first = SchoolAuthentication(
      store,
      transportFactory: () => ProtocolTransport(protocol),
    );
    await first.ensureSession();
    expect(store.values.containsKey('dart-session:synthetic-account'), isTrue);
    first.cancel();
    final restarted = SchoolAuthentication(
      store,
      transportFactory: () => ProtocolTransport(protocol),
    );
    await restarted.ensureSession();
    expect(protocol.logins, 0);
    expect(store.loads.where((k) => k.startsWith('password:')), isEmpty);
    restarted.cancel();
  });
  test('过期会话恢复最多首次加四次重试，保存密码仍保留', () async {
    final store = MemoryPlatform()..seed(expired: true);
    final protocol = ProtocolState();
    final auth = SchoolAuthentication(
      store,
      transportFactory: () => ProtocolTransport(protocol),
    );
    await expectLater(
      auth.ensureSession(),
      throwsA(isA<FoundationException>()),
    );
    expect(protocol.logins, 5);
    expect(store.values['password:synthetic-account'], 'synthetic-password');
    expect(store.values.containsKey('session:synthetic-account'), isFalse);
    auth.cancel();
  });
  test('十二个并发恢复请求共享同一五次失败流程', () async {
    final store = MemoryPlatform()..seed(expired: true);
    final protocol = ProtocolState();
    final auth = SchoolAuthentication(
      store,
      transportFactory: () => ProtocolTransport(protocol),
    );
    final results = await Future.wait(
      List.generate(12, (_) async {
        try {
          await auth.ensureSession();
          return false;
        } on FoundationException {
          return true;
        }
      }),
    );
    expect(results.every((result) => result), isTrue);
    expect(protocol.logins, 5);
    auth.cancel();
  });
  test('退出中断重试并清除当前账号全部兼容凭据', () async {
    final store = MemoryPlatform()..seed(expired: true);
    final protocol = ProtocolState();
    final auth = SchoolAuthentication(
      store,
      transportFactory: () => ProtocolTransport(protocol),
    );
    final pending = auth.ensureSession();
    final failure = expectLater(pending, throwsA(isA<FoundationException>()));
    while (protocol.logins == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await auth.logout();
    await failure;
    expect(protocol.logins, 1);
    expect(store.values, isEmpty);
    await expectLater(
      auth.ensureSession(),
      throwsA(
        isA<FoundationException>().having(
          (e) => e.code,
          'code',
          'login_required',
        ),
      ),
    );
  });
  test('并发业务会话失效共享一次清理及五次恢复流程', () async {
    final store = MemoryPlatform()..seed();
    final protocol = ProtocolState();
    final auth = SchoolAuthentication(
      store,
      transportFactory: () => ProtocolTransport(protocol),
    );
    await auth.ensureSession();
    final failures = await Future.wait(
      List.generate(12, (_) async {
        try {
          await auth.withSession<void>((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 5));
            throw const FoundationException(
              'authentication_required',
              'Synthetic expiry',
            );
          });
          return false;
        } on FoundationException {
          return true;
        }
      }),
    );
    expect(failures.every((failure) => failure), isTrue);
    expect(protocol.logins, 5);
    expect(store.values['password:synthetic-account'], 'synthetic-password');
    auth.cancel();
  });
  test('网络错误不抹除会话及密码', () async {
    final store = MemoryPlatform()..seed();
    final protocol = ProtocolState()..offline = true;
    final auth = SchoolAuthentication(
      store,
      transportFactory: () => ProtocolTransport(protocol),
    );
    await expectLater(
      auth.ensureSession(),
      throwsA(
        isA<FoundationException>().having(
          (e) => e.code,
          'code',
          'network_error',
        ),
      ),
    );
    expect(store.values.containsKey('session:synthetic-account'), isTrue);
    expect(store.values['password:synthetic-account'], 'synthetic-password');
    expect(protocol.logins, 0);
    auth.cancel();
  });
}
