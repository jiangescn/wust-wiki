import 'dart:async';
import 'progress.dart';
import 'academic_queries.dart';
import 'auth.dart';
import 'campus_services.dart';
import 'platform.dart';
import 'transport.dart';

abstract interface class FoundationApi {
  Future<Map<String, dynamic>> request(Map<String, dynamic> request);
  void cancel();
}

class DartFoundationClient implements FoundationApi, FoundationProgressSource {
  DartFoundationClient(this.platform, {SchoolAuthentication? authentication})
    : auth = authentication ?? SchoolAuthentication(platform) {
    auth.progressObserver = (event) {
      final attempt = event['attempt'] as int?;
      final message = switch (event['stage']) {
        'restoring-identity' => '正在恢复统一认证',
        'restoring-business' =>
          '正在恢复${schoolResourceLabel(event['service'] as String)}会话',
        'login' => '正在登录统一认证',
        'form' => '正在连接统一认证中心',
        'challenge-session' || 'slider' || 'slider-movement' => '正在验证登录',
        'verifying-identity' => '正在验证学生身份',
        'authorizing' =>
          '正在为${schoolResourceLabel(event['service'] as String)}建立会话',
        _ => null,
      };
      final id = Zone.current[_progressZone] as int?;
      if (message != null && id != null)
        _progress.update(id, message, attempt: attempt);
    };
  }
  final FoundationPlatform platform;
  final SchoolAuthentication auth;
  final Set<SchoolTransport> _publicTransports = {};
  final Map<Object, CampusServices> _campus = {};
  static final _progressZone = Object();
  void _queryProgress(String resource) {
    final id = Zone.current[_progressZone] as int?;
    if (id != null)
      _progress.update(id, '正在查询${schoolResourceLabel(resource)}');
  }

  final _progress = FoundationProgressHub();
  @override
  Stream<FoundationProgress?> get progress => _progress.progress;
  @override
  FoundationProgress? get currentProgress => _progress.currentProgress;
  final Set<Future<Map<String, dynamic>>> _requests = {};
  int _generation = 0;
  Future<Map<String, dynamic>>? _logoutOperation, _loginOperation;
  static const academicResources = {
    'schedule',
    'grades',
    'student',
    'exams',
    'credits',
    'calendar',
    'training-plan',
    'raw-schedule',
  };
  static const campusResources = {
    'notices',
    'notice-detail',
    'notice-file',
    'library',
    'library-search',
    'library-loans',
    'library-profile',
    'library-fines',
    'library-requests',
    'library-booklist',
    'library-booklist-books',
    'shuttle',
    'second-class',
    'laundry',
    'laundry-shops',
    'laundry-devices',
    'laundry-sms',
    'laundry-login',
    'laundry-orders',
    'laundry-order',
  };
  static const publicHttpResources = {
    'notices',
    'notice-detail',
    'notice-file',
  };

