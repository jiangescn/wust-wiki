import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:html/parser.dart' as html;
import 'platform.dart';
import 'auth_response.dart';
import 'slider.dart';
import 'transport.dart';

typedef TransportFactory = SchoolTransport Function();

class SchoolAuthentication {
  SchoolAuthentication(
    this.platform, {
    TransportFactory? transportFactory,
    this.observer,
  }) : _factory = transportFactory ?? SchoolTransport.new;
  final FoundationPlatform platform;
  final TransportFactory _factory;
  final Future<void> Function(Map<String, dynamic>)? observer;
  void Function(Map<String, dynamic>)? progressObserver;
  final Set<SchoolTransport> _transports = {};
  final Map<String, SchoolTransport> _business = {};
  final Map<String, Future<SchoolTransport>> _businessLoads = {};
  SchoolTransport? _session, _identity;
  String? _username;
  bool _loaded = false,
      _valid = false,
      _identityValid = false,
      _loggingOut = false;
  int _version = 0;
  Future<SchoolTransport>? _operation, _identityOperation;
  Completer<void> _cancelled = Completer<void>();
  bool restoredWithPassword = false;
  String? get username => _username;
  bool get identityVerified => _identityValid;
  bool get academicVerified => _valid;
  static final _authURL = Uri.parse(
    'https://auth.wust.edu.cn/authserver/login',
  );
  Future<void> _observe(Map<String, dynamic> event) async {
    progressObserver?.call(event);
    await observer?.call(event);
  }

  void _check(int version) {
    if (version != _version || _loggingOut)
      throw const FoundationException('cancelled', '操作已取消。');
  }

  SchoolTransport _make() {
    final http = _factory();
    _transports.add(http);
    return http;
  }

  Future<void> _pause(Duration duration, int version) async {
    _check(version);
    await Future.any([Future<void>.delayed(duration), _cancelled.future]);
    _check(version);
  }

  void cancel() {
    _version++;
    if (!_cancelled.isCompleted) _cancelled.complete();
    _cancelled = Completer<void>();
    for (final http in _transports) {
      http.close();
    }
    _transports.clear();
    _business.clear();
    _businessLoads.clear();
    _session = null;
    _identity = null;
    _valid = false;
    _identityValid = false;
  }

  Future<SchoolTransport> _share(Future<SchoolTransport> Function() body) {
    if (_loggingOut)
      return Future.error(
        const FoundationException('operation_in_progress', '正在退出登录。'),
      );
    if (_operation != null) return _operation!;
    late final Future<SchoolTransport> task;
    task = body().whenComplete(() {
      if (identical(_operation, task)) _operation = null;
    });
    return _operation = task;
  }

  Future<String> _account(int version) async {
    if (!_loaded) {
      _username = await platform.load('active-account');
      _check(version);
      _loaded = true;
    }
    if (_username == null || _username!.isEmpty)
      throw const FoundationException('login_required', '请先登录学校统一认证。');
    return _username!;
  }

  Future<SchoolTransport> login(String username, String password) {
    if (_operation != null || _identityOperation != null)
      throw const FoundationException('operation_in_progress', '已有登录操作正在进行。');
    if (username.trim().isEmpty || password.isEmpty)
      throw const FoundationException('invalid_input', '请填写学号和密码。');
    cancel();
    _username = username.trim();
    _loaded = true;
    restoredWithPassword = false;
    final version = _version;
    late final Future<SchoolTransport> task;
    task =
        (() async {
          await platform.invoke('saveAccount', {
            'username': _username!,
            'password': password,
          });
          _check(version);
          for (final prefix in [
            'auth-blocked:',
            'union-session:',
            'dart-session:',
            'session:',
            'tgt:',
            for (final key in schoolServices.keys.where((k) => k != 'academic'))
              'business-session:$key:',
          ]) {
            await platform.clear('$prefix${_username!}');
            _check(version);
          }
          return _passwordLogin(password, version);
        })().whenComplete(() {
          if (identical(_identityOperation, task)) _identityOperation = null;
        });
    return _identityOperation = task;
  }

