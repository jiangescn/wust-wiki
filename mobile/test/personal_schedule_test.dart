import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wust_wiki/academic.dart';
import 'package:wust_wiki/main.dart';
import 'package:wust_wiki/personal_schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(platform, null));

  test('课程冲突仅报告同周同节的交集', () {
    final original = Lesson({
      'name': '理论课',
      'day': 3,
      'sections': '1-2',
      'weeks': '3,5,7',
    });
    PersonalLesson lab(List<int> weeks) => PersonalLesson(
      const PersonalCourse(
        id: 'course',
        term: '2026-2027-1',
        owner: '',
        name: '实验课',
        times: [],
      ),
      PersonalTime(id: 'slot', day: 3, first: 2, last: 4, weeks: weeks),
      null,
    );
    expect(
      courseConflicts(
        [original],
        [
          lab([2, 4, 6]),
        ],
      ),
      isEmpty,
    );
    expect(
      courseConflicts(
        [original],
        [
          lab([2, 5, 9]),
        ],
      ),
      ['理论课 · 周三 · 第 2 节 · 第 5 周'],
    );
  });

  testWidgets('教务课补录默认按周重复，滑选后的时段可在首页显示并保留', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final today = chinaDay();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final year = today.month >= 8 ? today.year : today.year - 1;
    final semester = today.month >= 8 || today.month == 1 ? 1 : 2;
    final term = '$year-${year + 1}-$semester';
    var saved = jsonEncode({
      'mondays': {term: dateLabel(monday)},
    });
    final now = DateTime.now().millisecondsSinceEpoch;
    const validity = Duration(days: 7);
    var snapshot = jsonEncode({
      'fetchedAt': now,
      'expiresAt': now + validity.inMilliseconds,
      'result': {
        'schoolYear': '$year-${year + 1}',
        'semester': semester,
        'lessons': [
          {
            'name': '数据结构',
            'day': today.weekday,
            'sections': '1-2',
            'weeks': '1-20',
            'location': '教学楼 201',
            'teacher': '张老师',
          },
        ],
      },
    });
    messenger.setMockMethodCallHandler(platform, (call) async {
      switch (call.method) {
        case 'loadAppearance':
          return {'openScheduleOnLaunch': true};
        case 'restore':
          return {'snapshot': snapshot};
        case 'loadPersonalSchedule':
          return saved;
        case 'savePersonalSchedule':
          saved = call.arguments as String;
        case 'save':
          if (call.arguments['snapshot'] case final String value)
            snapshot = value;
      }
      return null;
    });

    await t.runAsync(() async {
      await nativeData;
    });
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    await t.tap(find.text('数据结构'));
    await t.pumpAndSettle();
    await t.tap(find.text('添加上课时间'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(AppBar, '添加上课时间'), findsOneWidget);
    expect(find.text('数据结构'), findsOneWidget);
    expect(find.text('上课日期'), findsNothing);
    expect(find.text('上课周次'), findsOneWidget);
    expect(
      t
          .widgetList<TextFormField>(find.byType(TextFormField))
          .last
          .controller
          ?.text,
      '张老师',
    );
    await t.tap(find.text('上课周次'));
    await t.pumpAndSettle();
    expect(find.text('起始周'), findsNothing);
    expect(find.text('结束周'), findsNothing);
    final dialog = find.byType(Dialog);
    expect(t.getSize(dialog).width, greaterThanOrEqualTo(336));
    Finder week(int number) => find.byKey(ValueKey('course-week-$number'));
    expect(t.getRect(week(2)).left - t.getRect(week(1)).right, 4);
    await t.tap(find.text('清空'));
    final drag = await t.startGesture(t.getCenter(week(1)));
    await drag.moveTo(t.getCenter(week(4)));
    await drag.moveTo(t.getCenter(week(8)));
    await drag.up();
    await t.pumpAndSettle();
    expect(find.text('已选 8 周'), findsOneWidget);
    await t.tap(week(3));
    await t.pumpAndSettle();
    expect(find.text('已选 7 周'), findsOneWidget);
    await t.tap(find.text('确定'));
    await t.pumpAndSettle();
    t
        .widget<DropdownButton<int>>(find.byType(DropdownButton<int>).at(1))
        .onChanged!(3);
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).first, '实验楼 101');
    await t.tap(find.text('保存'));
    await t.pumpAndSettle();
    final course = (jsonDecode(saved)['courses'] as List).single;
    expect(course['supplement'], true);
    expect((course['times'] as List).single['weeks'], [1, 2, 4, 5, 6, 7, 8]);
    expect(find.text('数据结构'), findsNWidgets(2));
    await t.tap(find.text('首页'));
    await t.pumpAndSettle();
    expect(find.textContaining('实验楼 101 · 本机补充'), findsOneWidget);
    await t.tap(find.text('课表'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('课表设置'));
    await t.pumpAndSettle();
    await t.tap(find.text('清除教务缓存'));
    await t.pumpAndSettle();
    await t.tap(find.text('清除'));
    await t.pumpAndSettle();
    expect(find.text('数据结构'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    expect(find.text('数据结构'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('同一自定义课程的多个时段可独立更新并随学期过滤', () async {
    var saved = '';
    messenger.setMockMethodCallHandler(platform, (call) async {
      if (call.method == 'loadPersonalSchedule') return saved;
      if (call.method == 'savePersonalSchedule')
        saved = call.arguments as String;
      return null;
    });
    final store = AcademicStore();
    final term = {'schoolYear': '2026-2027', 'semester': 1};
    store.acceptCache({...term, 'lessons': []}, 0);
    const theory = PersonalTime(
      id: 'theory',
      day: 1,
      first: 1,
      last: 2,
      weeks: [2, 5, 9],
    );
    const lab = PersonalTime(
      id: 'lab',
      day: 4,
      first: 3,
      last: 4,
      weeks: [2, 5, 9],
      place: '实验楼 101',
    );
    final course = PersonalCourse(
      id: 'course',
      term: store.courseTerm,
      owner: '',
      name: '数据结构',
      times: [theory],
    );
    await store.savePersonalCourse(course, monday: autumnStart);
    await store.savePersonalCourse(
      course.withTimes([theory, lab]),
      monday: autumnStart,
    );
    store.acceptCache({
      ...term,
      'lessons': [
        {'name': '新教务课', 'day': 5, 'sections': '3-4', 'weeks': '1-20'},
      ],
    }, 0);
    expect(store.displayedLessons.map((item) => item.name), [
      '新教务课',
      '数据结构',
      '数据结构',
    ]);
    expect(store.displayedLessons.last.weeks, [2, 5, 9]);
    store.acceptCache({
      'schoolYear': '2026-2027',
      'semester': 2,
      'lessons': [],
    }, 0);
    expect(store.displayedLessons, isEmpty);
    store.acceptCache({...term, 'lessons': []}, 0);
    await store.savePersonalCourse(
      course.withTimes([lab]),
      monday: autumnStart,
    );
    final restarted = AcademicStore();
    await restarted.init();
    restarted.acceptCache({...term, 'lessons': []}, 0);
    final remaining = restarted.displayedLessons.single as PersonalLesson;
    expect(remaining.time.id, 'lab');
    expect(remaining.course.id, 'course');
  });
}