  @override
  void cancel() {
    _generation++;
    _progress.cancel();
    auth.cancel();
    for (final http in _publicTransports) {
      http.close();
    }
    _publicTransports.clear();
    _campus.clear();
  }

  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> input) {
    final action = input['action'];
    if (action == 'logout')
      return _logoutOperation ??= _logout().whenComplete(
        () => _logoutOperation = null,
      );
    if (action == 'cancel') {
      cancel();
      return Future.value({'ok': true, 'state': 'cancelled'});
    }
    if (_logoutOperation != null)
      return Future.error(
        const FoundationException('operation_in_progress', '正在退出登录。'),
      );
    if (_loginOperation != null) {
      return Future.error(
        const FoundationException('operation_in_progress', '正在登录统一认证，请稍候。'),
      );
    }
    final pendingLogin = action == 'login'
        ? _requests.toList()
        : <Future<Map<String, dynamic>>>[];
    if (action == 'login') cancel();
    final resource = (input['resource'] is String
        ? input['resource'] as String
        : input['action'] is String
        ? input['action'] as String
        : 'service');
    final id = _progress.begin(
      resource == 'login'
          ? '正在登录统一认证'
          : resource == 'inspect'
          ? '正在验证统一认证'
          : '正在查询${schoolResourceLabel(resource)}',
      resource: resource,
    );
    late final Future<Map<String, dynamic>> operation;
    final generation = _generation;
    operation =
        runZoned(() async {
          for (final pending in pendingLogin) {
            try {
              await pending;
            } catch (_) {}
          }
          _check(generation);
          return _execute(input, generation);
        }, zoneValues: {_progressZone: id}).whenComplete(() {
          _requests.remove(operation);
          _progress.finish(id);
          if (identical(_loginOperation, operation)) _loginOperation = null;
        });
    _requests.add(operation);
    if (action == 'login') _loginOperation = operation;
    return operation;
  }

  void _check(int generation) {
    if (generation != _generation)
      throw const FoundationException('cancelled', '操作已取消。');
  }

  Future<Map<String, dynamic>> _execute(
    Map<String, dynamic> input,
    int generation,
  ) async {
    switch (input['action']) {
      case 'login':
        if (input['username'] is! String || input['password'] is! String)
          throw const FoundationException('invalid_input', '请填写学号和密码。');
        await auth.login(input['username'], input['password']);
        _check(generation);
        return {
          'ok': true,
          'state': 'authenticated',
          'sessionToken': 'local',
          'expiresAt': 0,
          'restoredWithPassword': false,
          'unifiedVerified': true,
          'academicVerified': auth.academicVerified,
        };
      case 'inspect':
        await auth.ensureIdentity();
        _check(generation);
        return {
          'ok': true,
          'state': 'authenticated',
          'sessionToken': 'local',
          'expiresAt': 0,
          'restoredWithPassword': auth.restoredWithPassword,
          'unifiedVerified': true,
          'academicVerified': auth.academicVerified,
        };
      case 'query':
        final resource = input['resource'];
        if (resource is! String ||
            !(academicResources.contains(resource) ||
                campusResources.contains(resource)))
          throw const FoundationException('unsupported_resource', '不支持的服务入口。');
        final supplied = input['options'];
        if (supplied != null && supplied is! Map<String, dynamic>)
          throw const FoundationException('invalid_input', '查询参数格式无效。');
        final options =
            supplied as Map<String, dynamic>? ?? <String, dynamic>{};
        final Map<String, dynamic> result;
        if (academicResources.contains(resource)) {
          result = await auth.withSession((http) {
            _queryProgress(resource);
            return AcademicQueries(http).query(resource, options: options);
          });
        } else {
          final protected =
              resource.startsWith('library') ||
              {'shuttle', 'second-class'}.contains(resource);
          final key = resource.startsWith('library') ? 'library' : resource;
          late final CampusServices service;
          if (protected) {
            final http = await auth.businessSession(key);
            _check(generation);
            service = _campus.putIfAbsent(
              http,
              () => CampusServices(
                http,
                platform,
                ticketProvider: auth.serviceTicket,
                onQuery: () => _queryProgress(resource),
              ),
            );
            try {
              result = await service.query(resource, options: options);
            } finally {
              _check(generation);
              await auth.saveBusinessSession(key, http);
            }
          } else {
            final public = publicHttpResources.contains(resource);
            service = _campus.putIfAbsent(public, () {
              final http = SchoolTransport(allowPublicHttp: public);
              _publicTransports.add(http);
              return CampusServices(http, platform);
            });
            result = await service.query(resource, options: options);
          }
        }
        _check(generation);
        return {
          'ok': true,
          'state': 'complete',
          'result': result,
          'academicVerified': academicResources.contains(resource),
          'unifiedVerified': auth.identityVerified,
          if (academicResources.contains(resource))
            'restoredWithPassword': auth.restoredWithPassword,
        };
      default:
        throw const FoundationException('unsupported_action', '不支持的教务操作。');
    }
  }

  Future<Map<String, dynamic>> _logout() async {
    cancel();
    final pending = _requests.toList();
    await Future.wait(
      pending.map((request) async {
        try {
          await request;
        } catch (_) {}
      }),
    );
    await auth.logout();
    return {'ok': true, 'state': 'idle'};
  }
}
