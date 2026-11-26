import 'home_tools.dart';
import 'app_update.dart';
import 'daily_timeline.dart';
import 'exam_schedule.dart';
import 'home_agenda.dart';
import 'school_operation_status.dart';
import 'dart:math' as math;
import 'package:flutter/physics.dart';
import 'wiki_motion.dart';
import 'wiki_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'blog_surface.dart';
import 'campus_directory.dart';
import 'dart:async';
import 'academic.dart';
import 'week.dart';
import 'native_pages.dart';
import 'package:flutter/material.dart';
import 'archive_motion.dart';
import 'package:flutter/foundation.dart';
import 'foundation/debug_probe.dart';
import 'foundation/system_probe.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (kDebugMode && route.startsWith('/foundation-auth-probe/')) {
    runApp(
      route.endsWith('/files')
          ? FoundationSystemProbe()
          : FoundationAuthProbe(route.split('/').last),
    );
  } else {
    runApp(const WikiApp());
  }
}

class WikiApp extends StatelessWidget {
  const WikiApp({super.key});
  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // Wiki blue/zinc shell; blog content has its own scoped CSS palette.
    final accent = dark ? const Color(0xff51a2ff) : const Color(0xff2b7fff);
    final ink = dark ? const Color(0xffe4e4e7) : const Color(0xff27272a);
    final paper = dark ? const Color(0xff232329) : Colors.white;
    final edge = dark ? const Color(0xff313137) : const Color(0xffe4e4e7);
    final strongBlue = dark ? accent : const Color(0xff245ac0);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          secondary: dark ? const Color(0xff76dad8) : const Color(0xff167b80),
          surface: paper,
          onSurface: ink,
          outlineVariant: edge,
          onSurfaceVariant: dark
              ? const Color(0xffb5b5be)
              : const Color(0xff52525b),
          onPrimaryContainer: strongBlue,
          primaryContainer: Color.alphaBlend(
            accent.withValues(alpha: .12),
            paper,
          ),
          secondaryContainer: Color.alphaBlend(
            accent.withValues(alpha: .14),
            paper,
          ),
          onSecondaryContainer: strongBlue,
          onPrimary: const Color(0xff07182d),
        );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: scheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? const Color(0xff1b1b1f)
          : const Color(0xfffafafa),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          backgroundColor: strongBlue,
          foregroundColor: dark ? const Color(0xff111827) : Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: strongBlue),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          foregroundColor: strongBlue,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: edge),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: accent),
      appBarTheme: AppBarTheme(
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 23,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WUST Wiki',
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('zh', 'CN')],
    debugShowCheckedModeBanner: false,
    theme: theme(Brightness.light),
    darkTheme: theme(Brightness.dark),
    home: const Dashboard(),
  );
}

