import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/foundation/auth.dart';
import 'package:wust_wiki/foundation/auth_response.dart';
import 'package:wust_wiki/foundation/transport.dart';
import 'auth_test.dart' show MemoryPlatform;

final _big = base64Encode(List.filled(20, 7));
final _small = base64Encode([
  ...List.filled(20, 9),
  ...ascii.encode('1234567890ABCDEF'),
]);

class _Store extends MemoryPlatform {
  _Store() {
    final random = Random(91);
    background = Uint8List(280 * 160 * 4);
    piece = Uint8List(56 * 160 * 4);
    for (var i = 0; i < 280 * 160; i++) {
      final value = 30 + random.nextInt(200);
      for (var c = 0; c < 3; c++) {
        background[i * 4 + c] = value;
      }
      background[i * 4 + 3] = 255;
    }
    for (var y = 48; y < 104; y++) {
      for (var x = 4; x < 52; x++) {
        final src = (y * 280 + 110 + x) * 4, dst = (y * 56 + x) * 4;
        for (var c = 0; c < 3; c++) {
          piece[dst + c] = background[src + c];
          background[src + c] = (background[src + c] * .55).round();
        }
        piece[dst + 3] = 255;
      }
    }
  }
  late Uint8List background, piece;
  void identity() {
    values['active-account'] = 'synthetic-account';
    values['password:synthetic-account'] = 'synthetic-password';
    values['union-session:synthetic-account'] = base64Encode(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'cookies': [
            {
              'name': 'CASTGC',
              'value': 'synthetic-sso',
              'domain': 'auth.wust.edu.cn',
              'path': '/authserver',
              'secure': true,
            },
          ],
        }),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> invoke(
    String operation, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (operation == 'aes') return {'data': 'synthetic-encrypted-only'};
    if (operation == 'raster')
      return {
        'width': args['data'] == _big ? 280 : 56,
        'height': 160,
        'pixels': base64Encode(args['data'] == _big ? background : piece),
      };
    return super.invoke(operation, args);
  }
}

class _Server {
  bool wrongPassword = false, identityExpired = false, offline = false;
  int posts = 0, identityGets = 0, businessGets = 0;
  final services = <String>[];
  final calls = <String>[];
  Future<SchoolResponse> respond(
    _Http http,
    Uri uri,
    String method,
    Map<String, String>? form,
  ) async {
    calls.add('${uri.host}${uri.path}');
    if (offline)
      throw const FoundationException('network_error', 'synthetic offline');
    Object body = '';
    var status = 200;
    final headers = <String, String>{};
    if (uri.host == 'auth.wust.edu.cn') {
      expect(uri.path.startsWith('/authserver/'), true);
      if (uri.path.endsWith('openSliderCaptcha.htl')) {
        body = {
          'bigImage': _big,
          'smallImage': _small,
          'tagWidth': 56,
          'yHeight': 48,
        };
      } else if (uri.path.endsWith('verifySliderCaptcha.htl')) {
        body = {'errorCode': 1};
      } else if (uri.path == '/authserver/login') {
        identityGets++;
        final signedIn =
            http.cookies.header(uri).contains('synthetic-sso') &&
            !identityExpired;
        if (method == 'POST') {
          posts++;
          expect(form?['password'], 'synthetic-encrypted-only');
          expect(form?.containsKey('passwordText'), false);
          if (wrongPassword) {
            body =
                '<form id="pwdFromId"></form><span id="showErrorTip">用户名或密码错误</span>';
          } else {
            identityExpired = false;
            http.cookies.remember(uri, [
              'CASTGC=synthetic-sso; Path=/authserver; Secure; HttpOnly',
            ]);
            status = 302;
            headers['location'] =
                '${uri.queryParameters['service']}?ticket=ST-synthetic';
          }
        } else if (signedIn) {
          services.add(uri.queryParameters['service']!);
          status = 302;
          headers['location'] =
              '${uri.queryParameters['service']}?ticket=ST-synthetic';
        } else {
          body =
              '<form id="pwdFromId" method="post" action="/authserver/login">'
              '<input type="hidden" name="execution" value="synthetic-execution">'
              '<input type="hidden" name="_eventId" value="submit">'
              '<input id="pwdEncryptSalt" value="1234567890ABCDEF"></form>';
        }
      }
    } else if (uri.host == 'bkjx.wust.edu.cn') {
      businessGets++;
      expect(
        http.cookies.header(
          Uri.parse('https://auth.wust.edu.cn/authserver/login'),
        ),
        isEmpty,
        reason: 'Business transport must never contain identity cookies',
      );
      if (uri.queryParameters.containsKey('ticket'))
        http.cookies.remember(uri, [
          'bzb_jsxsd=synthetic-business; Path=/jsxsd; Secure',
        ]);
      if (uri.path == '/jsxsd/grxx/xsxx')
        body =
            '<table id="xjkpTable"><tbody><tr><td></td></tr><tr><td></td></tr><tr><td>合成</td><td>合成</td><td></td><td></td><td>学号：synthetic-account</td></tr></tbody></table>';
    }
    return SchoolResponse(
      status: status,
      uri: uri,
      bytes: Uint8List.fromList(
        utf8.encode(body is String ? body : jsonEncode(body)),
      ),
      headers: headers,
    );
  }
}

