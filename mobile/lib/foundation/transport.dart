import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class FoundationException implements Exception {
  const FoundationException(this.code, this.message, {this.status});
  final String code, message;
  final int? status;
  @override
  String toString() => '$code: $message';
}

class SchoolResponse {
  SchoolResponse({
    required this.status,
    required this.uri,
    required this.bytes,
    this.headers = const {},
  });
  final int status;
  final Uri uri;
  final Uint8List bytes;
  final Map<String, String> headers;
  String get text => utf8.decode(bytes);
  Object? get json => jsonDecode(text);
}

class SessionCookie {
  SessionCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    this.secure = false,
    this.httpOnly = false,
    this.hostOnly = true,
    this.expires,
  });
  final String name, value, domain, path;
  final bool secure, httpOnly, hostOnly;
  final DateTime? expires;
  bool get expired =>
      expires != null && !expires!.isAfter(DateTime.now().toUtc());
  bool matches(Uri uri) {
    final host = uri.host.toLowerCase();
    final domainMatch =
        host == domain || (!hostOnly && host.endsWith('.$domain'));
    final route = uri.path.isEmpty ? '/' : uri.path;
    final pathMatch =
        route == path || route.startsWith(path.endsWith('/') ? path : '$path/');
    return !expired &&
        domainMatch &&
        pathMatch &&
        (!secure || uri.scheme == 'https');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'value': value,
    'domain': domain,
    'path': path,
    'secure': secure,
    'httpOnly': httpOnly,
    'hostOnly': hostOnly,
    if (expires != null) 'expires': expires!.millisecondsSinceEpoch,
  };
  static SessionCookie? fromJson(
    Map<String, dynamic> data, {
    bool swiftDate = false,
  }) {
    if (data['name'] is! String ||
        data['value'] is! String ||
        data['domain'] is! String ||
        data['path'] is! String)
      return null;
    final domain = (data['domain'] as String).toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    if (domain.isEmpty ||
        domain == 'edu.cn' ||
        domain == 'com' ||
        domain == 'cn')
      return null;
    final time = data['expires'];
    final expires = time is num
        ? DateTime.fromMillisecondsSinceEpoch(
            swiftDate ? ((time + 978307200) * 1000).round() : time.round(),
            isUtc: true,
          )
        : null;
    return SessionCookie(
      name: data['name'],
      value: data['value'],
      domain: domain,
      path: data['path'],
      secure: data['secure'] == true,
      httpOnly: data['httpOnly'] == true,
      hostOnly: data['hostOnly'] != false,
      expires: expires,
    );
  }
}

class SchoolCookieJar {
  final List<SessionCookie> _cookies = [];
  List<Map<String, dynamic>> export() =>
      _cookies.where((c) => !c.expired).map((c) => c.toJson()).toList();
  void import(List<dynamic> values, {bool swiftDate = false}) {
    for (final value in values) {
      if (value is Map) {
        final cookie = SessionCookie.fromJson(
          Map<String, dynamic>.from(value),
          swiftDate: swiftDate,
        );
        if (cookie != null) _put(cookie);
      }
    }
  }

  void _put(SessionCookie cookie) {
    _cookies.removeWhere(
      (c) =>
          c.name == cookie.name &&
          c.domain == cookie.domain &&
          c.path == cookie.path,
    );
    if (!cookie.expired) _cookies.add(cookie);
  }

  void remember(Uri origin, List<String> headers) {
    for (final header in headers) {
      try {
        final raw = Cookie.fromSetCookieValue(header);
        final hostOnly = raw.domain == null || raw.domain!.isEmpty;
        final domain = (hostOnly ? origin.host : raw.domain!)
            .toLowerCase()
            .replaceFirst(RegExp(r'^\.'), '');
        if (domain != origin.host.toLowerCase() &&
            (!origin.host.toLowerCase().endsWith('.$domain') ||
                domain.split('.').length < 2 ||
                {'edu.cn', 'com.cn', 'org.cn', 'co.uk'}.contains(domain)))
          continue;
        final slash = origin.path.lastIndexOf('/');
        final defaultPath = slash <= 0 ? '/' : origin.path.substring(0, slash);
        final path = raw.path != null && raw.path!.startsWith('/')
            ? raw.path!
            : defaultPath;
        final expires = raw.maxAge != null
            ? DateTime.now().toUtc().add(Duration(seconds: raw.maxAge!))
            : raw.expires?.toUtc();
        _put(
          SessionCookie(
            name: raw.name,
            value: raw.value,
            domain: domain,
            path: path,
            hostOnly: hostOnly,
            secure: raw.secure,
            httpOnly: raw.httpOnly,
            expires: expires,
          ),
        );
      } on FormatException {
        /* One invalid cookie must not discard the others. */
      }
    }
  }

  String header(Uri uri) {
    final selected = _cookies.where((c) => c.matches(uri)).toList()
      ..sort((a, b) => b.path.length.compareTo(a.path.length));
    return selected.map((c) => '${c.name}=${c.value}').join('; ');
  }
}

