import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/foundation/transport.dart';

void main() {
  test('多值表单实际发出两个同名值且正确编码', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? posted;
    server.listen((request) async {
      posted = await request.fold<String>(
        '',
        (a, b) => a + String.fromCharCodes(b),
      );
      request.response.write('ok');
      await request.response.close();
    });
    final http = SchoolTransport(allowInsecureForTests: true);
    try {
      await http.send(
        Uri.parse('http://127.0.0.1:${server.port}/'),
        method: 'POST',
        formFields: [const MapEntry('x', 'a+b'), const MapEntry('x', '&=')],
      );
      expect(posted, 'x=a%2Bb&x=%26%3D');
    } finally {
      http.close();
      await server.close(force: true);
    }
  });
  test('逐条保存合法 Cookie，拒绝上级公共域且保留路径和过期规则', () {
    final jar = SchoolCookieJar();
    final uri = Uri.parse('https://bkjx.wust.edu.cn/jsxsd/');
    jar.remember(uri, [
      'bad=synthetic; Domain=edu.cn; Path=/',
      'good=synthetic; Path=/jsxsd; Secure; HttpOnly',
      'gone=old; Max-Age=-1; Path=/',
    ]);
    expect(jar.header(uri), 'good=synthetic');
    expect(jar.header(Uri.parse('https://auth.wust.edu.cn/jsxsd/')), isEmpty);
    expect(jar.header(Uri.parse('https://bkjx.wust.edu.cn/other')), isEmpty);
    expect(jar.header(Uri.parse('http://bkjx.wust.edu.cn/jsxsd/')), isEmpty);
    final restored = SchoolCookieJar()..import(jar.export());
    expect(restored.header(uri), 'good=synthetic');
  });
  test('302 跨站转 GET，保留响应 Cookie，不转发请求体和授权头', () async {
    final first = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final second = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    String? method, authorization, body;
    first.listen((request) async {
      request.response.statusCode = 302;
      request.response.headers.add('Set-Cookie', 'sso=synthetic; Path=/');
      request.response.headers.set(
        'Location',
        'http://localhost:${second.port}/done',
      );
      await request.response.close();
    });
    second.listen((request) async {
      method = request.method;
      authorization = request.headers.value('Authorization');
      body = await request.fold<String>(
        '',
        (a, b) => a + String.fromCharCodes(b),
      );
      request.response.write('done');
      await request.response.close();
    });
    final transport = SchoolTransport(allowInsecureForTests: true);
    try {
      final result = await transport.send(
        Uri.parse('http://127.0.0.1:${first.port}/start'),
        method: 'POST',
        form: {'password': 'synthetic-only'},
        headers: {'Authorization': 'synthetic-only'},
      );
      expect(result.text, 'done');
      expect(method, 'GET');
      expect(body, isEmpty);
      expect(authorization, isNull);
      expect(
        transport.cookies.header(Uri.parse('http://127.0.0.1:${first.port}/')),
        'sso=synthetic',
      );
    } finally {
      transport.close();
      await first.close(force: true);
      await second.close(force: true);
    }
  });
  test('307 不向不同源转发 POST', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 307;
      request.response.headers.set(
        'Location',
        'http://localhost:${server.port}/foreign',
      );
      await request.response.close();
    });
    final transport = SchoolTransport(allowInsecureForTests: true);
    try {
      await expectLater(
        transport.send(
          Uri.parse('http://127.0.0.1:${server.port}/start'),
          method: 'POST',
          form: {'secret': 'synthetic'},
        ),
        throwsA(
          isA<FoundationException>().having(
            (e) => e.code,
            'code',
            'unsafe_redirect',
          ),
        ),
      );
    } finally {
      transport.close();
      await server.close(force: true);
    }
  });
}