  Future<SchoolTransport> ensureIdentity() {
    if (_loggingOut)
      return Future.error(
        const FoundationException('operation_in_progress', '正在退出登录。'),
      );
    if (_identityOperation != null) return _identityOperation!;
    late final Future<SchoolTransport> task;
    task = _restoreIdentity().whenComplete(() {
      if (identical(_identityOperation, task)) _identityOperation = null;
    });
    return _identityOperation = task;
  }

  Future<SchoolTransport> _restoreIdentity() async {
    final version = _version, account = await _account(_version);
    _check(version);
    await _observe({'stage': 'restoring-identity'});
    final blocked = await platform.load('auth-blocked:$account');
    _check(version);
    if (blocked != null) throw _blocked(blocked);
    if (_identityValid &&
        _identity != null &&
        !_identity!.closed &&
        _identity!.cookies.header(_authURL).isNotEmpty)
      return _identity!;
    if (_identity == null) {
      final encoded =
          await platform.load('union-session:$account') ??
          await platform.load('dart-session:$account') ??
          await platform.load('session:$account');
      _check(version);
      if (encoded != null) {
        final http = _make();
        try {
          final decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
          final values = decoded is List
              ? decoded
              : decoded is Map
              ? decoded['cookies']
              : null;
          if (values is! List) throw const FormatException();
          http.cookies.import(
            values.where((v) {
              if (v is! Map) return false;
              final cookie = SessionCookie.fromJson(
                Map<String, dynamic>.from(v),
                swiftDate: decoded is List,
              );
              return cookie?.matches(_authURL) == true;
            }).toList(),
            swiftDate: decoded is List,
          );
          if (http.cookies.header(_authURL).isEmpty)
            throw const FoundationException('identity_expired', '统一认证会话已失效。');
          await _ticketResponse(
            http,
            Uri.parse(schoolServices['academic']!),
            version,
          );
          return _acceptIdentity(http, version);
        } on FormatException {
          http.close();
        } on FoundationException catch (error) {
          http.close();
          if (error.code != 'identity_expired') rethrow;
        }
        await platform.clear('union-session:$account');
        _check(version);
      }
    }
    final password = await platform.load('password:$account');
    _check(version);
    if (password == null || password.isEmpty)
      throw const FoundationException('login_required', '请填写统一认证密码后重新登录。');
    restoredWithPassword = true;
    return _passwordLogin(password, version);
  }

  FoundationException _blocked(String code) => switch (code) {
    'account_locked' => const FoundationException(
      'account_locked',
      '学校账号已锁定，请在学校页面处理后重新登录。',
    ),
    'password_expired' => const FoundationException(
      'password_expired',
      '统一认证密码已过期，请修改密码后重新登录。',
    ),
    'interactive_login_required' => const FoundationException(
      'interactive_login_required',
      '学校要求额外身份验证，请使用学校网页登录。',
    ),
    _ => const FoundationException(
      'credentials_rejected',
      '账号或密码错误，请检查并修改后重新登录。',
    ),
  };
  Future<SchoolTransport> _acceptIdentity(
    SchoolTransport http,
    int version,
  ) async {
    _check(version);
    if (http.cookies.header(_authURL).isEmpty)
      throw const FoundationException('invalid_session', '学校没有建立统一认证会话。');
    await platform.save(
      'union-session:${_username!}',
      base64Encode(
        utf8.encode(
          jsonEncode({'version': 1, 'cookies': http.cookies.export()}),
        ),
      ),
    );
    _check(version);
    _identity = http;
    _identityValid = true;
    await _observe({'stage': 'identity', 'verified': true});
    return http;
  }

