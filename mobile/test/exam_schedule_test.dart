import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/academic.dart';
import 'package:wust_wiki/countdown.dart';
import 'package:wust_wiki/daily_timeline.dart';
import 'package:wust_wiki/exam_schedule.dart';
import 'package:wust_wiki/foundation/client.dart';

class _ExamSource implements FoundationApi {
  final arrival = Completer<Json>();
  int queries = 0;

  @override
  void cancel() {}

  @override
  Future<Json> request(Json input) {
    queries++;
    return arrival.future;
  }
}

Json _row(String name, String time) => {
  'title': name,
  'fields': [
    {'name': '时间', 'value': time},
    {'name': '场地', 'value': '合成考场'},
  ],
};

void main() {
  testWidgets('窄屏时间轴只显示实课范围，当前时间标记跟随当天刻度', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: DailyTimeline(
              segments: [
                (start: 500, end: 600, color: Colors.blue),
                (start: 840, end: 940, color: Colors.teal),
              ],
              now: 790,
            ),
          ),
        ),
      ),
    );
    expect(find.text('现在 13:10'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('按北京时间解释教务时间，去重并筛选接下来的十四天', () {
    final near = _row('两周内考试', '2026-12-02 08:30～10:00');
    final list = readScheduledExams([
      near,
      near,
      _row('两周外考试', '2026-12-21 08:30～10:00'),
      _row('日期待定', ''),
      _row('错误日期', '2026-11-31 08:30'),
    ]);
    expect(list.length, 4);
    expect(list.first.startsAt, DateTime.utc(2026, 12, 2, 0, 30));
    expect(list.last.startsAt, isNull);
    expect(
      upcomingExams(
        list,
        DateTime.utc(2026, 11, 25),
        within: const Duration(days: 14),
      ).map((e) => e.name),
      ['两周内考试'],
    );
  });

  testWidgets('教务默认查询与自动同步合并，考试自动出现且退出后清除', (tester) async {
    final source = _ExamSource();
    final store = AcademicStore(foundation: source)
      ..token = 'local'
      ..initialized = true;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      platform,
      (call) async => call.method == 'loadCountdowns' ? '[]' : null,
    );
    addTearDown(() => messenger.setMockMethodCallHandler(platform, null));
    final explicit = store.queryService('exams');
    await tester.pumpWidget(MaterialApp(home: CountdownPage(store: store)));
    await tester.pumpAndSettle();
    final tomorrow = DateTime.now().toUtc().add(const Duration(hours: 32));
    source.arrival.complete({
      'result': {
        'rows': [
          _row(
            '合成期末考试',
            '${tomorrow.toIso8601String().substring(0, 10)} 18:30～20:00',
          ),
          _row('时间待定的考试', ''),
        ],
      },
    });
    await tester.pumpAndSettle();
    await explicit;
    expect(source.queries, 1);
    expect(find.text('合成期末考试'), findsOneWidget);
    expect(find.text('时间待定的考试'), findsOneWidget);
    await store.remember('', 0);
    await tester.pumpAndSettle();
    expect(find.text('合成期末考试'), findsNothing);
    expect(find.text('添加倒计时'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