class _Http extends SchoolTransport {
  _Http(this.server);
  final _Server server;
  @override
  Future<SchoolResponse> send(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
    List<MapEntry<String, String>>? formFields,
    Object? jsonBody,
    Map<String, String> headers = const {},
    bool followRedirects = true,
  }) => server.respond(this, uri, method, form);
}

void main() {
  test(
    'SSO supplies per-service tickets and restores academic without reading a password',
    () async {
      final store = _Store()..identity(), server = _Server();
      final auth = SchoolAuthentication(
        store,
        transportFactory: () => _Http(server),
      );
      await auth.ensureIdentity();
      expect(auth.identityVerified, true);
      expect(auth.academicVerified, false);
      expect(
        server.businessGets,
        0,
        reason: 'Identity login does not depend on academic availability',
      );
      for (final value in schoolServices.values) {
        expect(await auth.serviceTicket(value), 'ST-synthetic');
      }
      await auth.ensureSession();
      expect(auth.academicVerified, true);
      expect(server.posts, 0);
      expect(store.loads.where((k) => k.startsWith('password:')), isEmpty);
      expect(server.services.toSet(), containsAll(schoolServices.values));
      auth.cancel();
    },
  );
  test(
    'Business expiry refreshes only business while valid SSO is reused',
    () async {
      final store = _Store()..identity(), server = _Server();
      final auth = SchoolAuthentication(
        store,
        transportFactory: () => _Http(server),
      );
      var tries = 0;
      final value = await auth.withSession((_) async {
        if (++tries == 1)
          throw const FoundationException(
            'authentication_required',
            'synthetic business expired',
          );
        return 7;
      });
      expect(value, 7);
      expect(tries, 2);
      expect(server.posts, 0);
      expect(store.loads.where((k) => k.startsWith('password:')), isEmpty);
      auth.cancel();
    },
  );
  test(
    'Server password rejection stops after one POST and blocks future automatic attempts',
    () async {
      final store = _Store(), server = _Server()..wrongPassword = true;
      final auth = SchoolAuthentication(
        store,
        transportFactory: () => _Http(server),
      );
      final rejected = throwsA(
        isA<FoundationException>().having(
          (e) => e.code,
          'code',
          'credentials_rejected',
        ),
      );
      await expectLater(
        auth.login('synthetic-account', 'synthetic-wrong'),
        rejected,
      );
      expect(server.posts, 1);
      expect(store.values['password:synthetic-account'], isNull);
      await expectLater(auth.ensureIdentity(), rejected);
      await expectLater(auth.ensureSession(), rejected);
      auth.cancel();
      final restarted = SchoolAuthentication(
        store,
        transportFactory: () => _Http(server),
      );
      await expectLater(restarted.ensureIdentity(), rejected);
      expect(server.posts, 1);
      server.wrongPassword = false;
      await restarted.login('synthetic-account', 'synthetic-corrected');
      expect(server.posts, 2);
      expect(store.values['auth-blocked:synthetic-account'], isNull);
      expect(restarted.identityVerified, true);
      expect(restarted.academicVerified, false);
      restarted.cancel();
    },
  );
  test('Concurrent identity restores share one password submission', () async {
    final store = _Store()..identity(),
        server = _Server()..identityExpired = true;
    final auth = SchoolAuthentication(
      store,
      transportFactory: () => _Http(server),
    );
    await Future.wait(List.generate(12, (_) => auth.ensureIdentity()));
    expect(server.posts, 1);
    expect(auth.restoredWithPassword, true);
    auth.cancel();
  });
  test(
    'Business sessions finish loading, remain isolated and survive restart',
    () async {
      final store = _Store()..identity(), server = _Server();
      final auth = SchoolAuthentication(
        store,
        transportFactory: () => _Http(server),
      );
      final library = await auth
          .businessSession('library')
          .timeout(const Duration(seconds: 1));
      final portal = await auth
          .businessSession('shuttle')
          .timeout(const Duration(seconds: 1));
      expect(identical(library, portal), false);
      library.cookies.remember(Uri.parse(schoolServices['library']!), [
        'LIB=synthetic-library; Path=/; Secure',
      ]);
      await auth.saveBusinessSession('library', library);
      auth.cancel();
      final restored = await auth
          .businessSession('library')
          .timeout(const Duration(seconds: 1));
      expect(
        restored.cookies.header(Uri.parse(schoolServices['library']!)),
        contains('LIB=synthetic-library'),
      );
      expect(
        restored.cookies.header(
          Uri.parse('https://auth.wust.edu.cn/authserver/login'),
        ),
        isEmpty,
      );
      auth.cancel();
    },
  );
  test(
    'Concurrent expiry after verified SSO shares one password recovery',
    () async {
      final store = _Store()..identity(), server = _Server();
      final auth = SchoolAuthentication(
        store,
        transportFactory: () => _Http(server),
      );
      await auth.ensureIdentity();
      server.identityExpired = true;
      final tickets = await Future.wait(
        List.generate(
          12,
          (_) => auth.serviceTicket(schoolServices['shuttle']!),
        ),
      );
      expect(tickets.toSet(), {'ST-synthetic'});
      expect(server.posts, 1);
      auth.cancel();
    },
  );
  test(
    'Only supported services and matching one-time ticket callbacks are accepted',
    () {
      expect(
        () => checkedSchoolService('https://evil.example/'),
        throwsA(isA<FoundationException>()),
      );
      final service = Uri.parse(schoolServices['academic']!);
      expect(
        () => checkedServiceTicket(
          Uri.parse('https://evil.example/?ticket=ST-secret'),
          service,
        ),
        throwsA(isA<FoundationException>()),
      );
      expect(
        () => checkedServiceTicket(
          service.replace(query: 'ticket=ST-one&ticket=ST-two'),
          service,
        ),
        throwsA(isA<FoundationException>()),
      );
    },
  );
  test('Password messages come only from explicit server error containers', () {
    expect(
      authenticationRejection(
        '<script>var msg="密码错误";</script><span id="showErrorTip"></span>',
      ),
      isNull,
    );
    expect(
      authenticationRejection('<span id="showErrorTip">密码错误</span>')?.code,
      'credentials_rejected',
    );
    expect(
      authenticationRejection('<span id="showErrorTip">验证码错误</span>')?.code,
      'captcha_rejected',
    );
    expect(
      authenticationRejection('<span id="showErrorTip">密码已过期</span>')?.code,
      'password_expired',
    );
    expect(
      authenticationRejection('<span id="showErrorTip">账号已锁定</span>')?.code,
      'account_locked',
    );
  });
  test(
    'Logout clears central, business, compatibility and blocked credentials',
    () async {
      final store = _Store()..identity();
      for (final key in [
        'auth-blocked:',
        'business-session:library:',
        'business-session:shuttle:',
        'business-session:second-class:',
      ]) {
        store.values['${key}synthetic-account'] = 'synthetic';
      }
      final auth = SchoolAuthentication(
        store,
        transportFactory: () => _Http(_Server()),
      );
      await auth.logout();
      expect(store.values, isEmpty);
    },
  );
}
