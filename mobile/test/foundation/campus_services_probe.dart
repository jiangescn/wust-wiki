import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../lib/foundation/campus_parsers.dart';
import '../../lib/foundation/campus_services.dart';
import '../../lib/foundation/platform.dart';
import '../../lib/foundation/transport.dart';
import 'campus_fixtures.dart';

class CampusFakeRequest {
  CampusFakeRequest(
    this.uri,
    this.method,
    this.form,
    this.body,
    this.headers,
    this.follow,
  );
  final Uri uri;
  final String method;
  final Map<String, String>? form;
  final Object? body;
  final Map<String, String> headers;
  final bool follow;
}

class CampusFakeTransport extends SchoolTransport {
  CampusFakeTransport(this.handle);
  final FutureOr<SchoolResponse> Function(CampusFakeRequest request) handle;
  final requests = <CampusFakeRequest>[];
  @override
  Future<SchoolResponse> send(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
    List<MapEntry<String, String>>? formFields,
    Object? jsonBody,
    Map<String, String> headers = const {},
    bool followRedirects = true,
  }) async {
    final request = CampusFakeRequest(
      uri,
      method,
      form,
      jsonBody,
      headers,
      followRedirects,
    );
    requests.add(request);
    return handle(request);
  }
}

class CampusFakePlatform implements FoundationPlatform {
  final values = <String, String>{};
  final calls = <(String, Map<String, dynamic>)>[];
  @override
  Future<void> clear(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> load(String key) async => values[key];
  @override
  Future<void> save(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<Map<String, dynamic>> invoke(
    String operation, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    calls.add((operation, arguments));
    if (operation == 'digest')
      return {'data': base64Encode(List<int>.generate(16, (i) => i))};
    if (operation == 'decodeText') return {'text': campusNoticeListFixture};
    throw StateError('unexpected platform operation $operation');
  }
}

SchoolResponse _reply(
  CampusFakeRequest r,
  Object? body, {
  int status = 200,
  Map<String, String> headers = const {},
  Uri? uri,
}) => SchoolResponse(
  status: status,
  uri: uri ?? r.uri,
  bytes: Uint8List.fromList(
    body is String ? utf8.encode(body) : utf8.encode(jsonEncode(body)),
  ),
  headers: headers,
);

String _savedCredential({
  String id = 'fixture-user',
  String token = 'synthetic-only-token',
}) => CampusLaundryCredential(
  id,
  token,
  DateTime.utc(2001),
  DateTime.utc(2001, 1, 1, 0, 1),
).encode();

Future<int> runCampusServiceChecks() async {
  var checks = 0;
  void check(bool value, String description) {
    if (!value) throw StateError(description);
    checks++;
  }

  Future<void> rejects(String code, Future<Object?> Function() action) async {
    try {
      await action();
    } on FoundationException catch (error) {
      check(error.code == code, 'expected $code, got ${error.code}');
      return;
    }
    throw StateError('expected $code');
  }

  final transports = <CampusFakeTransport>[];
  CampusFakeTransport transport(
    FutureOr<SchoolResponse> Function(CampusFakeRequest) handle,
  ) {
    final result = CampusFakeTransport(handle);
    transports.add(result);
    return result;
  }

  try {
    final noHTTP = transport(
      (r) => throw StateError('must not make a request'),
    );
    final platform = CampusFakePlatform();
    final missing = CampusServices(noHTTP, platform);
    for (final resource in [
      'library',
      'library-search',
      'shuttle',
      'second-class',
    ]) {
      await rejects('tgt_required', () => missing.query(resource));
    }
    await rejects(
      'laundry_login_required',
      () => missing.query('laundry-orders'),
    );
    await rejects(
      'unsupported_url',
      () => missing.query('notices', options: {'url': 'https://example.test/'}),
    );
    await rejects(
      'unsupported_url',
      () => missing.query(
        'notice-file',
        options: {
          'url': 'https://example.test/file.pdf',
          'sourceURL': 'https://www.wust.edu.cn/info/1/2.htm',
        },
      ),
    );
    final home = await missing.query('laundry');
    final smsForm = await missing.query('laundry-sms');
    check(
      noHTTP.requests.isEmpty &&
          (home['actions'] as List).length == 3 &&
          smsForm['controls'].length == 2,
      'initialization and SMS form never send SMS',
    );
    await rejects(
      'invalid_phone_number',
      () => missing.query(
        'laundry-sms',
        options: {'action': 'send', 'phone': 'invalid'},
      ),
    );
    await rejects(
      'invalid_sms_code',
      () => missing.query(
        'laundry-login',
        options: {
          'action': 'login',
          'phone': '10000000000',
          'smsCode': 'invalid',
        },
      ),
    );

    final noticeHTTP = transport(
      (r) => _reply(
        r,
        r.uri.path.endsWith('.pdf')
            ? '%PDF-fixture'
            : r.uri.path.contains('/info/')
            ? campusNoticeDetailFixture
            : campusNoticeListFixture,
      ),
    );
    final notice = CampusServices(noticeHTTP, platform);
    final list = await notice.query('notices');
    check(
      list['rows'].length == 2 && list['actions'].length == 2,
      'notice list rows and pagination actions',
    );
    final action = list['rows'][0]['action'];
    final detail = await notice.query(
      action['resource'],
      options: campusMap(action['options']),
    );
    check(
      detail['title'] == '合成详情' && detail['rows'].length == 6,
      'notice detail content and resources',
    );
    final pdfAction = detail['actions'][0];
    final file = await notice.query(
      pdfAction['resource'],
      options: campusMap(pdfAction['options']),
    );
    check(
      file['files'][0]['mime'] == 'application/pdf' &&
          utf8.decode(base64Decode(file['files'][0]['base64'])) ==
              '%PDF-fixture',
      'PDF export contract',
    );
    check(
      noticeHTTP.requests.last.headers['Referer'] ==
          'https://www.wust.edu.cn/info/1001/123.htm',
      'PDF article referer',
    );
    final badRedirect = transport(
      (r) => _reply(
        r,
        campusNoticeListFixture,
        uri: Uri.parse('https://example.test/index/tzgg.htm'),
      ),
    );
    await rejects(
      'unexpected_redirect',
      () => CampusServices(badRedirect, platform).query('notices'),
    );
    final invalidPDF = transport((r) => _reply(r, '<html>login</html>'));
    await rejects(
      'invalid_document',
      () => CampusServices(invalidPDF, platform).query(
        'notice-file',
        options: {
          'url': 'https://www.wust.edu.cn/test.pdf',
          'sourceURL': 'https://www.wust.edu.cn/info/1/2.htm',
        },
      ),
    );
    final gbkHTTP = transport(
      (r) => SchoolResponse(
        status: 200,
        uri: r.uri,
        bytes: Uint8List.fromList([0xd6, 0xd0]),
        headers: {'content-type': 'text/html; charset=gb2312'},
      ),
    );
    check(
      (await CampusServices(
            gbkHTTP,
            platform,
          ).query('notices'))['rows'].length ==
          2,
      'declared GBK fallback',
    );
    check(
      platform.calls.last.$1 == 'decodeText' &&
          platform.calls.last.$2['data'] == '1tA=' &&
          platform.calls.last.$2['charset'] == 'GB18030',
      'Base64 native charset contract',
    );
    final invalidUTF8 = transport(
      (r) => SchoolResponse(
        status: 200,
        uri: r.uri,
        bytes: Uint8List.fromList([0xff]),
      ),
    );
    await rejects(
      'invalid_encoding',
      () => CampusServices(invalidUTF8, platform).query('notices'),
    );

    var initialized = false;
    final secondHTTP = transport((r) {
      check(
        r.method == 'POST' && !r.follow,
        'second class POST without redirects',
      );
      if (r.uri.path.endsWith('getAppConfig.do')) {
        initialized = true;
        check(
          r.uri.queryParameters['appId'] == '5446046383738452',
          'second class app config',
        );
        return _reply(r, {'MODULES': []});
      }
      check(initialized, 'second class initializes before grades');
      return _reply(
        r,
        r.uri.path.endsWith('getCj.do')
            ? campusSecondClassFixture
            : {
                'code': 0,
                'data': {'ZXF': 1.5, 'PJ': '合成评价'},
              },
      );
    });
    final second = await CampusServices(
      secondHTTP,
      platform,
      credential: () async => 'TGT-synthetic',
    ).query('second-class');
    check(
      second['rows'].length == 3 &&
          second['rows'][1]['fields'].any(
            (f) => f['name'] == '选修已获' && f['value'] == '1.5',
          ),
      'second class visible elective credit',
    );

    var libraryAuthenticated = false;
    final libraryHTTP = transport((r) {
      if (r.uri.host == 'auth.wust.edu.cn') {
        check(
          r.form!['service'] ==
              'https://libsys.wust.edu.cn:443/meta-local/opac/cas/rosetta',
          'library CAS service exact',
        );
        return _reply(r, 'ST-synthetic');
      }
      if (r.uri.path.endsWith('/rosetta')) {
        libraryAuthenticated = true;
        return _reply(r, '<html>index</html>');
      }
      if (!libraryAuthenticated) return _reply(r, {}, status: 302);
      if (r.uri.path.endsWith('/stats'))
        return _reply(r, {
          'code': 200,
          'data': {
            'loanCount': '0',
            'fineSum': '1.25',
            'requestCount': 0,
            'booklistCount': 1,
          },
        });
      if (r.uri.path.endsWith('/tree'))
        return _reply(r, {
          'data': [
            {
              '_id': 'fixture-list',
              'booklistName': '合成目录',
              'description': '合成资料',
            },
          ],
        });
      if (r.uri.path.endsWith('/info'))
        return _reply(r, {
          'code': 0,
          'data': {'_id': 'fixture-list', 'booklistName': '合成目录'},
        });
      if (r.uri.path.endsWith('/detls')) {
        check(
          r.method == 'POST' && campusMap(r.body)['page'] == 1,
          'library booklist JSON pagination',
        );
        return _reply(r, {
          'currentPage': 1,
          'pageSize': 10,
          'totalPage': 2,
          'total': 12,
          'items': [
            {
              'title': '合成书目',
              'bibAttrs': {'isbn': 'synthetic-isbn'},
            },
          ],
        });
      }
      if (r.uri.path.endsWith('/requests/list')) {
        check(
          r.uri.queryParameters['requestFlagStatus'] == 'all' &&
              r.uri.queryParameters['processStatus'] == '0',
          'library request filters',
        );
        return _reply(r, {
          'currentPage': 1,
          'pageSize': 5,
          'totalPage': 0,
          'total': 0,
          'items': [],
        });
      }
      if (r.uri.path.endsWith('/fines'))
        return _reply(r, {
          'currentPage': 1,
          'pageSize': 10,
          'totalPage': 0,
          'total': 0,
          'items': [],
        });
      return _reply(r, {'code': 0, 'data': []});
    });
    final library = CampusServices(
      libraryHTTP,
      platform,
      credential: () async => 'TGT-synthetic',
    );
    final dashboard = await library.query('library');
    check(
      dashboard['rows'].length == 3 &&
          libraryHTTP.requests
                  .where((r) => r.uri.path.endsWith('/rosetta'))
                  .length ==
              2,
      'library authentication and dashboard sections',
    );
    check(
      (await library.query(
        'library-profile',
      ))['rows'][0]['fields'].any((f) => f['value'] == '1.25'),
      'library preserves fine decimal',
    );
    final search = await library.query(
      'library-search',
      options: {'keyword': '合成'},
    );
    check(
      search['rows'].length == 1 &&
          search['controls'][0]['label'] == '书单目录名称筛选',
      'booklist directory search contract',
    );
    final info = await library.query(
      'library-booklist',
      options: {'id': 'fixture-list'},
    );
    check(
      info['actions'][0]['resource'] == 'library-booklist-books',
      'booklist info action',
    );
    final books = await library.query(
      'library-booklist-books',
      options: {'id': 'fixture-list'},
    );
    check(
      books['rows'][0]['fields'].any(
            (f) =>
                f['name'] == 'bibAttrs' &&
                f['value'].contains('synthetic-isbn'),
          ) &&
          books['actions'].length == 2,
      'booklist attributes and next page',
    );
    check(
      (await library.query('library-loans'))['rows'].isEmpty,
      'confirmed empty loan list',
    );
    check(
      (await library.query('library-requests'))['rows'].isEmpty,
      'confirmed empty requests',
    );
    check(
      (await library.query('library-fines'))['rows'].isEmpty,
      'confirmed empty fines',
    );
    await rejects(
      'invalid_booklist_id',
      () => library.query('library-booklist', options: {'id': '../escape'}),
    );
    await rejects(
      'invalid_pagination',
      () => library.query('library-loans', options: {'pageSize': 101}),
    );
    final libraryError = transport(
      (r) => _reply(r, {'code': 403, 'data': null}),
    );
    await rejects(
      'library_rejected_403',
      () => CampusServices(
        libraryError,
        platform,
        credential: () async => 'TGT-synthetic',
      ).query('library'),
    );

    var portalAuthenticated = false;
    final portalHTTP = transport((r) {
      if (r.uri.host == 'auth.wust.edu.cn') return _reply(r, 'ST-synthetic');
      if (r.uri.path == '/auth')
        return _reply(
          r,
          '',
          status: 302,
          headers: {
            'location':
                'https://auth.wust.edu.cn/lyuapServer/login?service=https%3A%2F%2Fportal.wust.edu.cn%2Fshiro-cas',
          },
        );
      if (r.uri.path == '/shiro-cas')
        return _reply(
          r,
          '',
          status: 302,
          headers: {
            'location':
                '/#/index70?Authorization=synthetic%2Bauthorization%26test%3Dvalue',
            'set-cookie': 'XSRF-TOKEN=synthetic%2Bxsrf; Path=/',
          },
        );
      if (r.uri.path == '/tryLoginUserInfo') {
        if (!portalAuthenticated && r.headers['Authorization'] == 'undefined')
          return _reply(r, {
            'meta': {'statusCode': 401, 'success': false},
          });
        check(
          r.headers['Authorization'] == 'synthetic+authorization&test=value',
          'portal callback authorization',
        );
        check(
          r.headers['csrfToken'] == '000102030405060708090a0b0c0d0e0f',
          'MD5 Base64 result converted to hex',
        );
        portalAuthenticated = true;
        return _reply(r, {
          'meta': {'success': true, 'statusCode': 200},
          'data': {
            'userId': 42,
            'orgId': 'org',
            'departmentId': 7,
            'accessToken': 'synthetic-access',
          },
        });
      }
      check(
        r.headers['loginUserId'] == '42' &&
            r.headers['loginUserDeptId'] == '7' &&
            r.headers['X-XSRF-TOKEN'] == 'synthetic+xsrf',
        'portal IDs and XSRF cookie',
      );
      check(
        r.uri.path.endsWith('/e05973ba27214e7a97234733848f05d5'),
        'portal schedule card',
      );
      return _reply(r, {
        'meta': {'success': true, 'statusCode': 200},
        'data': {
          'contentDisplay': {'html': campusShuttleFixture},
        },
      });
    });
    final shuttle = await CampusServices(
      portalHTTP,
      platform,
      credential: () async => 'TGT-synthetic',
    ).query('shuttle');
    check(shuttle['rows'].length == 2, 'authenticated shuttle schedule');
    final digests = platform.calls.where((c) => c.$1 == 'digest').toList();
    check(
      digests.every(
        (c) =>
            c.$2['algorithm'] == 'MD5' &&
            RegExp(
              r'^timestamp=[0-9]+,key=lianyi2019$',
            ).hasMatch(utf8.decode(base64Decode(c.$2['data']))),
      ),
      'shuttle signature uses exact upstream bytes',
    );

    final smsPlatform = CampusFakePlatform();
    final smsHTTP = transport((r) {
      check(
        r.headers['Cookie'] == '' && !r.follow,
        'laundry disables cookies and redirects',
      );
      if (r.uri.path == '/common/isNeedCaptcha')
        return _reply(r, {'code': 0, 'data': false});
      if (r.uri.path == '/common/sms/sendCode') {
        check(r.form!['template'] == 'reg', 'SMS registration template');
        return _reply(r, {'code': 0});
      }
      if (r.uri.path == '/user/reg') {
        check(
          r.form!['channel'] == 'ios_app' && r.form!['verify'] == '123456',
          'laundry login form',
        );
        return _reply(r, {
          'code': 0,
          'data': {'token': 'synthetic-only-token'},
        });
      }
      if (r.uri.path == '/user/info')
        return _reply(r, {
          'code': 0,
          'data': {'id': 42},
        });
      throw StateError('unexpected SMS request');
    });
    final sms = CampusServices(smsHTTP, smsPlatform);
    await sms.query(
      'laundry-sms',
      options: {'action': 'send', 'phone': '10000000000'},
    );
    check(
      smsHTTP.requests.length == 2,
      'explicit SMS action preflight then send',
    );
    await sms.query(
      'laundry-login',
      options: {'action': 'login', 'phone': '10000000000', 'smsCode': '123456'},
    );
    final stored = CampusLaundryCredential.decode(
      smsPlatform.values['laundry']!,
    );
    check(
      stored.userID == '42' && stored.token == 'synthetic-only-token',
      'login validates user before secure persistence',
    );
    await sms.query('laundry-login', options: {'action': 'restore'});
    check(
      CampusLaundryCredential.decode(
            smsPlatform.values['laundry']!,
          ).firstVerifiedAt ==
          stored.firstVerifiedAt,
      'restore preserves first verification date',
    );
    smsPlatform.values['laundry'] = _savedCredential();
    await rejects(
      'account_mismatch',
      () => sms.query('laundry-login', options: {'action': 'restore'}),
    );
    await rejects(
      'unexpected_web_origin',
      () => sms.query(
        'laundry-login',
        options: {
          'action': 'web-token',
          'origin': 'https://h5.qiekj.com.evil.test',
          'token': 'synthetic-only-token',
        },
      ),
    );
    await sms.query('laundry-login', options: {'action': 'clear'});
    check(
      !smsPlatform.values.containsKey('laundry'),
      'clear only laundry credential',
    );
    final captchaHTTP = transport((r) => _reply(r, {'code': 0, 'data': true}));
    await rejects(
      'captcha_required',
      () => CampusServices(captchaHTTP, platform).query(
        'laundry-sms',
        options: {'action': 'send', 'phone': '10000000000'},
      ),
    );
    check(captchaHTTP.requests.length == 1, 'captcha prevents SMS send');

    final orderPlatform = CampusFakePlatform()
      ..values['laundry'] = _savedCredential(token: 'synthetic+token');
    Map<String, dynamic> order(
      String id, {
      int status = 2,
      String type = laundryWasherType,
    }) => {
      'id': id,
      'orderType': 1,
      'orderStatus': status,
      'parentTypeId': type,
      'machineName': '合成设备',
      'shopName': '合成门店',
      'machineFunctionName': '标准洗',
    };
    final orderHTTP = transport((r) {
      if (r.uri.path == '/order/list') {
        check(
          r.method == 'GET' &&
              r.uri.queryParameters['token'] == 'synthetic+token' &&
              r.uri.query.contains('token=synthetic%2Btoken'),
          'order list GET preserves plus-safe token form',
        );
        final items = r.uri.queryParameters['page'] == '1'
            ? [
                for (var i = 0; i < 9; i++) order('done-$i', status: 3),
                order('running-other', type: 'other'),
              ]
            : [order('running-washer'), order('completed', status: 3)];
        return _reply(r, {
          'code': 0,
          'data': {'total': 12, 'items': items},
        });
      }
      if (r.uri.path == '/order/detail')
        return _reply(
          r,
          {
            'code': 0,
            'data': {
              ...order(r.form!['orderId']!),
              'completeTime': '2026-11-09 21:02:22',
            },
          },
          headers: {'date': 'Mon, 09 Nov 2026 13:00:00 GMT'},
        );
      throw StateError('unexpected order path');
    });
    final orders = CampusServices(orderHTTP, orderPlatform);
    final running = await orders.query(
      'laundry-orders',
      options: {'running': true},
    );
    check(
      running['rows'].length == 1 &&
          running['snapshots'][0]['remainingSeconds'] == 142 &&
          orderHTTP.requests.length == 3,
      'running washer on later page uses server time',
    );
    final single = await orders.query(
      'laundry-order',
      options: {'orderId': 'running-washer'},
    );
    check(
      single['snapshot']['remainingSeconds'] == 142 &&
          orderHTTP.requests.length == 3,
      'monitor cache uses remaining-time lifetime',
    );
    await orders.query(
      'laundry-order',
      options: {'orderId': 'running-washer', 'refresh': true},
    );
    check(
      orderHTTP.requests.length == 4,
      'force refresh bypasses monitor cache',
    );
    final expired = transport((r) => _reply(r, {'code': 2, 'data': null}));
    await rejects(
      'laundry_login_required',
      () => CampusServices(expired, orderPlatform).query('laundry-orders'),
    );
    check(
      orderPlatform.values.containsKey('laundry'),
      'business rejection does not silently erase credential',
    );
    final failed = transport((r) => _reply(r, {'code': 429, 'data': null}));
    await rejects(
      'laundry_rejected_429',
      () => CampusServices(failed, platform).query('laundry-shops'),
    );

    final devicesHTTP = transport((r) {
      if (r.uri.path == '/shop/nearby/list')
        return _reply(r, {
          'code': 0,
          'data': {
            'total': 11,
            'items': [
              {
                'id': 'fixture-shop',
                'name': '合成门店',
                'machineCount': 3,
                'freeMachine': 3,
                'distance': 120,
              },
            ],
          },
        });
      final items = r.form!['goodsPage'] == '1'
          ? [
              {'id': 'north', 'name': '北楼1'},
              {'id': 'south10', 'name': '南楼10'},
            ]
          : [
              {'id': 'south2', 'name': '南楼2'},
              {'id': 'north', 'name': '北楼1'},
            ];
      return _reply(r, {
        'code': 0,
        'data': {'goodsPage': 2, 'items': items},
      });
    });
    final devices = CampusServices(devicesHTTP, platform);
    final shops = await devices.query('laundry-shops');
    check(
      shops['actions'].length == 2 && shops['rows'][0]['fields'].length == 4,
      'shop fields and pagination',
    );
    final deviceAction = shops['rows'][0]['action'];
    final inventory = await devices.query(
      deviceAction['resource'],
      options: campusMap(deviceAction['options']),
    );
    check(
      inventory['allDevices'].length == 3 &&
          inventory['availableDevices'].map((d) => d['id']).join(',') ==
              'south2,south10,north',
      'inventory combines pages, deduplicates and sorts',
    );
    final partial = await devices.query(
      'laundry-devices',
      options: {'shopId': 'fixture-shop', 'machineCount': 4},
    );
    check(
      partial['allDevices'] == null,
      'partial idle inventory never becomes all-device list',
    );
    final redirectHTTP = transport((r) {
      if (r.uri.host == 'auth.wust.edu.cn') return _reply(r, 'ST-synthetic');
      if (r.uri.path.endsWith('/rosetta'))
        return _reply(
          r,
          '',
          status: 302,
          headers: {'location': 'https://example.test/steal'},
        );
      return _reply(r, {}, status: 302);
    });
    await rejects(
      'unexpected_redirect',
      () => CampusServices(
        redirectHTTP,
        platform,
        credential: () async => 'TGT-synthetic',
      ).query('library'),
    );
    check(
      redirectHTTP.requests.every((r) => r.uri.host.endsWith('.wust.edu.cn')),
      'CAS never follows external origin',
    );
    var secondAuth = false;
    final secondAuthHTTP = transport((r) {
      if (r.uri.host == 'auth.wust.edu.cn') {
        check(
          r.form!['service'] ==
              'https://xg.wust.edu.cn/xsfw/sys/dektapp/*default/index.do',
          'second class CAS service',
        );
        return _reply(r, 'ST-synthetic');
      }
      if (r.uri.path.endsWith('index.do')) {
        secondAuth = true;
        return _reply(r, 'entry');
      }
      if (!secondAuth) return _reply(r, {}, status: 401);
      if (r.uri.path.endsWith('getAppConfig.do'))
        return _reply(r, {'MODULES': []});
      return _reply(
        r,
        r.uri.path.endsWith('getCj.do')
            ? {
                'code': 0,
                'data': {'cj': []},
              }
            : {
                'code': 0,
                'data': {'ZXF': 0, 'PJ': '合成评价'},
              },
      );
    });
    final emptySecond = await CampusServices(
      secondAuthHTTP,
      platform,
      credential: () async => 'TGT-synthetic',
    ).query('second-class');
    check(
      emptySecond['transcript']['categories'].isEmpty &&
          emptySecond['rows'].length == 1,
      'second class retries initialization after CAS',
    );
    final badSecondHTTP = transport(
      (r) => _reply(
        r,
        r.uri.path.endsWith('getAppConfig.do')
            ? {'MODULES': []}
            : {'code': '403', 'data': null},
      ),
    );
    await rejects(
      'second_class_rejected_403',
      () => CampusServices(
        badSecondHTTP,
        platform,
        credential: () async => 'TGT-synthetic',
      ).query('second-class'),
    );
    final businessPortal = transport(
      (r) => _reply(r, {
        'meta': {'success': false, 'statusCode': 422},
        'data': null,
      }),
    );
    await rejects(
      'shuttle_rejected_422',
      () => CampusServices(
        businessPortal,
        platform,
        credential: () async => 'TGT-synthetic',
      ).query('shuttle'),
    );
    final orderGate = Completer<void>();
    final started = Completer<void>();
    final concurrentPlatform = CampusFakePlatform()
      ..values['laundry'] = _savedCredential();
    final concurrentHTTP = transport((r) async {
      if (!started.isCompleted) started.complete();
      await orderGate.future;
      return _reply(
        r,
        {
          'code': 0,
          'data': {...order('shared'), 'completeTime': '2026-11-09 21:02:22'},
        },
        headers: {'date': 'Mon, 09 Nov 2026 13:00:00 GMT'},
      );
    });
    final concurrent = CampusServices(concurrentHTTP, concurrentPlatform);
    final firstOrder = concurrent.query(
      'laundry-order',
      options: {'orderId': 'shared'},
    );
    final secondOrder = concurrent.query(
      'laundry-order',
      options: {'orderId': 'shared'},
    );
    await started.future;
    orderGate.complete();
    await Future.wait([firstOrder, secondOrder]);
    check(
      concurrentHTTP.requests.length == 1,
      'simultaneous order queries share a pending request',
    );
    final staleGate = Completer<void>(), staleStarted = Completer<void>();
    final staleHTTP = transport((r) async {
      staleStarted.complete();
      await staleGate.future;
      return _reply(r, {'code': 0, 'data': order('stale')});
    });
    final stale = CampusServices(staleHTTP, concurrentPlatform);
    final staleResult = rejects(
      'account_changed',
      () => stale.query('laundry-order', options: {'orderId': 'stale'}),
    );
    await staleStarted.future;
    await stale.query('laundry-login', options: {'action': 'clear'});
    staleGate.complete();
    await staleResult;
    var correction = 0;
    final correctionPlatform = CampusFakePlatform()
      ..values['laundry'] = _savedCredential();
    final correctionHTTP = transport((r) {
      correction++;
      if (correction == 2)
        throw const FoundationException('network_error', '合成失败。');
      return _reply(
        r,
        {
          'code': 0,
          'data': {
            ...order('correction'),
            'completeTime': correction == 1
                ? '2026-11-09 21:00:00'
                : '2026-11-09 21:03:00',
          },
        },
        headers: {'date': 'Mon, 09 Nov 2026 13:00:00 GMT'},
      );
    });
    final monitor = CampusServices(correctionHTTP, correctionPlatform);
    check(
      (await monitor.query(
            'laundry-order',
            options: {'orderId': 'correction'},
          ))['snapshot']['remainingSeconds'] ==
          0,
      'zero remaining countdown',
    );
    await rejects(
      'network_error',
      () => monitor.query('laundry-order', options: {'orderId': 'correction'}),
    );
    check(
      (await monitor.query(
            'laundry-order',
            options: {'orderId': 'correction'},
          ))['snapshot']['remainingSeconds'] ==
          180,
      'failed zero-time correction retries and accepts extended order',
    );
    return checks;
  } finally {
    for (final http in transports) {
      http.close();
    }
  }
}

Future<void> main() async {
  print('Campus service checks passed: ${await runCampusServiceChecks()}');
}