const schedule = (
  label: '课程安排',
  path: '/study/curriculum',
  icon: Icons.calendar_month_outlined,
);
const examScheduleEntry = (
  label: '考试安排',
  path: '/study/exams',
  icon: Icons.assignment_outlined,
);

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final motion = AnimationController(
    vsync: this,
    duration: WikiMotion.enter,
    value: 1,
  );
  late final dock = AnimationController.unbounded(vsync: this);
  static const tabs = WikiTab.values;
  final visitedTabs = {WikiTab.home};
  WikiTab tab = WikiTab.home, previous = WikiTab.home;
  bool draggingDock = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WikiMotion.reduced(context)) {
      motion.value = 1;
      draggingDock = false;
      dock.value = tab.index.toDouble();
    }
  }

  final store = AcademicStore();
  final updater = WikiUpdater();
  bool _foreground = true;
  Timer? timer;
  final scroll = List.generate(tabs.length, (_) => ScrollController());
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(refresh);
    store.init();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => tick());
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(checkAppUpdate()),
    );
  }

  Future<void> checkAppUpdate() async {
    if (!mounted ||
        !await updater.checkAutomatically() ||
        !mounted ||
        !_foreground ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final release = updater.release;
    if (release == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('发现新版本 ${release.name}'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => AppUpdateTile.open(context, updater),
        ),
      ),
    );
  }

  void refresh() {
    if (!mounted) return;
    if (_foreground) unawaited(store.ensureExamSchedule());
    setState(() {});
  }

  void tick() {
    store.expire();
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(refresh);
    timer?.cancel();
    updater.dispose();
    motion.dispose();
    dock.dispose();
    for (final c in scroll) {
      c.dispose();
    }
    super.dispose();
  }

  bool loggingIn = false;
  WikiPageMark mark(Entry entry) => WikiPageMark(
    entry.path,
    entry.icon,
    hue: switch (entry.path) {
      '/tools/dorm' || '/life/nearby' => 177,
      '/tools/contests' || '/tools/countdown' => 32,
      '/tools/gpa' || '/study/status' || '/study/grades' => 266,
      _ => 220,
    },
  );
  Future<void> open(Entry entry, {WikiPageMark? source}) => openNative(
    context,
    store,
    entry.path,
    entry.label,
    selectTab: choose,
    mark: source ?? mark(entry),
  );
  void login() => setState(() => loggingIn = true);
  void moveDock(double pixels, double cell) {
    dock.value = (pixels / cell - .5).clamp(0.0, (tabs.length - 1).toDouble());
  }

  void choose(WikiTab next, {double? velocity}) {
    final reduced = WikiMotion.reduced(context);
    draggingDock = false;
    final position = next.index.toDouble();
    if (reduced || (dock.value - position).abs() < .001) {
      dock.value = position;
    } else {
      dock.animateWith(
        SpringSimulation(
          WikiMotion.spring,
          dock.value,
          position,
          (velocity ?? dock.velocity).clamp(-9.0, 9.0),
        ),
      );
    }
    if (next == tab) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      previous = tab;
      tab = next;
      visitedTabs.add(next);
    });
    if (reduced) {
      motion.value = 1;
    } else {
      motion.forward(from: 0);
    }
  }

  ColorScheme get colors => Theme.of(context).colorScheme;
  Widget panel(Widget child, {Color? fill}) => Material(
    color: fill ?? colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: colors.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  Widget scheduleCard() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final week = teachingWeek(store.schedule ?? {}, chinaDay());
    final todaysLessons =
        store.lessons
            .where(
              (l) =>
                  l.placed && l.day == now.weekday && l.weeks!.contains(week),
            )
            .toList()
          ..sort((a, b) => a.sections!.first.compareTo(b.sections!.first));
    final slots = <({Lesson lesson, int start, int end})>[];
    for (final lesson in todaysLessons) {
      final periods = lesson.sections!;
      var start = periods.first, end = start;
      for (final section in periods.skip(1)) {
        if (section != end + 1) {
          slots.add((lesson: lesson, start: start, end: end));
          start = section;
        }
        end = section;
      }
      slots.add((lesson: lesson, start: start, end: end));
    }
    slots.sort((a, b) => a.start.compareTo(b.start));
    final courseNames =
        store.lessons.map((lesson) => lesson.name).toSet().toList()..sort();
    final courseAccents = {
      for (final (i, name) in courseNames.indexed)
        name: blogTint(
          context,
          const [220.0, 178.0, 266.0, 32.0, 154.0, 342.0][i % 6],
        ),
    };
    final today = {
      'status': !store.initialized
          ? 'loading'
          : store.schedule == null
          ? 'missing'
          : week == null
          ? 'unknown'
          : 'ready',
      'week': week,
      'uncertain': store.lessons.any(
        (l) => !l.placed && (l.day == 0 || l.day == now.weekday),
      ),
    };
    final status = today['status'];
    final message = switch (status) {
      'missing' => '课表尚未同步',
      'loading' => '正在读取课表',
      'unknown' => '当前教学周待确认',
      _ => today['uncertain'] == true ? '部分排课时间待确认' : '今日无课',
    };
    return panel(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArchivePart(
              start: 0,
              end: .68,
              travel: const Offset(-9, 0),
              child: Row(
                children: [
                  Icon(schedule.icon, color: colors.primary, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${now.month}月${now.day}日  星期${'一二三四五六日'[now.weekday - 1]}',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (today['week'] != null) Text('第 ${today['week']} 周'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ArchivePart(
              start: .15,
              end: .87,
              travel: const Offset(-10, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '今日课表',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => choose(WikiTab.schedule),
                    child: const Text('完整课表'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            if (slots.isNotEmpty)
              FutureBuilder<Json>(
                future: nativeData,
                builder: (_, snapshot) {
                  final times =
                      snapshot.data?['times']?[store.campus] as List? ?? [];
                  final nowMinute = now.hour * 60 + now.minute;
                  final periods = [
                    for (final slot in slots)
                      (
                        lesson: slot.lesson,
                        sections: slot.start == slot.end
                            ? '第 ${slot.start} 节'
                            : '第 ${slot.start}–${slot.end} 节',
                        start: slot.start <= times.length
                            ? times[slot.start - 1][0] as String?
                            : null,
                        end: slot.end <= times.length
                            ? times[slot.end - 1][1] as String?
                            : null,
                        accent:
                            courseAccents[slot.lesson.name] ?? colors.primary,
                      ),
                  ];
                  final segments = <DailySegment>[];
                  int? nextStart;
                  for (final period in periods) {
                    final start = clockMinutes(period.start),
                        end = clockMinutes(period.end);
                    if (start != null && end != null && start < end) {
                      if (start > nowMinute &&
                          (nextStart == null || start < nextStart)) {
                        nextStart = start;
                      }
                      segments.add((
                        start: start,
                        end: end,
                        color: period.accent,
                      ));
                    }
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DailyTimeline(segments: segments, now: nowMinute),
                      for (final (i, period) in periods.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        ArchivePart.staggered(
                          i + 2,
                          child: TodayPeriodRow(
                            lesson: period.lesson,
                            sections: period.sections,
                            start: period.start,
                            end: period.end,
                            now: nowMinute,
                            accent: period.accent,
                            next:
                                clockMinutes(period.start) == nextStart &&
                                nextStart != null,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            if (slots.isEmpty || today['uncertain'] == true)
              ArchivePart(
                start: .32,
                end: 1,
                axis: ArchiveRevealAxis.vertical,
                travel: const Offset(0, 5),
                child: Text(
                  message,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
      fill: Color.alphaBlend(
        colors.primary.withValues(alpha: .055),
        colors.surface,
      ),
    );
  }

  Widget examsCard() {
    final now = DateTime.now();
    final records = store.examSchedule;
    final next = upcomingExams(
      records ?? const [],
      now,
      within: const Duration(days: 14),
    );
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: BlogPanel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                mark(examScheduleEntry),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '近两周考试',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => open(examScheduleEntry),
                  child: const Text('考试安排'),
                ),
                IconButton(
                  tooltip: '考试倒计时',
                  onPressed: () => openNative(
                    context,
                    store,
                    '/tools/countdown',
                    '考试倒计时',
                    selectTab: choose,
                  ),
                  icon: const Icon(Icons.timer_outlined),
                ),
              ],
            ),
            if (records != null && next.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '近两周暂无考试',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            for (final (index, exam) in next.indexed) ...[
              if (index > 0) const Divider(height: 1),
              ArchivePart.staggered(
                index,
                child: HomeExamRow(exam: exam, now: now),
              ),
            ],
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        quiet: true,
      ),
    );
  }

  Widget body(WikiTab page) {
    if (page == WikiTab.schedule)
      return SafeArea(bottom: false, child: WeekPage(store));
    if (page == WikiTab.profile && loggingIn)
      return AcademicQuery(
        store,
        'login',
        onClose: () => setState(() => loggingIn = false),
      );
    final children = <Widget>[];
    if (page == WikiTab.home)
      children.addAll([
        ContentReveal.grouped(
          scheduleCard(),
          revision: (store.initialized, store.schedule),
        ),
        ContentReveal.sequence(examsCard(), revision: store.examSchedule),
        HomeTools(
          store: store,
          open: (entry, source) => open(entry, source: source),
          mark: mark,
        ),
      ]);
    if (page == WikiTab.profile)
      children.addAll([
        ContentReveal.grouped(
          BlogPanel(
            ListTile(
              leading: BlogIcon(
                store.loggedIn
                    ? Icons.verified_user_outlined
                    : Icons.person_outline,
                hue: store.loggedIn ? 178 : 220,
              ),
              title: ArchivePart(
                travel: const Offset(-8, 0),
                child: Text(
                  store.token == 'local'
                      ? store.unifiedVerified
                            ? (store.localVerified
                                  ? '统一认证已登录 · 教务已连接'
                                  : '统一认证已登录')
                            : (store.localVerified
                                  ? '教务已连接 · 统一认证待验证'
                                  : '学校账号已保存')
                      : store.loggedIn
                      ? '学校网页登录已连接'
                      : '未登录',
                ),
              ),
            ),
            hue: store.loggedIn ? 178 : 220,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          ),
          revision: store.loggedIn,
        ),
        if (store.localAvailable && store.loggedIn)
          TextButton.icon(
            onPressed: login,
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('登录设置'),
          ),
        if (store.loggedIn)
          BlogPanel(
            ListTile(
              leading: mark(_studentEntry),
              title: const Text('学籍信息'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => open(_studentEntry),
            ),
            padding: EdgeInsets.zero,
            quiet: true,
          ),
        const SizedBox(height: 16),
        ArchivePart.staggered(
          3,
          child: !store.loggedIn
              ? FilledButton.icon(
                  onPressed: login,
                  icon: const Icon(Icons.login),
                  label: const Text('学校统一认证'),
                )
              : OutlinedButton(
                  onPressed: () async {
                    try {
                      await store.logout();
                    } catch (_) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('本机已退出，远端会话撤销未确认。')),
                        );
                    }
                  },
                  child: const Text('退出学校账号'),
                ),
        ),
        const SizedBox(height: 16),
        ContentReveal.grouped(AppUpdateTile(updater)),
      ]);
    return Column(
      children: [
        AppBar(
          title: ArchivePart(
            start: .20,
            end: .94,
            travel: const Offset(-10, 0),
            child: Text(page.title),
          ),
          actions: [
            if (page == WikiTab.campus)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: () => open((
                    label: '武科大导航',
                    path: '/navigation',
                    icon: Icons.explore_outlined,
                  )),
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('武科大导航'),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SchoolOperationStatus(store.foundation),
        ),
        Expanded(
          child: page == WikiTab.campus
              ? CampusDirectory(controller: scroll[page.index], onOpen: open)
              : ListView(
                  controller: scroll[page.index],
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                  children: children,
                ),
        ),
      ],
    );
  }

  Widget tabPlane(WikiTab i) {
    if (!visitedTabs.contains(i)) return SizedBox.shrink(key: ValueKey(i));
    final active = i == tab;
    final page = ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ArchiveMotionScope(
        animation: motion,
        enabled: active && !WikiMotion.reduced(context),
        child: body(i),
      ),
    );
    return AnimatedBuilder(
      key: ValueKey(i),
      animation: motion,
      child: RepaintBoundary(child: page),
      builder: (_, child) {
        final leaving = i == previous && !motion.isCompleted;
        return Offstage(
          offstage: !active && !leaving,
          child: ExcludeFocus(
            excluding: !active,
            child: TickerMode(
              enabled: active,
              child: HeroMode(
                enabled: active,
                child: ExcludeSemantics(
                  excluding: !active,
                  child: IgnorePointer(
                    ignoring: !active,
                    child: ArchivePlaneTransition(
                      animation: active || leaving
                          ? motion
                          : const AlwaysStoppedAnimation(1),
                      kind: active
                          ? ArchivePlaneKind.incoming
                          : ArchivePlaneKind.outgoing,
                      direction: tab.index > previous.index ? 1 : -1,
                      child: child!,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: tab == WikiTab.home,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (tab == WikiTab.profile && loggingIn) {
        setState(() => loggingIn = false);
      } else {
        choose(WikiTab.home);
      }
    },
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (final i in tabs)
            if (i != tab) tabPlane(i),
          tabPlane(tab),
        ],
      ),
      bottomNavigationBar: Material(
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (_, bounds) {
              final cell = bounds.maxWidth / tabs.length;
              final reduced = WikiMotion.reduced(context);
              return GestureDetector(
                onHorizontalDragStart: reduced
                    ? null
                    : (event) {
                        draggingDock = true;
                        moveDock(event.localPosition.dx, cell);
                      },
                onHorizontalDragUpdate: reduced
                    ? null
                    : (event) {
                        moveDock(event.localPosition.dx, cell);
                      },
                onHorizontalDragEnd: reduced
                    ? null
                    : (event) {
                        choose(
                          tabs[dock.value.round().clamp(0, tabs.length - 1)],
                          velocity: (event.primaryVelocity ?? 0) / cell,
                        );
                      },
                onHorizontalDragCancel: reduced
                    ? null
                    : () => choose(tab, velocity: 0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: dock,
                          builder: (_, _) {
                            final position = dock.value;
                            final between = (position - position.round()).abs();
                            final width = math.min(
                              cell,
                              50.0 + (draggingDock ? between * 20 : 0),
                            );
                            final left = (cell * (position + .5) - width / 2)
                                .clamp(0.0, bounds.maxWidth - width);
                            return Stack(
                              children: [
                                Positioned(
                                  key: const ValueKey('wiki-dock-indicator'),
                                  top: 8,
                                  left: left,
                                  width: width,
                                  height: 28,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: colors.primary.withValues(
                                        alpha: .16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final i in tabs)
                          Expanded(
                            child: Semantics(
                              selected: i == tab,
                              button: true,
                              child: InkWell(
                                onTap: () => choose(i),
                                splashFactory: NoSplash.splashFactory,
                                highlightColor: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        child: Icon(
                                          i.icon,
                                          color: i == tab
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            i.title,
                                            maxLines: 1,
                                            style: TextStyle(
                                              color: i == tab
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

const _studentEntry = (
  label: '学籍信息',
  path: '/study/student',
  icon: Icons.badge_outlined,
);