class SchoolTransport {
  SchoolTransport({
    HttpClient? client,
    SchoolCookieJar? cookies,
    this.allowInsecureForTests = false,
    this.allowPublicHttp = false,
  }) : _client = client ?? HttpClient(),
       cookies = cookies ?? SchoolCookieJar() {
    _client.connectionTimeout = const Duration(seconds: 30);
    _client.idleTimeout = const Duration(seconds: 15);
  }
  final HttpClient _client;
  final SchoolCookieJar cookies;
  final bool allowInsecureForTests;
  final bool allowPublicHttp;
  final Set<HttpClientRequest> _requests = {};
  bool _closed = false;
  bool get closed => _closed;
  void cancel() {
    _closed = true;
    for (final request in _requests.toList()) {
      request.abort();
    }
    _client.close(force: true);
  }

  void close() => cancel();

  Future<SchoolResponse> send(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
    List<MapEntry<String, String>>? formFields,
    Object? jsonBody,
    Map<String, String> headers = const {},
    bool followRedirects = true,
  }) async {
    var target = uri;
    var verb = method.toUpperCase();
    if (form != null && formFields != null)
      throw const FoundationException('invalid_input', '表单参数冲突。');
    var fields = formFields ?? form?.entries.toList();
    var jsonValue = jsonBody;
    var forwarded = Map<String, String>.from(headers);
    for (var redirects = 0; redirects <= 10; redirects++) {
      if (_closed) throw const FoundationException('cancelled', '操作已取消。');
      final publicHttp =
          allowPublicHttp &&
          target.scheme == 'http' &&
          (target.host == 'wust.edu.cn' ||
              target.host.endsWith('.wust.edu.cn')) &&
          {'GET', 'HEAD'}.contains(verb) &&
          fields == null &&
          jsonValue == null &&
          !forwarded.keys.any(
            (key) => {
              'authorization',
              'token',
              'x-auth-token',
              'cookie',
            }.contains(key.toLowerCase()),
          );
      if (target.userInfo.isNotEmpty ||
          (target.scheme != 'https' &&
              !publicHttp &&
              !(allowInsecureForTests &&
                  target.scheme == 'http' &&
                  {'127.0.0.1', 'localhost', '::1'}.contains(target.host)))) {
        throw const FoundationException('unsafe_url', '请求地址不安全。');
      }
      HttpClientRequest? request;
      try {
        request = await _client
            .openUrl(verb, target)
            .timeout(const Duration(seconds: 30));
        _requests.add(request);
        request.followRedirects = false;
        forwarded.forEach((name, value) => request!.headers.set(name, value));
        if (!forwarded.keys.any((k) => k.toLowerCase() == 'cookie')) {
          final cookie = cookies.header(target);
          if (cookie.isNotEmpty)
            request.headers.set(HttpHeaders.cookieHeader, cookie);
        }
        if (fields != null) {
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/x-www-form-urlencoded;charset=UTF-8',
          );
          request.add(
            utf8.encode(
              fields
                  .map(
                    (entry) =>
                        '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
                  )
                  .join('&'),
            ),
          );
        } else if (jsonValue != null) {
          request.headers.contentType = ContentType.json;
          request.add(utf8.encode(jsonEncode(jsonValue)));
        }
        final response = await request.close().timeout(
          const Duration(seconds: 40),
        );
        cookies.remember(
          target,
          response.headers[HttpHeaders.setCookieHeader] ?? const [],
        );
        final responseHeaders = <String, String>{};
        response.headers.forEach(
          (name, values) =>
              responseHeaders[name.toLowerCase()] = values.join(', '),
        );
        final data = BytesBuilder(copy: false);
        await for (final bytes in response.timeout(
          const Duration(seconds: 40),
        )) {
          if (data.length + bytes.length > 64 * 1024 * 1024)
            throw const FoundationException(
              'response_too_large',
              '服务响应超过大小限制。',
            );
          data.add(bytes);
        }
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (followRedirects &&
            {301, 302, 303, 307, 308}.contains(response.statusCode) &&
            location != null) {
          final next = target.resolve(location);
          if (!{'http', 'https'}.contains(next.scheme) ||
              !next.hasAuthority ||
              next.authority.contains('@'))
            throw const FoundationException('unsafe_redirect', '重定向地址不安全。');
          final changeToGet =
              response.statusCode == 303 ||
              ((response.statusCode == 301 || response.statusCode == 302) &&
                  verb == 'POST');
          if (changeToGet) {
            verb = 'GET';
            fields = null;
            jsonValue = null;
            forwarded.removeWhere(
              (k, _) =>
                  {'content-type', 'content-length'}.contains(k.toLowerCase()),
            );
          }
          if (next.origin != target.origin) {
            if (verb != 'GET' && verb != 'HEAD')
              throw const FoundationException('unsafe_redirect', '已阻止跨站提交凭据。');
            forwarded.removeWhere(
              (k, _) => !{
                'accept',
                'accept-language',
                'user-agent',
              }.contains(k.toLowerCase()),
            );
          }
          target = next;
          continue;
        }
        return SchoolResponse(
          status: response.statusCode,
          uri: target,
          bytes: data.takeBytes(),
          headers: responseHeaders,
        );
      } on FoundationException {
        rethrow;
      } on TimeoutException {
        request?.abort();
        throw FoundationException(
          _closed ? 'cancelled' : 'network_timeout',
          _closed ? '操作已取消。' : '学校服务响应超时。',
        );
      } on IOException {
        throw FoundationException(
          _closed ? 'cancelled' : 'network_error',
          _closed ? '操作已取消。' : '无法连接服务，已保存的登录信息仍保留。',
        );
      } finally {
        if (request != null) _requests.remove(request);
      }
    }
    throw const FoundationException('redirect_limit', '服务重定向次数过多。');
  }
}
