import 'package:wust_wiki/blog_surface.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wust_wiki/main.dart';
import 'package:wust_wiki/academic.dart';
import 'package:wust_wiki/grade_selection.dart';
import 'package:wust_wiki/native_pages.dart';
import 'package:wust_wiki/week.dart';
import 'package:wust_wiki/archive_motion.dart';
import 'package:wust_wiki/wiki_sticker_flight.dart';
import 'package:wust_wiki/countdown.dart';
import 'package:wust_wiki/exam_schedule.dart';
import 'package:wust_wiki/home_agenda.dart';

Future<void> openMoreTools(WidgetTester tester) async {
  final link = find.text('更多工具');
  await tester.ensureVisible(link);
  await tester.tap(link);
  await tester.pumpAndSettle();
}

class ConfirmedSchool extends AcademicStore {
  final calls = <String>[];
  final resources = <String>[];
  @override
  Future<Json> api(String action, String bearer, {String? resource}) async {
    calls.add(action);
    if (resource != null) resources.add(resource);
    final until = DateTime.now().millisecondsSinceEpoch + 60000;
    return switch (action) {
      'start' => {
        'state': 'waiting',
        'sessionToken': 'test',
        'expiresAt': until,
        'schoolLoginUrl':
            'https://auth.wust.edu.cn/authserver/qrCode/qrCodeLogin.do?uuid=demo',
        'qr':
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
      },
      'poll' => {'state': 'authenticated', 'expiresAt': until},
      'query' => {
        'state': 'complete',
        'result': resource == 'grades'
            ? {
                'courses': [
                  {'name': '已同步成绩', 'score': 96},
                ],
              }
            : {'provider': 'wust', 'lessons': []},
      },
      _ => {'state': 'idle'},
    };
  }
}

class RestoredSchool extends AcademicStore {
  final calls = <String>[];
  bool unavailable = true;

  @override
  Future<Json> sendAcademic(Json body, String bearer) async {
    final action = body['action'] as String;
    calls.add(action);
    expect(bearer, 'saved-school-session');
    if (action == 'inspect' && unavailable) {
      throw const AcademicApiException('暂时无法连接学校', 502);
    }
    return {'state': action == 'inspect' ? 'authenticated' : 'complete'};
  }
}