  bool _retryable(FoundationException error) =>
      {
        'slider_no_match',
        'slider_rejected',
        'captcha_rejected',
        'network_error',
        'network_timeout',
        'login_not_completed',
      }.contains(error.code) ||
      error.code == 'http_error' && (error.status ?? 0) >= 500;
  Future<SchoolTransport> _passwordLogin(String password, int version) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      _check(version);
      final candidate = _make();
      try {
        await _observe({'stage': 'login', 'attempt': attempt + 1});
        await _authenticate(candidate, _username!, password, version);
        return _acceptIdentity(candidate, version);
      } catch (error) {
        candidate.close();
        _check(version);
        if (error is FoundationException) {
          if ({
            'credentials_rejected',
            'account_locked',
            'password_expired',
            'interactive_login_required',
          }.contains(error.code)) {
            await platform.save('auth-blocked:${_username!}', error.code);
            _check(version);
            if (error.code == 'credentials_rejected') {
              await platform.clear('password:${_username!}');
              _check(version);
            }
            rethrow;
          }
          if (!_retryable(error)) rethrow;
          if (attempt == 4)
            throw FoundationException(
              error.code,
              '登录累计 5 次仍失败，已停止重试。${error.message}',
              status: error.status,
            );
        } else {
          rethrow;
        }
        await _pause(const Duration(seconds: 1), version);
      }
    }
    throw const FoundationException('login_failed', '统一认证登录失败。');
  }

  void _status(SchoolResponse response) {
    if (response.status != 200)
      throw FoundationException(
        'http_error',
        '学校服务请求失败（HTTP ${response.status}）。',
        status: response.status,
      );
  }

  Future<Uri> _ticketResponse(
    SchoolTransport http,
    Uri service,
    int version, {
    SchoolResponse? initial,
  }) async {
    var response =
        initial ??
        await http.send(
          _authURL.replace(
            queryParameters: {
              'service': schoolServices.values.firstWhere(
                (value) => Uri.parse(value) == service,
              ),
            },
          ),
          followRedirects: false,
        );
    for (var i = 0; i < 10; i++) {
      _check(version);
      if ({301, 302, 303, 307, 308}.contains(response.status)) {
        final location = response.headers['location'];
        if (location == null || location.contains('@'))
          throw const FoundationException('unsafe_redirect', '统一认证回调地址无效。');
        final next = response.uri.resolve(location);
        if (next.host != 'auth.wust.edu.cn') {
          checkedServiceTicket(next, service);
          return next;
        }
        if (next.scheme != 'https' ||
            next.port != 443 ||
            next.authority.contains('@') ||
            !next.path.startsWith('/authserver/'))
          throw const FoundationException('unsafe_redirect', '统一认证跳转地址无效。');
        response = await http.send(next, followRedirects: false);
        continue;
      }
      _status(response);
      if (response.bytes.length >= 12000000)
        throw const FoundationException('invalid_response', '统一认证响应过大。');
      final rejection = authenticationRejection(response.text);
      if (rejection != null) throw rejection;
      if (html.parse(response.text).querySelector('#pwdFromId') != null)
        throw const FoundationException('identity_expired', '统一认证会话已过期。');
      await _observe({
        'stage': 'authorization-error',
        'service': schoolServices.entries
            .firstWhere((e) => Uri.parse(e.value) == service)
            .key,
        'knownReasons': [
          for (final term in [
            '未认证授权的服务',
            '未注册',
            '未授权',
            'not authorized',
            'not allowed',
            'not registered',
            'Unauthorized Service',
          ])
            if (response.text.contains(term)) term,
        ],
      });
      throw const FoundationException(
        'service_authorization_failed',
        '学校未向此业务签发授权，请使用学校页面确认访问权限。',
      );
    }
    throw const FoundationException('redirect_limit', '统一认证重定向次数过多。');
  }

  Future<String> serviceTicket(String value) async {
    final service = checkedSchoolService(value), version = _version;
    await _observe({
      'stage': 'authorizing',
      'service': schoolServices.entries
          .firstWhere((e) => Uri.parse(e.value) == service)
          .key,
    });
    final original = await ensureIdentity();
    _check(version);
    try {
      final callback = await _ticketResponse(original, service, version);
      await _acceptIdentity(original, version);
      return checkedServiceTicket(callback, service);
    } on FoundationException catch (error) {
      if (error.code != 'identity_expired') rethrow;
      final refreshed = await _refreshIdentity(original, version);
      _check(version);
      final callback = await _ticketResponse(refreshed, service, version);
      await _acceptIdentity(refreshed, version);
      return checkedServiceTicket(callback, service);
    }
  }

  Future<SchoolTransport> _refreshIdentity(
    SchoolTransport old,
    int version,
  ) async {
    _check(version);
    if (identical(_identity, old)) {
      _identity = null;
      _identityValid = false;
      old.close();
      await platform.clear('union-session:${_username!}');
      _check(version);
    }
    return ensureIdentity();
  }

  Future<void> _authenticate(
    SchoolTransport session,
    String username,
    String password,
    int version,
  ) async {
    final service = Uri.parse(schoolServices['academic']!);
    final login = _authURL.replace(
      queryParameters: {'service': service.toString()},
    );
    await _observe({'stage': 'form'});
    final response = await session.send(login, followRedirects: false);
    _check(version);
    _status(response);
    if (response.bytes.length >= 12000000)
      throw const FoundationException('invalid_response', '统一认证页面无效。');
    final form = html.parse(response.text).querySelector('#pwdFromId');
    final salt = form
        ?.querySelector('input[id=pwdEncryptSalt]')
        ?.attributes['value'];
    if (form == null ||
        form.attributes['method']?.toLowerCase() != 'post' ||
        salt == null ||
        ![16, 24, 32].contains(utf8.encode(salt).length))
      throw const FoundationException('invalid_login_form', '学校登录表单发生变化。');
    final target = login.resolve(form.attributes['action'] ?? '');
    if (target.scheme != 'https' ||
        target.host != login.host ||
        target.port != login.port ||
        target.path != login.path ||
        target.authority.contains('@'))
      throw const FoundationException('unsafe_form', '学校登录表单目标无效。');
    final fields = <String, String>{
      for (final input in form.querySelectorAll('input[type=hidden][name]'))
        input.attributes['name']!: input.attributes['value'] ?? '',
    };
    if ((fields['execution'] ?? '').isEmpty || fields['_eventId'] != 'submit')
      throw const FoundationException('invalid_login_form', '学校登录表单缺少认证字段。');
    fields['username'] = username;
    fields['password'] = await _encrypt(utf8.encode(password), salt);
    _check(version);
    fields['captcha'] = '';
    fields.remove('passwordText');
    await _solveCaptcha(session, version);
    final completed = await session.send(
      login,
      method: 'POST',
      form: fields,
      headers: {'Referer': login.toString(), 'Origin': _authURL.origin},
      followRedirects: false,
    );
    _check(version);
    if (completed.status == 200) {
      final rejection = authenticationRejection(completed.text);
      if (rejection != null) throw rejection;
    }
    await _ticketResponse(session, service, version, initial: completed);
  }

  Future<SchoolTransport> ensureSession() => _share(_restoreSession);
  Future<SchoolTransport> _restoreSession() async {
    final version = _version, account = await _account(_version);
    _check(version);
    final blocked = await platform.load('auth-blocked:$account');
    _check(version);
    if (blocked != null) throw _blocked(blocked);
    if (_valid &&
        _session != null &&
        !_session!.closed &&
        _session!.cookies
            .header(Uri.parse(schoolServices['academic']!))
            .isNotEmpty)
      return _session!;
    final candidate = _make();
    final encoded =
        await platform.load('dart-session:$account') ??
        await platform.load('session:$account');
    _check(version);
    if (encoded != null) {
      try {
        final decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
        final values = decoded is List
            ? decoded
            : decoded is Map
            ? decoded['cookies']
            : null;
        if (values is! List) throw const FormatException();
        candidate.cookies.import(
          values
              .where(
                (v) =>
                    v is Map &&
                    (v['domain'] as String?)?.replaceFirst(
                          RegExp(r'^\.'),
                          '',
                        ) ==
                        'bkjx.wust.edu.cn',
              )
              .toList(),
          swiftDate: decoded is List,
        );
        await _validate(candidate, account, version);
        return _accept(candidate, version);
      } on FormatException {
        /* Discard only this malformed business snapshot. */
      } on FoundationException catch (error) {
        if (!{
          'invalid_session',
          'cookie_missing',
          'student_id_mismatch',
        }.contains(error.code)) {
          candidate.close();
          rethrow;
        }
      }
    }
    if (encoded != null) {
      // Preserve any legacy SSO cookies before discarding an expired business snapshot.
      if (await platform.load('union-session:$account') == null) {
        try {
          final old = jsonDecode(utf8.decode(base64Decode(encoded)));
          final values = old is List
              ? old
              : old is Map
              ? old['cookies']
              : null;
          if (values is List) {
            final jar = SchoolCookieJar();
            jar.import(values, swiftDate: old is List);
            final identity = jar
                .export()
                .where(
                  (v) => SessionCookie.fromJson(v)?.matches(_authURL) == true,
                )
                .toList();
            if (identity.isNotEmpty)
              await platform.save(
                'union-session:$account',
                base64Encode(
                  utf8.encode(jsonEncode({'version': 1, 'cookies': identity})),
                ),
              );
          }
        } on FormatException {
          /* Only malformed legacy data is discarded. */
        }
      }
      _check(version);
      await platform.clear('dart-session:$account');
      await platform.clear('session:$account');
      _check(version);
    }
    final ticket = await serviceTicket(schoolServices['academic']!);
    _check(version);
    final response = await candidate.send(
      Uri.parse(
        schoolServices['academic']!,
      ).replace(queryParameters: {'ticket': ticket}),
    );
    _check(version);
    _status(response);
    await _validate(candidate, account, version);
    return _accept(candidate, version);
  }

  Future<SchoolTransport> _accept(SchoolTransport session, int version) async {
    _check(version);
    await platform.save(
      'dart-session:${_username!}',
      base64Encode(
        utf8.encode(
          jsonEncode({'version': 2, 'cookies': session.cookies.export()}),
        ),
      ),
    );
    _check(version);
    _session = session;
    _valid = true;
    return session;
  }

  Future<SchoolTransport> businessSession(String key) {
    if (!schoolServices.containsKey(key) || key == 'academic')
      throw const FoundationException('unsupported_resource', '未知学校业务会话。');
    return _businessLoads.putIfAbsent(
      key,
      () => _loadBusiness(key).whenComplete(() {
        _businessLoads.remove(key);
      }),
    );
  }

  Future<SchoolTransport> _loadBusiness(String key) async {
    await _observe({'stage': 'restoring-business', 'service': key});
    final version = _version, account = await _account(_version);
    _check(version);
    final blocked = await platform.load('auth-blocked:$account');
    _check(version);
    if (blocked != null) throw _blocked(blocked);
    final existing = _business[key];
    if (existing != null && !existing.closed) return existing;
    final candidate = _make();
    final encoded = await platform.load('business-session:$key:$account');
    _check(version);
    if (encoded != null) {
      try {
        final decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
        if (decoded is Map && decoded['cookies'] is List)
          candidate.cookies.import(decoded['cookies']);
      } on FormatException {
        /* A missing business session is rebuilt with SSO. */
      }
    }
    _business[key] = candidate;
    return candidate;
  }

  Future<void> saveBusinessSession(String key, SchoolTransport http) async {
    final version = _version, account = await _account(_version);
    _check(version);
    if (!identical(_business[key], http))
      throw const FoundationException('cancelled', '业务会话已取消。');
    await platform.save(
      'business-session:$key:$account',
      base64Encode(
        utf8.encode(
          jsonEncode({'version': 1, 'cookies': http.cookies.export()}),
        ),
      ),
    );
    _check(version);
  }

  Future<void> _validate(
    SchoolTransport session,
    String account,
    int version,
  ) async {
    await _observe({'stage': 'verifying-identity'});
    final url = Uri.parse(
      'https://bkjx.wust.edu.cn/jsxsd/framework/blankPage.jsp',
    );
    if (session.cookies.header(url).isEmpty)
      throw const FoundationException('cookie_missing', '教务 Cookie 缺失。');
    final response = await session.send(url);
    _check(version);
    _status(response);
    if (response.uri.origin != url.origin || response.uri.path != url.path)
      throw const FoundationException('invalid_session', '教务会话已失效。');
    final text = response.text.trim();
    if (text.contains('禁用'))
      throw const FoundationException('system_unavailable', '学校教务服务暂时禁用。');
    if (text.contains('不存在'))
      throw const FoundationException('student_record_missing', '学校未返回学生记录。');
    if (text.contains('500'))
      throw const FoundationException('remote_system_error', '学校系统暂时出错。');
    if (text.toLowerCase().contains('script'))
      throw const FoundationException('invalid_session', '教务会话已失效。');
    if (text.isNotEmpty)
      throw const FoundationException('invalid_response', '教务会话校验响应无效。');
    final student = await session.send(
      Uri.parse('https://bkjx.wust.edu.cn/jsxsd/grxx/xsxx'),
    );
    _check(version);
    _status(student);
    final table = html.parse(student.text).querySelector('#xjkpTable');
    final rows = table?.querySelectorAll('tbody > tr') ?? [];
    final cell =
        rows.length >= 3 &&
            rows[2].children.length >= 5 &&
            rows[2].children[4].localName == 'td'
        ? rows[2].children[4]
        : null;
    final value = cell?.text.trim() ?? '';
    if (!value.startsWith('学号：'))
      throw const FoundationException('invalid_session', '无法确认学生身份，请重新登录。');
    if (value.substring('学号：'.length).trim() != account)
      throw const FoundationException(
        'student_id_mismatch',
        '学校返回的学号与登录账号不一致。',
      );
  }

  Future<String> _encrypt(List<int> payload, String salt) async {
    const alphabet = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
    final random = Random.secure();
    List<int> randomBytes(int size) => List.generate(
      size,
      (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
    );
    final result = await platform.invoke('aes', {
      'data': base64Encode([...randomBytes(64), ...payload]),
      'key': base64Encode(utf8.encode(salt.trim())),
      'iv': base64Encode(randomBytes(16)),
    });
    if (result['data'] is! String)
      throw const FoundationException('encryption_failed', '本机加密未完成。');
    return result['data'] as String;
  }

  Future<SliderRaster> _raster(String encoded, {int height = 0}) async {
    final result = await platform.invoke('raster', {
      'data': encoded,
      'height': height,
    });
    return SliderRaster(
      result['width'] as int,
      result['height'] as int,
      base64Decode(result['pixels'] as String),
    );
  }

  /// Standalone challenge verification, without sending account credentials.
  Future<void> verifyCaptcha({bool withService = false}) async {
    final version = _version;
    final http = _make();
    try {
      final business = Uri.parse('https://bkjx.wust.edu.cn/jsxsd/');
      if (withService) _status(await http.send(business));
      _status(
        await http.send(
          Uri.https(
            'auth.wust.edu.cn',
            '/authserver/login',
            withService ? {'service': business.toString()} : null,
          ),
        ),
      );
      await _solveCaptcha(http, version);
    } finally {
      http.close();
    }
  }

  Future<void> _solveCaptcha(SchoolTransport session, int version) async {
    const headers = {
      'X-Requested-With': 'XMLHttpRequest',
      'Accept': 'application/json',
    };
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final elapsed = Stopwatch()..start();
        final cookieURL = Uri.parse(
          'https://auth.wust.edu.cn/authserver/common/openSliderCaptcha.htl',
        );
        final cookieBefore = session.cookies.header(cookieURL);
        final response = await session.send(
          Uri.parse(
            'https://auth.wust.edu.cn/authserver/common/openSliderCaptcha.htl',
          ),
          headers: headers,
        );
        _check(version);
        _status(response);
        await _observe({
          'stage': 'challenge-session',
          'cookiePresent': cookieBefore.isNotEmpty,
          'cookieStable': cookieBefore == session.cookies.header(cookieURL),
          'cookies': session.cookies
              .export()
              .map(
                (c) => {
                  'name': c['name'],
                  'domain': c['domain'],
                  'path': c['path'],
                },
              )
              .toList(),
        });
        final challenge = response.json;
        if (challenge is! Map ||
            challenge['bigImage'] is! String ||
            challenge['smallImage'] is! String ||
            challenge['tagWidth'] is! int ||
            challenge['yHeight'] is! int) {
          throw const FoundationException(
            'invalid_slider_response',
            '学校滑块数据无效。',
          );
        }
        final pieceBytes = base64Decode(challenge['smallImage'] as String);
        final backgroundBytes = base64Decode(challenge['bigImage'] as String);
        if (pieceBytes.length <= 16 ||
            pieceBytes.length > 8000000 ||
            backgroundBytes.isEmpty ||
            backgroundBytes.length > 8000000)
          throw const FoundationException('invalid_slider_image', '滑块图片无效。');
        final key = pieceBytes.sublist(pieceBytes.length - 16);
        if (!key.every((value) => value >= 33 && value <= 126))
          throw const FoundationException('invalid_slider_image', '滑块密钥无效。');
        final background = await _raster(challenge['bigImage']);
        _check(version);
        var piece = await _raster(challenge['smallImage']);
        _check(version);
        if ((piece.height - background.height).abs() <= 2 &&
            piece.height != background.height)
          piece = await _raster(
            challenge['smallImage'],
            height: background.height,
          );
        final tag = challenge['tagWidth'] as int,
            y = challenge['yHeight'] as int;
        final solution = await solveSliderAsync(background, piece, tag, y);
        _check(version);
        await _observe({
          'stage': 'slider',
          'offset': solution.pixelOffset,
          'score': solution.confidence,
          'elapsedMs': elapsed.elapsedMilliseconds,
          'width': background.width,
          'height': background.height,
        });
        final payload = solution.payload();
        final movementClock = Stopwatch()..start();
        var previousElapsed = 0;
        for (final point in (payload['tracks'] as List).skip(1)) {
          await _pause(Duration(milliseconds: point['c'] as int), version);
          final now = movementClock.elapsedMilliseconds;
          point['c'] = now - previousElapsed;
          previousElapsed = now;
        }
        await _observe({
          'stage': 'slider-movement',
          'steps': (payload['tracks'] as List).length,
          'elapsedMs': previousElapsed,
        });
        final sign = await _encrypt(
          utf8.encode(jsonEncode(payload)),
          ascii.decode(key),
        );
        _check(version);
        final verified = await session.send(
          Uri.parse(
            'https://auth.wust.edu.cn/authserver/common/verifySliderCaptcha.htl',
          ),
          method: 'POST',
          form: {'sign': sign},
          headers: headers,
        );
        _check(version);
        _status(verified);
        final object = verified.json;
        final value = object is Map ? object['errorCode'] : null;
        final code =
            value is num && value.isFinite && value == value.roundToDouble()
            ? value.toInt()
            : value is String
            ? int.tryParse(value)
            : null;
        if (code == null)
          throw const FoundationException(
            'invalid_slider_response',
            '学校滑块校验响应无效。',
          );
        await _observe({
          'stage': 'slider-result',
          'code': code,
          'elapsedMs': elapsed.elapsedMilliseconds,
        });
        if (code != 1)
          throw FoundationException('slider_rejected', '学校拒绝滑块校验（业务码 $code）。');
        return;
      } on FoundationException catch (error) {
        await _observe({'stage': 'slider-error', 'code': error.code});
        if (attempt == 2 ||
            !{'slider_no_match', 'slider_rejected'}.contains(error.code))
          rethrow;
      }
    }
  }

  Future<T> withSession<T>(
    Future<T> Function(SchoolTransport) operation,
  ) async {
    final version = _version, session = await ensureSession();
    _check(version);
    try {
      final result = await operation(session);
      _check(version);
      if (identical(_session, session)) await _accept(session, version);
      return result;
    } on FoundationException catch (error) {
      if (error.code != 'authentication_required') rethrow;
      _check(version);
      final refreshed = await _share(() async {
        if (identical(_session, session)) {
          _session = null;
          _valid = false;
          await platform.clear('dart-session:${_username!}');
          await platform.clear('session:${_username!}');
          _check(version);
        }
        return _restoreSession();
      });
      final result = await operation(refreshed);
      _check(version);
      if (identical(_session, refreshed)) await _accept(refreshed, version);
      return result;
    }
  }

  Future<void> logout() async {
    final pending = [
      if (_operation != null) _operation!,
      if (_identityOperation != null) _identityOperation!,
      ..._businessLoads.values,
    ];
    cancel();
    _loggingOut = true;
    try {
      for (final task in pending) {
        try {
          await task;
        } catch (_) {}
      }
      final account = _username ?? await platform.load('active-account');
      if (account != null)
        await platform.invoke('clearAccount', {'username': account});
      _username = null;
      _loaded = true;
    } finally {
      _loggingOut = false;
    }
  }
}
