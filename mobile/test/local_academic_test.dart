import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/academic.dart';
import 'package:wust_wiki/local_academic.dart';
import 'package:wust_wiki/foundation/client.dart';
import 'package:wust_wiki/foundation/transport.dart';

class FakeFoundation implements FoundationApi {
  FakeFoundation(this.handler);
  final Future<Json> Function(Json) handler;
  @override
  Future<Json> request(Json input) => handler(input);
  @override
  void cancel() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  late FakeFoundation foundation;
  var failLogin = false;
  setUp(() {
    calls.clear();
    failLogin = false;
    foundation = FakeFoundation((input) async {
      if (failLogin) throw const FoundationException('query_failed', '合成登录失败');
      calls.add(MethodCall('academic', input));
      final query = input['action'] == 'query';
      return {
        'academicVerified': true,
        'state': query ? 'complete' : 'authenticated',
        if (query)
          'result': {
            'rows': [
              {
                'title': '合成考试',
                'fields': [
                  {'name': '场地', 'value': '测试教室'},
                ],
              },
            ],
          },
      };
    });
    messenger.setMockMethodCallHandler(platform, (call) async {
      calls.add(call);
      if (call.method == 'restore')
        return {'localAvailable': true, 'localSaved': true};
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(platform, null));

  test('重启恢复本机凭据，首次查询先校验，再通过本机接口查询', () async {
    final store = AcademicStore(foundation: foundation);
    await store.init();
    expect(store.localAvailable, isTrue);
    expect(store.token, 'local');
    expect(store.localVerified, isFalse);
    await store.api('query', store.token, resource: 'exams');
    final actions = calls
        .where((call) => call.method == 'academic')
        .map((call) => (call.arguments as Map)['action']);
    expect(actions, ['inspect', 'query']);
    expect(store.localVerified, isTrue);
    await store.logout();
    expect(store.loggedIn, isFalse);
    expect(store.schedule, isNull);
    expect(
      (calls.lastWhere((call) => call.method == 'academic').arguments
          as Map)['action'],
      'logout',
    );
  });

  test('本机凭据已删除时不恢复遗留登录标记', () async {
    messenger.setMockMethodCallHandler(
      platform,
      (call) async => call.method == 'restore'
          ? {'token': 'local', 'localAvailable': true, 'localSaved': false}
          : null,
    );
    final store = AcademicStore(foundation: foundation);
    await store.init();
    expect(store.loggedIn, isFalse);
  });

  test('校园 TGT 缺失时保留教务已验证状态与课表', () async {
    final store = AcademicStore(
      foundation: FakeFoundation((_) async {
        throw const FoundationException('tgt_required', '需要学校授权');
      }),
    );
    await store.init();
    store.localVerified = true;
    store.acceptCache({
      'lessons': <Json>[],
    }, DateTime.now().millisecondsSinceEpoch + 60000);
    await expectLater(
      store.queryService('library'),
      throwsA(
        isA<AcademicApiException>().having(
          (e) => e.code,
          'code',
          'tgt_required',
        ),
      ),
    );
    expect(store.loggedIn, isTrue);
    expect(store.localVerified, isTrue);
    expect(store.schedule, isNotNull);
    store.dispose();
  });

  test('切换账号失败不显示前一个账号的课表或已验证状态', () async {
    final store = AcademicStore(foundation: foundation);
    await store.init();
    store.acceptCache({
      'lessons': <Json>[
        {'name': '旧账号合成课程'},
      ],
    }, DateTime.now().millisecondsSinceEpoch + 60000);
    store.localVerified = true;
    failLogin = true;
    await expectLater(
      store.loginLocal('other-synthetic-account', 'synthetic-password'),
      throwsA(isA<AcademicApiException>()),
    );
    expect(store.schedule, isNull);
    expect(store.loggedIn, isFalse);
    expect(store.localVerified, isFalse);
  });

  testWidgets('密码隐藏输入并交给本机模块，成功后清空输入', (tester) async {
    final store = AcademicStore(foundation: foundation);
    await store.init();
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LocalAcademicLogin(
          store,
          onLegacy: () {},
          onClose: () => closed = true,
        ),
      ),
    );
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    await tester.enterText(fields.at(0), 'synthetic-account');
    await tester.enterText(fields.at(1), 'synthetic-password');
    await tester.tap(find.text('登录并保存'));
    await tester.pumpAndSettle();
    final login = calls.firstWhere(
      (call) =>
          call.method == 'academic' &&
          (call.arguments as Map)['action'] == 'login',
    );
    expect((login.arguments as Map)['username'], 'synthetic-account');
    expect((login.arguments as Map)['password'], 'synthetic-password');
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
    expect(closed, isTrue);
  });

  testWidgets('密码错误后清空密码并在输入框提示修改，不发起重试', (tester) async {
    var requests = 0;
    final store = AcademicStore(
      foundation: FakeFoundation((input) async {
        requests++;
        throw const FoundationException(
          'credentials_rejected',
          'synthetic rejection',
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LocalAcademicLogin(store, onLegacy: () {}, onClose: () {}),
      ),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '123456');
    await tester.enterText(fields.last, 'rejected-fixture');
    await tester.tap(find.text('登录并保存'));
    await tester.pumpAndSettle();
    expect(find.text('账号或密码错误，请修改后重新登录'), findsOneWidget);
    expect(tester.widget<TextField>(fields.last).controller!.text, isEmpty);
    expect(find.text('取消登录'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(requests, 1);
  });

  testWidgets('原学校网页与微信入口保留', (tester) async {
    final store = AcademicStore(foundation: foundation);
    await store.init();
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LocalAcademicLogin(store, onLegacy: () => opened = true),
      ),
    );
    await tester.ensureVisible(find.text('学校网页 / 微信登录'));
    await tester.tap(find.text('学校网页 / 微信登录'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('新增考试页面显示学校字段，查询走本机接口', (tester) async {
    final store = AcademicStore(foundation: foundation);
    await store.init();
    await tester.pumpWidget(
      MaterialApp(home: FoundationResourcePage(store, 'exams', '考试安排')),
    );
    await tester.pumpAndSettle();
    expect(find.text('合成考试'), findsOneWidget);
    expect(find.textContaining('测试教室'), findsOneWidget);
    expect(
      calls.where(
        (call) =>
            call.method == 'academic' &&
            (call.arguments as Map)['resource'] == 'exams',
      ),
      hasLength(1),
    );
  });
}