Future<void> chooseWeek(WidgetTester tester, int week) async {
  await tester.tap(find.byTooltip('选择教学周'));
  await tester.pumpAndSettle();
  final strip = find.byWidgetPredicate(
    (w) => w is ListView && w.scrollDirection == Axis.horizontal,
  );
  final scroll = find.descendant(of: strip, matching: find.byType(Scrollable));
  final label = find.descendant(of: strip, matching: find.text('第 $week 周'));
  // Exercise the horizontal picker as a user would, including offscreen weeks.
  final current = tester.state<ScrollableState>(scroll).position;
  if (current.pixels > 0) {
    await tester.drag(strip, const Offset(2200, 0));
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(label, 100, scrollable: scroll);
  await tester.tap(label);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final fixture = {
    'provider': 'wust',
    'schoolYear': '2026-2027',
    'semester': 1,
    'lessons': [
      {
        'name': '数据结构',
        'day': 2,
        'sections': '1-2',
        'weeks': '1-18(单)',
        'location': '教三楼207',
      },
      {
        'name': '大学物理',
        'day': 2,
        'sections': '1-2',
        'weeks': '2-18(双)',
        'location': '教一楼301',
      },
      {
        'name': '大学英语',
        'day': 4,
        'sections': '3-4',
        'weeks': '1',
        'location': '教十一楼107',
      },
    ],
  };
  setUpAll(() async {
    await nativeData;
  });
  setUp(() {
    messenger.setMockMethodCallHandler(
      platform,
      (call) async => call.method == 'restore' ? <String, dynamic>{} : null,
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(platform, null));
  testWidgets('设置可手动切换主题并保存低性能模式', (t) async {
    Map<String, dynamic> saved = {};
    messenger.setMockMethodCallHandler(platform, (call) async {
      if (call.method == 'saveAppearance') {
        saved = Map<String, dynamic>.from(call.arguments as Map);
      }
      return switch (call.method) {
        'loadAppearance' => saved,
        'restore' => <String, dynamic>{},
        _ => null,
      };
    });
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    await t.tap(find.text('个人').last);
    await t.pumpAndSettle();
    await t.tap(find.text('设置'));
    await t.pumpAndSettle();
    await t.tap(find.text('跟随系统'));
    await t.pumpAndSettle();
    await t.tap(find.text('深色').last);
    await t.pumpAndSettle();
    await t.tap(find.text('低性能模式'));
    await t.pumpAndSettle();
    final setting = t.element(find.text('低性能模式'));
    expect(Theme.of(setting).brightness, Brightness.dark);
    expect(MediaQuery.disableAnimationsOf(setting), isTrue);
    expect(saved, {
      'theme': 'dark',
      'lowPerformance': true,
      'openScheduleOnLaunch': false,
    });

    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    final dock = t.element(find.text('个人').last);
    expect(Theme.of(dock).brightness, Brightness.dark);
    expect(MediaQuery.disableAnimationsOf(dock), isTrue);
  });

  testWidgets('启动课表设置仅在下次启动生效，关闭后恢复首页', (t) async {
    var saved = <String, dynamic>{};
    Completer<Map<String, dynamic>>? pendingRestore;
    messenger.setMockMethodCallHandler(platform, (call) async {
      if (call.method == 'saveAppearance') {
        saved = Map<String, dynamic>.from(call.arguments as Map);
        return null;
      }
      return switch (call.method) {
        'loadAppearance' =>
          await (pendingRestore?.future ?? Future.value(saved)),
        'restore' => <String, dynamic>{},
        _ => null,
      };
    });

    Future<void> openSettings() async {
      await t.tap(find.text('个人').last);
      await t.pumpAndSettle();
      await t.tap(find.text('设置'));
      await t.pumpAndSettle();
    }

    final toggle = find.widgetWithText(SwitchListTile, '启动时打开课表');
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    expect(find.text('课表尚未同步'), findsOneWidget);
    await openSettings();
    expect(t.widget<SwitchListTile>(toggle).value, isFalse);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(saved['openScheduleOnLaunch'], isTrue);
    expect(toggle, findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(WeekPage), findsNothing);

    pendingRestore = Completer<Map<String, dynamic>>();
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(const WikiApp());
    expect(find.byType(Dashboard), findsNothing);
    pendingRestore.complete(saved);
    pendingRestore = null;
    await t.pumpAndSettle();
    expect(find.byType(WeekPage), findsOneWidget);
    expect(find.text('课表尚未同步'), findsNothing);
    expect(
      t.getCenter(find.byKey(const ValueKey('wiki-dock-indicator'))).dx,
      closeTo(t.getCenter(find.text('课表')).dx, 1),
    );

    await openSettings();
    expect(t.widget<SwitchListTile>(toggle).value, isTrue);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(saved['openScheduleOnLaunch'], isFalse);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    expect(find.text('课表尚未同步'), findsOneWidget);
    expect(find.byType(WeekPage), findsNothing);
  });

  testWidgets('武科大导航沿用网页版分组并为条目绘制独立的图标', (t) async {
    final store = AcademicStore();
    await t.pumpWidget(
      MaterialApp(
        home: NativePage(store, '/navigation', '武科大导航', selectTab: (_) {}),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('教务学习'), findsOneWidget);
    expect(find.byType(SvgPicture), findsWidgets);
    await t.enterText(find.byType(TextField), '图书馆');
    await t.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '图书馆'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('首页、七天课表、Wiki 分栏', (t) async {
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    final scaffold = t.widget<Scaffold>(find.byType(Scaffold));
    final dock = find.byWidget(scaffold.bottomNavigationBar!);
    final labels = t.widgetList<Text>(
      find.descendant(of: dock, matching: find.byType(Text)),
    );
    expect(labels.map((text) => text.data), ['首页', '课表', '校园', '个人']);
    expect(find.text('课表尚未同步'), findsOneWidget);
    await t.tap(find.text('课表'));
    await t.pumpAndSettle();
    expect(find.text('周日'), findsOneWidget);
    expect(find.text('登录后可同步课表'), findsOneWidget);
    await t.tap(find.text('校园').last);
    await t.pumpAndSettle();
    expect(find.text('校园指南'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('上课时间选择青山后，空课表使用同一作息且没有课程卡', (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    messenger.setMockMethodCallHandler(
      platform,
      (call) async => call.method == 'restore'
          ? {
              'snapshot': jsonEncode({
                'fetchedAt': now,
                'expiresAt': now + 604800000,
                'result': {
                  'provider': 'wust',
                  'schoolYear': '2026-2027',
                  'semester': 1,
                  'lessons': [],
                },
              }),
            }
          : null,
    );
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    await openMoreTools(t);
    await t.ensureVisible(find.text('上课时间'));
    await t.pump();
    await t.tap(find.text('上课时间'));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('青山校区').last);
    await t.pumpAndSettle();
    expect(find.text('08:00 — 08:45'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.tap(find.text('课表').last);
    await t.pumpAndSettle();
    expect(find.text('本学期暂无排课'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('08:20'), findsNothing);
    final grid = find.descendant(
      of: find.byType(WeekPage),
      matching: find.byType(ListView),
    );
    expect(
      find.descendant(of: grid, matching: find.byType(InkWell)),
      findsNothing,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('首页按学习和生活展示全部工具，校园栏目继续展示文章分类', (t) async {
    messenger.setMockMethodCallHandler(
      platform,
      (call) async =>
          call.method == 'restore' ? {'pinnedHomeTools': '/tools/beds'} : null,
    );
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    await t.tap(find.text('今日课表'));
    await t.pumpAndSettle();
    expect(find.text('洗衣机'), findsOneWidget);
    expect(find.text('床铺尺寸'), findsNothing);
    expect(find.text('图书馆'), findsOneWidget);
    expect(find.text('主修进度'), findsOneWidget);
    expect(find.text('常用工具'), findsNothing);
    double toolY(String title) => t.getTopLeft(find.text(title)).dy;
    expect(toolY('学习'), lessThan(toolY('绩点计算')));
    expect(toolY('图书馆'), lessThan(toolY('生活')));
    expect(toolY('生活'), lessThan(toolY('查宿舍')));
    expect(find.text('学生信息'), findsNothing);
    expect(find.text('课表采集'), findsNothing);
    expect(find.text('周边地图'), findsNothing);
    await openMoreTools(t);
    expect(find.text('主修进度'), findsOneWidget);
    expect(find.text('培养方案'), findsOneWidget);
    expect(find.text('图书馆'), findsOneWidget);
    expect(find.text('成绩查询'), findsOneWidget);
    expect(find.text('课表采集'), findsNothing);
    await t.scrollUntilVisible(find.text('查宿舍'), 180);
    await t.pumpAndSettle();
    expect(find.text('查宿舍').hitTestable(), findsOneWidget);
    expect(find.text('床铺尺寸'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.tap(find.text('校园').last);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Coder'));
    await t.pumpAndSettle();
    expect(find.text('技术交流'), findsOneWidget);
    expect(find.text('个人博客'), findsOneWidget);
    expect(find.text('床铺尺寸'), findsNothing);
    expect(find.text('学校简介'), findsNothing);
    await t.tap(find.text('个人').last);
    await t.pumpAndSettle();
    expect(find.text('学校统一认证'), findsOneWidget);
    expect(find.text('成绩查询'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('可在所属分组置顶，重开恢复且可取消', (t) async {
    final preferences = <String, dynamic>{};
    messenger.setMockMethodCallHandler(platform, (call) async {
      if (call.method == 'restore') return preferences;
      if (call.method == 'save') preferences.addAll(Map.from(call.arguments));
      return null;
    });
    bool timesBeforeGpa() {
      final times = t.getTopLeft(find.text('上课时间'));
      final gpa = t.getTopLeft(find.text('绩点计算'));
      return (times.dy - gpa.dy).abs() < .1
          ? times.dx < gpa.dx
          : times.dy < gpa.dy;
    }

    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    expect(timesBeforeGpa(), isFalse);
    await openMoreTools(t);
    final pin = find.byTooltip('固定上课时间到首页');
    await t.ensureVisible(pin);
    await t.tap(pin);
    await t.pumpAndSettle();
    expect(find.byTooltip('取消固定上课时间'), findsOneWidget);
    expect(preferences['pinnedHomeTools'], '/tools/times');

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(timesBeforeGpa(), isTrue);
    await t.ensureVisible(find.text('上课时间'));
    await t.tap(find.text('上课时间'));
    await t.pumpAndSettle();
    expect(find.byType(NativePage), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    expect(timesBeforeGpa(), isTrue);
    await openMoreTools(t);
    final unpin = find.byTooltip('取消固定上课时间');
    await t.ensureVisible(unpin);
    await t.tap(unpin);
    await t.pumpAndSettle();
    expect(preferences['pinnedHomeTools'], '');
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('上课时间'), findsOneWidget);
    expect(timesBeforeGpa(), isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('上课状态与课程同一行，考试时间对齐倒计时右缘', (t) async {
    final exam = ScheduledExam.fromRow({
      'title': '数据结构',
      'fields': [
        {'name': '时间', 'value': '2026-12-02 14:00'},
        {'name': '场地', 'value': '教一楼 204'},
      ],
    });
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Column(
              children: [
                TodayPeriodRow(
                  lesson: Lesson({'name': '线性代数'}),
                  sections: '第 5–6 节',
                  start: '14:00',
                  end: '15:40',
                  now: 14 * 60 + 20,
                  accent: Colors.blue,
                  next: false,
                ),
                HomeExamRow(exam: exam, now: DateTime.utc(2026, 11, 25, 6)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('上课中 · 线性代数'), findsOneWidget);
    final time = find.text('12月2日 14:00');
    expect(t.widget<Text>(time).textAlign, TextAlign.end);
    expect(
      t.getTopRight(time).dx,
      closeTo(t.getTopRight(find.byType(ExamTimeBadge)).dx, .01),
    );
  });

  test('贴纸先揭起上缘，飞到位后从左下角贴平', () {
    const peel = PaperFlightPose(.10);
    expect(peel.depthAt(0), greaterThan(0));
    expect(peel.depthAt(1), 0);
    const contact = PaperFlightPose(.80);
    expect(contact.depthAt(1, column: 0), 0);
    expect(contact.depthAt(0, column: 1), greaterThan(0));
    expect(const PaperFlightPose(1).depthAt(0, column: 1), 0);

    const source = Rect.fromLTWH(0, 100, 32, 32);
    const destination = Rect.fromLTWH(120, 100, 38, 38);
    final track = PaperCoverRectTween(
      begin: source,
      end: destination,
      returning: false,
      heroCurve: true,
    );
    expect(track.transform(Curves.fastOutSlowIn.transform(.10)), source);
    expect(track.lerp(Curves.fastOutSlowIn.transform(.41)).top, lessThan(100));
    expect(track.transform(Curves.fastOutSlowIn.transform(.70)), destination);
  });

  testWidgets('贴纸用纸面网格飞行，贴合时有水纹，路由完成后揭示标题', (t) async {
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    await openMoreTools(t);
    await t.scrollUntilVisible(find.text('上课时间'), 180);
    await t.pump();
    await t.tap(find.text('上课时间'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    await t.pump();
    final sticker = find.byType(WikiStickerRipple).last;
    final water = find.descendant(
      of: sticker,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.foregroundPainter is StickerRipplePainter,
      ),
    );
    expect(water, findsOneWidget);
    final mesh = find.byType(PaperCoverBend);
    expect(mesh, findsOneWidget);
    expect(
      t.renderObject<PaperCoverRender>(mesh).debugMeshDraws,
      greaterThan(0),
    );
    await t.pump(const Duration(milliseconds: 330));
    expect(
      water,
      paints
        ..clipRRect()
        ..circle(),
    );

    final heading = find.byWidgetPredicate(
      (widget) => widget is WikiPageTitle && widget.title == '上课时间',
    );
    final clip = find.descendant(
      of: heading,
      matching: find.byType(ArchiveReveal),
    );
    double visualProgress() =>
        t.renderObject<ArchiveRevealRender>(clip).progress;
    final route = ModalRoute.of(t.element(heading))!;
    expect(
      visualProgress(),
      0,
      reason:
          'route ${route.runtimeType} ${route.animation?.value} ${route.animation?.status}',
    );
    final samples = <double>[];
    for (var frame = 0; frame < 18; frame++) {
      await t.pump(const Duration(milliseconds: 30));
      samples.add(visualProgress());
    }
    expect(samples.any((p) => p > 0 && p < 1), isTrue, reason: '$samples');
    await t.pumpAndSettle();
    expect(t.renderObject<ArchiveRevealRender>(clip).progress, 1);
    await t.binding.handlePopRoute();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump();
    expect(mesh, findsOneWidget);
    expect(
      t.renderObject<PaperCoverRender>(mesh).debugMeshDraws,
      greaterThan(0),
    );
    await t.pumpAndSettle();
    expect(find.text('上课时间').hitTestable(), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('校园入口的原贴图飞到标题后才交接', (t) async {
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    await t.tap(find.text('校园').last);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, '学习'));
    await t.pumpAndSettle();
    await t.tap(find.text('竞赛与证书'));
    await t.pump();

    final faces = find.descendant(
      of: find.byType(WikiStickerRipple),
      matching: find.byType(FadeTransition),
    );
    List<double> opacity() => t
        .widgetList<FadeTransition>(faces)
        .map((face) => face.opacity.value)
        .toList();

    await t.pump(const Duration(milliseconds: 300));
    expect(faces, findsNWidgets(2));
    expect(opacity().first, greaterThan(.99));
    expect(opacity().last, lessThan(.01));

    await t.pump(const Duration(milliseconds: 260));
    expect(opacity().first, lessThan(.25));
    expect(opacity().last, greaterThan(.75));
    await t.pumpAndSettle();
    expect(find.byType(WikiStickerRipple), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('底栏随手移动指示器，松手后选中栏目，连点以最后一栏为准', (t) async {
    t.view.padding = FakeViewPadding(bottom: 24 * t.view.devicePixelRatio);
    addTearDown(t.view.resetPadding);
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    final indicator = find.byKey(const ValueKey('wiki-dock-indicator'));
    double indicatorX() => t.getCenter(indicator).dx;

    final home = t.getCenter(find.text('首页').last);
    final campus = t.getCenter(find.text('校园').last);
    final campusButton = find.ancestor(
      of: find.text('校园').last,
      matching: find.byType(InkWell),
    );
    final scaffold = t.widget<Scaffold>(find.byType(Scaffold).first);
    final dockBar = find.byWidget(scaffold.bottomNavigationBar!);
    final buttonHeight = t.getSize(campusButton).height;
    expect(buttonHeight, greaterThan(56));
    expect(t.getSize(dockBar).height, buttonHeight + 24);
    expect(
      t.widget<InkWell>(campusButton).splashFactory,
      NoSplash.splashFactory,
    );
    expect(t.widget<InkWell>(campusButton).highlightColor, Colors.transparent);
    expect(
      find.descendant(
        of: campusButton,
        matching: find.byType(WikiStickerRipple),
      ),
      findsNothing,
    );
    final gesture = await t.startGesture(home);
    await gesture.moveBy(const Offset(28, 0));
    await gesture.moveTo(Offset(campus.dx - 24, home.dy));
    await t.pump();
    expect(indicatorX(), inExclusiveRange(home.dx, campus.dx));
    expect(find.text('今日课表'), findsOneWidget);
    await gesture.up();
    await t.pumpAndSettle();
    expect(indicatorX(), closeTo(campus.dx, 1));
    expect(find.text('校园指南'), findsOneWidget);

    await t.tap(find.text('个人').last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 72));
    await t.tapAt(home);
    await t.pumpAndSettle();
    expect(indicatorX(), closeTo(home.dx, 1));
    expect(find.text('今日课表'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('减少动态时切栏首帧到位，工具页仍可返回', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Dashboard(),
        ),
      ),
    );
    await t.pumpAndSettle();
    final indicator = find.byKey(const ValueKey('wiki-dock-indicator'));
    final campus = find.text('校园').last;
    final campusX = t.getCenter(campus).dx;
    await t.tap(campus);
    await t.pump();
    expect(t.getCenter(indicator).dx, closeTo(campusX, 1));
    expect(find.text('校园指南'), findsOneWidget);
    await t.tap(find.text('首页').last);
    await t.pump();
    await openMoreTools(t);
    await t.scrollUntilVisible(find.text('上课时间'), 180);
    await t.pump();
    await t.tap(find.text('上课时间'));
    await t.pumpAndSettle();
    expect(find.text('08:20 — 09:05'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('上课时间').hitTestable(), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('考试倒计时数字有独立的醒目字号', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ExamTimeBadge(Duration(days: 7, hours: 1))),
      ),
    );
    final text = t.widget<Text>(find.text('还有 7 天'));
    final span = text.textSpan! as TextSpan;
    final count = span.children!.first as TextSpan;
    expect(count.text, '7');
    expect(count.style!.fontSize, greaterThan(text.style!.fontSize!));
  });

  testWidgets('首尾栏的蓝色指示器越过中心后回弹', (t) async {
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    final indicator = find.byKey(const ValueKey('wiki-dock-indicator'));
    final home = t.getCenter(find.text('首页').last);
    final profile = t.getCenter(find.text('个人').last);

    Future<List<double>> changeTab(Offset target) async {
      await t.tapAt(target);
      final centers = <double>[];
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 16));
        centers.add(t.getCenter(indicator).dx);
      }
      await t.pumpAndSettle();
      expect(t.getCenter(indicator).dx, closeTo(target.dx, 1));
      return centers;
    }

    expect(await changeTab(profile), contains(greaterThan(profile.dx + 1)));
    expect(await changeTab(home), contains(lessThan(home.dx - 1)));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('校园按主题导航，常用课表卡片进入原生周视图', (t) async {
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    await t.tap(find.text('校园').last);
    await t.pumpAndSettle();
    expect(find.text('住宿生活'), findsOneWidget);
    expect(find.text('原博客完整组件示例'), findsNothing);
    await t.tap(find.widgetWithText(ChoiceChip, '关于'));
    await t.pumpAndSettle();
    expect(find.text('原博客完整组件示例'), findsOneWidget);
    expect(find.text('住宿生活'), findsNothing);
    await t.tap(find.widgetWithText(ChoiceChip, '学习'));
    await t.pumpAndSettle();
    expect(find.text('培养方案'), findsOneWidget);
    expect(find.text('课程安排'), findsOneWidget);
    await t.tap(find.text('课程安排'));
    await t.pumpAndSettle();
    expect(find.byType(WeekPage), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('选周栏展开和收回都有中间帧，连续点按从当前位置折返', (t) async {
    final store = AcademicStore();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: WeekPage(store))));
    await t.pumpAndSettle();
    double headerY() => t.getTopLeft(find.text('周日')).dy;
    Future<void> toggle() async {
      await t.tap(find.byTooltip('选择教学周'));
      await t.pump();
    }

    final closed = headerY();
    await toggle();
    await t.pump(const Duration(milliseconds: 100));
    final opening = headerY();
    await t.pumpAndSettle();
    final opened = headerY();
    expect(opening, inExclusiveRange(closed, opened));
    await toggle();
    await t.pump(const Duration(milliseconds: 100));
    final closing = headerY();
    expect(closing, inExclusiveRange(closed, opened));
    await toggle();
    await t.pumpAndSettle();
    expect(headerY(), closeTo(opened, .1));
    await toggle();
    await t.pumpAndSettle();
    expect(headerY(), closeTo(closed, .1));
  });

  testWidgets('系统关闭动画后，选周栏点开和收回在第一帧完成', (t) async {
    final store = AcademicStore();
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(body: WeekPage(store)),
        ),
      ),
    );
    await t.pumpAndSettle();
    double headerY() => t.getTopLeft(find.text('周日')).dy;
    final closed = headerY();
    await t.tap(find.byTooltip('选择教学周'));
    await t.pump();
    final opened = headerY();
    expect(opened, greaterThan(closed));
    await t.pumpAndSettle();
    expect(headerY(), closeTo(opened, .1));
    await t.tap(find.byTooltip('选择教学周'));
    await t.pump();
    expect(headerY(), closeTo(closed, .1));
  });
  testWidgets('左右换周只移动课程列，减少动态效果时直接到位', (t) async {
    final store = AcademicStore();
    store.acceptCache({
      ...fixture,
      'schoolYear': '2025-2026',
    }, DateTime.now().millisecondsSinceEpoch + 60000);
    Future<void> mount(bool reduced) async {
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(body: WeekPage(store)),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    final plane = find.byKey(const ValueKey('week-course-plane'));
    double x() => t.widget<Transform>(plane).transform.getTranslation().x;
    await mount(false);
    final axis = t.getCenter(find.text('08:20'));
    final gesture = await t.startGesture(t.getCenter(find.text('数据结构')));
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(const Offset(-90, 0));
    await t.pump();
    expect(x(), lessThan(-80));
    expect(t.getCenter(find.text('08:20')), axis);
    await gesture.up();
    await t.pump();
    final entering = x();
    expect(entering, greaterThan(0));
    await t.pump(const Duration(milliseconds: 70));
    expect(x(), inExclusiveRange(0, entering));
    expect(t.getCenter(find.text('08:20')), axis);
    await t.pumpAndSettle();
    expect(x(), 0);
    await t.drag(find.text('大学物理'), const Offset(150, 0));
    await t.pump();
    expect(x(), lessThan(0));
    await t.pumpAndSettle();

    final cancelled = await t.startGesture(t.getCenter(find.text('数据结构')));
    await cancelled.moveBy(const Offset(-30, 0));
    await t.pump();
    await cancelled.cancel();
    await t.pumpAndSettle();
    expect(x(), 0);
    expect(find.text('第 1 周'), findsOneWidget);

    await mount(true);
    await t.drag(find.text('数据结构'), const Offset(-150, 0));
    await t.pump();
    expect(x(), 0);
    expect(find.text('大学物理'), findsOneWidget);
  });
  testWidgets('同一时段换周更换课程，灰色独占课程没有角标', (t) async {
    final store = AcademicStore();
    store.acceptCache(fixture, DateTime.now().millisecondsSinceEpoch + 100000);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(360, 800);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: WeekPage(store))));
    await t.pumpAndSettle();
    await chooseWeek(t, 1);
    expect(find.textContaining('数据结构'), findsOneWidget);
    expect(find.byKey(const ValueKey('other-week-corner')), findsOneWidget);
    final corner = find.byKey(const ValueKey('other-week-corner'));
    final card = find
        .ancestor(of: corner, matching: find.byType(Material))
        .first;
    expect(t.getBottomRight(corner), t.getBottomRight(card));
    expect(t.widget<Material>(card).clipBehavior, Clip.antiAlias);
    await t.drag(find.textContaining('数据结构'), const Offset(-120, 0));
    await t.pumpAndSettle();
    expect(find.text('第 2 周'), findsOneWidget);
    expect(find.textContaining('大学物理'), findsOneWidget);
    expect(find.textContaining('大学英语'), findsOneWidget);
    expect(find.byKey(const ValueKey('other-week-corner')), findsOneWidget);
    final faded = t.widget<Material>(
      find
          .ancestor(
            of: find.textContaining('大学英语'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(faded.color, const Color(0xffdce1e5));
    await t.tap(find.textContaining('大学物理'));
    await t.pumpAndSettle();
    expect(find.text('数据结构'), findsOneWidget);
    expect(find.text('其他周'), findsOneWidget);
  });
  testWidgets('窄屏大字下的部分重叠课程只画一次，详情能查看完整课程', (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 640);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = AcademicStore();
    const first = '科技英语写作与文献检索';
    const second = '科研方法与实践';
    store.acceptCache({
      'schoolYear': '2025-2026',
      'lessons': [
        {
          'name': first,
          'day': 3,
          'sections': '5-6',
          'weeks': '1',
          'location': '教十一楼 B 区 213',
        },
        {
          'name': second,
          'day': 3,
          'sections': '6-7',
          'weeks': '2',
          'location': '实训楼 302',
        },
      ],
    }, DateTime.now().millisecondsSinceEpoch + 60000);
    await t.pumpWidget(
      MaterialApp(
        theme: const WikiApp().theme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(body: WeekPage(store)),
      ),
    );
    await t.pumpAndSettle();
    final cardName = find.text(first);
    expect(cardName, findsOneWidget);
    await t.ensureVisible(cardName);
    await t.pumpAndSettle();
    await t.tap(cardName);
    await t.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text(first)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text(second)),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('同周同期排课显示并课数，可打开两门详情', (t) async {
    final store = AcademicStore();
    store.acceptCache({
      'schoolYear': '2025-2026',
      'lessons': [
        for (final name in ['数据结构实验', '课程设计'])
          {
            'name': name,
            'day': 2,
            'sections': '3-4',
            'weeks': '1',
            'location': '实验楼 202',
          },
      ],
    }, DateTime.now().millisecondsSinceEpoch + 60000);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: WeekPage(store))));
    await t.pumpAndSettle();
    expect(find.text('+1'), findsOneWidget);
    expect(find.byKey(const ValueKey('other-week-corner')), findsNothing);
    await t.tap(find.text('数据结构实验'));
    await t.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('课程设计')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('本周')),
      findsNWidgets(2),
    );
  });
  testWidgets('切栏后保留选择的教学周，过期登录仍有入口', (t) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          platform,
          (call) async => call.method == 'restore'
              ? {
                  'token': '',
                  'expires': 0,
                  'snapshot': jsonEncode({
                    'expiresAt': now + 604800000,
                    'fetchedAt': now,
                    'result': fixture,
                  }),
                }
              : null,
        );
    await t.pumpWidget(const WikiApp());
    await t.pumpAndSettle();
    expect(find.text('学校统一认证'), findsNothing);
    await t.tap(find.text('个人').last);
    await t.pumpAndSettle();
    expect(find.text('学校统一认证'), findsOneWidget);
    await t.tap(find.text('课表'));
    await t.pumpAndSettle();
    expect(find.textContaining('正在显示本机课表'), findsNothing);
    await chooseWeek(t, 3);
    expect(find.text('数据结构'), findsOneWidget);
    await t.pump();
    await t.tap(find.text('个人').last);
    await t.pump(const Duration(milliseconds: 80));
    await t.tap(find.text('首页').last);
    await t.pumpAndSettle();
    await t.tap(find.text('课表'));
    await t.pumpAndSettle();
    expect(find.text('第 3 周'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('本地校园目录、导航、作息与绩点，旧床铺工具地址退出', (t) async {
    final store = AcademicStore();
    Future<void> page(String p) async {
      await t.pumpWidget(
        MaterialApp(
          home: NativePage(store, p, '测试', key: ValueKey(p), selectTab: (_) {}),
        ),
      );
      await t.pumpAndSettle();
    }

    await page('/tools/contests');
    expect(find.textContaining('中国国际大学生创新大赛'), findsOneWidget);
    await page('/navigation');
    expect(find.text('本科教务系统'), findsOneWidget);
    await page('/tools/beds');
    expect(find.text('此条目暂无内容'), findsOneWidget);
    await page('/tools/times');
    expect(find.text('08:20 — 09:05'), findsOneWidget);
    await page('/tools/gpa');
    await t.enterText(find.byType(TextFormField).at(0), '3');
    await t.enterText(find.byType(TextFormField).at(1), '0');
    await t.pump();
    expect(find.textContaining('0.00'), findsOneWidget);
    await page('/study/status');
    expect(find.byType(ExpansionTile), findsWidgets);
    await page('/tools/dorm');
    expect(find.text('查询寝室'), findsOneWidget);
  });
  testWidgets('切换校区可见中间动画帧，减少动态效果时直接显示新作息', (t) async {
    final store = AcademicStore();
    Future<void> show(bool reduced) async {
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: NativePage(store, '/tools/times', '上课时间', selectTab: (_) {}),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await show(false);
    t
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .onChanged!('qingshan');
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    final reveal = t.renderObject<ArchiveRevealRender>(
      find.ancestor(
        of: find.text('08:00 — 08:45'),
        matching: find.byType(ArchiveReveal),
      ),
    );
    expect(reveal.progress, inExclusiveRange(0, 1));
    await t.pumpAndSettle();
    expect(reveal.progress, 1);
    await show(true);
    expect(find.byType(ArchiveReveal), findsNothing);
    t
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .onChanged!('huangjiahu');
    await t.pump();
    expect(find.text('08:20 — 09:05'), findsOneWidget);
    expect(find.byType(ArchiveReveal), findsNothing);
  });
  testWidgets('应用内打开学校认证，继续轮询同一个会话并同步课表', (tester) async {
    final school = ConfirmedSchool();
    MethodCall? wechat;
    MethodCall? browser;
    messenger.setMockMethodCallHandler(platform, (call) async {
      if (call.method == 'wechat') wechat = call;
      if (call.method == 'external') {
        browser = call;
        return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        return 0;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AcademicQuery(school, 'login')),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('学校统一认证登录二维码'), findsOneWidget);
    await tester.tap(find.text('用微信扫码'));
    final args = wechat?.arguments as Map?;
    expect(args?['mode'], 'confirm');
    expect(args?['qr'], startsWith('data:image/png;base64,'));
    await tester.tap(find.text('打开学校认证'));
    await tester.pump();
    final portal = tester.widget<AndroidView>(find.byType(AndroidView));
    expect(portal.viewType, 'wiki/school-portal');
    expect(
      portal.creationParams,
      'https://auth.wust.edu.cn/authserver/qrCode/qrCodeLogin.do?uuid=demo',
    );
    await tester.tap(find.byTooltip('用系统浏览器打开'));
    await tester.pump();
    expect(browser?.arguments, portal.creationParams);
    expect(find.byType(AndroidView), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 4));
    expect(school.calls, ['start']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(school.calls, ['start', 'poll', 'query', 'query']);
    expect(school.resources, ['schedule', 'grades']);
    expect(school.schedule?['lessons'], isEmpty);
    expect(school.gradeCourses?.single['name'], '已同步成绩');
    expect(school.loggedIn, isTrue);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: WeekPage(school))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('同步课表'));
    await tester.pumpAndSettle();
    expect(school.resources, ['schedule', 'grades', 'schedule']);
    expect(school.schedule?['lessons'], isEmpty);
  });
  test('重修同学期优先，无法判断的记录交由用户选择', () {
    expect(
      latestAttempt([
        {'term': '2024-2025-1', 'attempt': '正常'},
        {'term': '2024-2025-1', 'attempt': '重修'},
      ]),
      1,
    );
    expect(
      latestAttempt([
        {'term': '未注明', 'attempt': '重修'},
        {'term': '2024-2025-1', 'attempt': '正常'},
      ]),
      null,
    );
  });
  testWidgets('恢复的教务令牌首次查询前核对，学校暂不可用时可重试', (t) async {
    messenger.setMockMethodCallHandler(
      platform,
      (call) async => call.method == 'restore'
          ? {'token': 'saved-school-session', 'expires': 1}
          : null,
    );
    final school = RestoredSchool();
    await school.init();
    await expectLater(
      school.api('query', school.token, resource: 'schedule'),
      throwsA(isA<AcademicApiException>()),
    );
    expect(school.loggedIn, isTrue);
    expect(school.calls, ['inspect']);
    school.unavailable = false;
    await school.api('query', school.token, resource: 'schedule');
    await school.api('query', school.token, resource: 'grades');
    await school.logout();
    expect(school.calls, ['inspect', 'inspect', 'query', 'query', 'logout']);
    expect(school.loggedIn, isFalse);
  });
  test('学期与星期读取兼容 Wiki 数据', () {
    expect(teachingWeek(fixture, DateTime.utc(2026, 11, 20)), 12);
    expect(teachingWeek({'semester': 2}, DateTime.utc(2026, 11, 20)), null);
    expect(Lesson.parseWeeks('1–6周（双）'), [2, 4, 6]);
    expect(
      Lesson(jsonDecode('{"day":1,"start":3,"length":2,"weeks":"待定"}')).placed,
      false,
    );
  });
}
