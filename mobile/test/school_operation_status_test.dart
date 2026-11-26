import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/foundation/client.dart';
import 'package:wust_wiki/foundation/progress.dart';
import 'package:wust_wiki/school_operation_status.dart';

class _Api extends FoundationProgressHub implements FoundationApi {
  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> input) async => {};
}

void main() {
  test(
    'Completion or cancellation of an old request cannot clear a newer status',
    () {
      final hub = FoundationProgressHub();
      final old = hub.begin('正在查询课表', resource: 'schedule');
      hub.cancel();
      final next = hub.begin('正在查询图书馆', resource: 'library');
      hub.update(old, '迟到的旧消息');
      hub.finish(old);
      expect(hub.currentProgress?.message, '正在查询图书馆');
      hub.finish(next);
      expect(hub.currentProgress, isNull);
    },
  );
  testWidgets('A quick query never shows its loading state', (tester) async {
    final api = _Api();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SchoolOperationStatus(api))),
    );
    final id = api.begin('正在查询课表', resource: 'schedule');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('正在查询课表'), findsNothing);
    api.finish(id);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'All services show actual phase, retry count and elapsed waiting time',
    (tester) async {
      final api = _Api();
      final id = api.begin('正在登录统一认证', resource: 'login');
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SchoolOperationStatus(api))),
      );
      expect(find.text('正在登录统一认证'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('正在登录统一认证'), findsOneWidget);
      expect(find.textContaining('已等待'), findsOneWidget);
      api.update(id, '正在验证登录', attempt: 2);
      await tester.pump();
      expect(find.text('正在验证登录'), findsOneWidget);
      expect(find.text('第 2/5 次尝试'), findsOneWidget);
      api.update(id, '正在查询图书馆');
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('正在查询图书馆'), findsOneWidget);
      api.finish(id);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
