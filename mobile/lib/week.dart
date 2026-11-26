import 'school_operation_status.dart';
import 'foundation/progress.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'academic.dart';
import 'blog_surface.dart';
import 'archive_motion.dart';
import 'wiki_motion.dart';
import 'wiki_page.dart';
import 'local_academic.dart';

const _days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
typedef _Tone = ({Color fill, Color text});
const _lightCourseColors = [
  (0xff2478af, 0xffffffff),
  (0xff83cfd6, 0xff13383e),
  (0xfff1a1aa, 0xff482333),
  (0xffbaa3de, 0xff312249),
  (0xff87bff0, 0xff173750),
  (0xff99d2b9, 0xff183c33),
  (0xfff0c089, 0xff462d21),
  (0xff9daee4, 0xff252e50),
];

// Catppuccin Mocha accents softened against the Wiki dark surface.
const _mochaAccents = [
  Color(0xff89b4fa), // Blue
  Color(0xff94e2d5), // Teal
  Color(0xffeba0ac), // Maroon
  Color(0xffcba6f7), // Mauve
  Color(0xff89dceb), // Sky
  Color(0xffa6e3a1), // Green
  Color(0xfffab387), // Peach
  Color(0xfff5c2e7), // Pink
  Color(0xfff9e2af), // Yellow
  Color(0xffb4befe), // Lavender
];

_Tone _tone(int index, bool dark) {
  final hue = (index * 137.508) % 360;
  if (dark) {
    final accent = index < _mochaAccents.length
        ? _mochaAccents[index]
        : HSLColor.fromAHSL(1, hue, .55, .80).toColor();
    return (
      fill: Color.lerp(const Color(0xff232329), accent, .28)!,
      text: Color.lerp(accent, Colors.white, .59)!,
    );
  }
  if (index < _lightCourseColors.length) {
    final (fill, text) = _lightCourseColors[index];
    return (fill: Color(fill), text: Color(text));
  }
  return (
    fill: HSLColor.fromAHSL(1, hue, .60, .77).toColor(),
    text: const Color(0xff202638),
  );
}

class WeekPage extends StatefulWidget {
  final AcademicStore store;
  const WeekPage(this.store, {super.key});
  @override
  State<WeekPage> createState() => _WeekState();
}

class _WeekState extends State<WeekPage> with TickerProviderStateMixin {
  late final weekMotion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 175),
    value: 1,
  );
  late final strip = AnimationController(
    vsync: this,
    duration: WikiMotion.enter,
    reverseDuration: WikiMotion.exit,
  );
  late final stripEase = strip.drive(CurveTween(curve: Curves.easeOutCubic));
  late final touch = _CourseTouch(this);
  final dragOffset = ValueNotifier<double>(0);
  double slideFrom = 0;
  int? outgoingWeek;
  bool fadeWeek = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      weekMotion.value = 1;
      dragOffset.value = 0;
      strip.value = picking ? 1 : 0;
      touch.clear();
    }
  }

  @override
  void dispose() {
    weekMotion.dispose();
    dragOffset.dispose();
    strip.dispose();
    touch.dispose();
    super.dispose();
  }

  void moveStrip(bool open) {
    if (MediaQuery.disableAnimationsOf(context)) {
      strip.value = open ? 1 : 0;
    } else if (open) {
      strip.forward();
    } else {
      strip.reverse();
    }
  }

  void toggleStrip() {
    setState(() => picking = !picking);
    moveStrip(picking);
  }

  int? chosen;
  double drag = 0;
  bool picking = false;
  FoundationProgress? syncProgress;
  bool get syncing => syncProgress != null;

  Future<void> sync() async {
    final store = widget.store;
    if (!store.loggedIn || syncing) return;
    setState(
      () => syncProgress = FoundationProgress(
        message: '正在查询课表',
        startedAt: DateTime.now(),
        activeCount: 1,
        resource: 'schedule',
      ),
    );
    try {
      await store.academicResult('schedule');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is FormatException ? e.message : '同步失败，请检查网络后重试。'),
          ),
        );
    } finally {
      if (mounted) setState(() => syncProgress = null);
    }
  }

  Future<void> option(String value) async {
    final store = widget.store;
    if (value == 'export') {
      await Navigator.of(context).push(
        WikiRoute(
          FoundationResourcePage(store, 'raw-schedule', '导出原始课表'),
          MediaQuery.disableAnimationsOf(context),
        ),
      );
    } else if (value == 'clear') {
      final clear = await showWikiDialog<bool>(
        context,
        (ctx) => AlertDialog(
          title: const Text('清除本机课表？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清除'),
            ),
          ],
        ),
      );
      if (clear == true && mounted) await store.clearSchedule();
    } else {
      await store.saveCampus(value);
    }
  }

  void select(int? selection, {double? swipe}) {
    final current = teachingWeek(widget.store.schedule ?? {}, chinaDay()) ?? 1;
    final previous = chosen ?? current, next = selection ?? current;
    setState(() {
      chosen = selection;
      picking = false;
    });
    moveStrip(false);
    if (previous != next) {
      touch.clear();
      if (MediaQuery.disableAnimationsOf(context)) {
        weekMotion.value = 1;
      } else {
        final side = next > previous ? 1.0 : -1.0;
        slideFrom = swipe == null ? side * .10 : side + swipe;
        outgoingWeek = swipe == null ? null : previous;
        fadeWeek = true;
        weekMotion.forward(from: 0);
      }
    }
  }

  void returnToWeek() {
    if (dragOffset.value == 0) return;
    slideFrom = dragOffset.value;
    outgoingWeek = null;
    fadeWeek = false;
    weekMotion.forward(from: 0);
    dragOffset.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store, term = store.schedule ?? {};
    final today = chinaDay();
    final current = teachingWeek(term, today);
    final week = chosen ?? current ?? 1;
    final lessons = store.lessons.where((l) => l.placed).toList();
    final names = lessons.map((l) => l.name).toSet().toList()..sort();
    final courseColors = {for (final (i, name) in names.indexed) name: i};
    final lastWeek = lessons.fold<int>(
      math.max(20, week),
      (m, l) => math.max(m, l.weeks!.last),
    );
    final sections = lessons.fold<int>(
      10,
      (m, l) => math.max(m, l.sections!.last),
    );
    final colors = Theme.of(context).colorScheme;
    final start = knownTerm(term)
        ? autumnStart.add(Duration(days: (week - 1) * 7))
        : null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final axis = MediaQuery.sizeOf(context).width < 350 ? 40.0 : 45.0;
    final headerStyle = TextStyle(
      color: colors.onSurfaceVariant,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
    final year = term['schoolYear']?.toString() ?? '';
    final semester = term['semester']?.toString() ?? '';
    final campus = store.campus == 'qingshan' ? '青山' : '黄家湖';
    final headerSubtitle = [
      if (year.isNotEmpty) year,
      if (semester.isNotEmpty) '第${semester}学期',
      campus + '作息',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 6),
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: '选择教学周',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: toggleStrip,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: ArchivePart(
                                  travel: const Offset(-9, 0),
                                  child: Text(
                                    '第 $week 周',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                              RotationTransition(
                                turns: stripEase.drive(
                                  Tween(begin: 0.0, end: .5),
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: colors.primary,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ArchivePart(
                      start: .24,
                      end: .94,
                      axis: ArchiveRevealAxis.vertical,
                      travel: const Offset(0, 5),
                      child: Text(
                        headerSubtitle,
                        style: headerStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (current != null && current != week)
                IconButton(
                  tooltip: '回到本周',
                  onPressed: () => select(null),
                  icon: const Icon(Icons.today_outlined),
                ),
              IconButton(
                tooltip: '同步课表',
                onPressed: syncing
                    ? null
                    : () {
                        if (store.loggedIn) {
                          sync();
                        } else {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('请先在「个人」登录')),
                          );
                        }
                      },
                icon: const Icon(Icons.sync_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: '课表设置',
                onSelected: option,
                itemBuilder: (_) => [
                  for (final c in {
                    'huangjiahu': '黄家湖',
                    'qingshan': '青山',
                  }.entries)
                    CheckedPopupMenuItem(
                      value: c.key,
                      checked: store.campus == c.key,
                      child: Text('${c.value}校区作息'),
                    ),
                  if (store.schedule != null)
                    const PopupMenuItem(value: 'clear', child: Text('清除本机课表')),
                  if (store.loggedIn)
                    const PopupMenuItem(value: 'export', child: Text('导出原始课表')),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SchoolOperationStatus(
            store.foundation,
            fallback: syncProgress,
          ),
        ),
        AnimatedBuilder(
          animation: strip,
          child: _WeekPicker(
            selected: week,
            current: current,
            total: lastWeek,
            lessons: lessons,
            select: select,
          ),
          builder: (context, child) => strip.isDismissed
              ? const SizedBox.shrink()
              : ExcludeSemantics(
                  excluding: !picking,
                  child: IgnorePointer(
                    ignoring: !picking,
                    child: SizeTransition(
                      axisAlignment: -1,
                      sizeFactor: stripEase,
                      child: child,
                    ),
                  ),
                ),
        ),
        if (lessons.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 3),
            child: ArchivePart.staggered(
              2,
              child: BlogPanel(
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        store.schedule == null
                            ? store.loggedIn
                                  ? '尚未同步课表'
                                  : '登录后可同步课表'
                            : store.lessons.isEmpty
                            ? '本学期暂无排课'
                            : '排课时间待确认',
                        style: TextStyle(color: colors.onSurface, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
            ),
          ),
        ArchivePart.staggered(
          1,
          child: _DateHeader(axis: axis, start: start, today: today),
        ),
        Expanded(
          child: FutureBuilder<Json>(
            future: nativeData,
            builder: (context, snapshot) {
              final times =
                  snapshot.data?['times']?[store.campus] as List? ?? [];
              final extra = store.lessons.where((l) => !l.placed);
              final notes = (term['notes'] as List?) ?? [];
              return LayoutBuilder(
                builder: (context, bounds) {
                  final gridWidth = math.max(1.0, bounds.maxWidth - axis);
                  final reduced = MediaQuery.disableAnimationsOf(context);
                  final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
                  final unit = math.max(
                    (bounds.maxHeight / 10).clamp(54.0, 83.0),
                    55.0 * scale.clamp(1.0, 1.65),
                  );
                  Widget columns(int page) => Row(
                    children: [
                      for (int day = 1; day <= 7; day++)
                        Expanded(
                          child: ArchivePart.staggered(
                            day - 1,
                            child: _DayColumn(
                              touch: touch,
                              colors: courseColors,
                              week: page,
                              day: day,
                              sections: sections,
                              unit: unit,
                              times: times,
                              lessons: lessons
                                  .where((l) => l.day == day)
                                  .toList(),
                              campus: campus,
                            ),
                          ),
                        ),
                    ],
                  );
                  final adjacent = {
                    if (week > 1) week - 1: columns(week - 1),
                    if (week < lastWeek) week + 1: columns(week + 1),
                    if (outgoingWeek case final int previous)
                      previous: columns(previous),
                  };
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {
                      drag = 0;
                      dragOffset.value = 0;
                      weekMotion.value = 1;
                    },
                    onHorizontalDragUpdate: (e) {
                      drag += e.delta.dx;
                      if (!reduced) {
                        final atEdge = drag > 0 ? week == 1 : week == lastWeek;
                        dragOffset.value =
                            (drag / gridWidth * (atEdge ? .2 : 1)).clamp(
                              atEdge ? -.12 : -1.0,
                              atEdge ? .12 : 1.0,
                            );
                      }
                    },
                    onHorizontalDragCancel: returnToWeek,
                    onHorizontalDragEnd: (e) {
                      final velocity = e.primaryVelocity ?? 0;
                      final distance = drag.abs() > 40
                          ? drag
                          : velocity.abs() > 430
                          ? velocity
                          : 0;
                      final next = (week + (distance < 0 ? 1 : -1)).clamp(
                        1,
                        lastWeek,
                      );
                      if (distance == 0 || next == week) {
                        returnToWeek();
                      } else {
                        select(next, swipe: dragOffset.value);
                        dragOffset.value = 0;
                      }
                    },
                    child: ListView(
                      children: [
                        SizedBox(
                          height: unit * sections,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Row(
                                  children: [
                                    SizedBox(width: axis),
                                    for (int day = 1; day <= 7; day++)
                                      Expanded(
                                        child: ColoredBox(
                                          color:
                                              start != null &&
                                                  start.add(
                                                        Duration(days: day - 1),
                                                      ) ==
                                                      today
                                              ? colors.primary.withValues(
                                                  alpha: dark ? .11 : .065,
                                                )
                                              : Colors.transparent,
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              for (int s = 0; s < sections; s += 2)
                                Positioned(
                                  top: s * unit,
                                  left: 0,
                                  right: 0,
                                  child: Divider(
                                    height: 1,
                                    thickness: .7,
                                    color: colors.outlineVariant.withValues(
                                      alpha: .65,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: axis,
                                      child: Column(
                                        children: [
                                          for (int i = 0; i < sections; i += 2)
                                            SizedBox(
                                              height:
                                                  unit *
                                                  math.min(2, sections - i),
                                              child: _TimeRange(
                                                first: i,
                                                end: math.min(
                                                  i + 1,
                                                  sections - 1,
                                                ),
                                                times: times,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRect(
                                        child: AnimatedBuilder(
                                          animation: Listenable.merge([
                                            weekMotion,
                                            dragOffset,
                                          ]),
                                          child: RepaintBoundary(
                                            child: columns(week),
                                          ),
                                          builder: (_, child) {
                                            final progress = Curves.easeOutCubic
                                                .transform(weekMotion.value);
                                            final settling = progress < 1;
                                            final shift = settling
                                                ? slideFrom * (1 - progress)
                                                : dragOffset.value;
                                            final previous =
                                                settling && fadeWeek
                                                ? outgoingWeek
                                                : null;
                                            final companion =
                                                previous ??
                                                (fadeWeek && settling
                                                    ? null
                                                    : shift < 0
                                                    ? week + 1
                                                    : shift > 0
                                                    ? week - 1
                                                    : null);
                                            final side = previous == null
                                                ? (shift < 0 ? 1 : -1)
                                                : (previous < week ? -1 : 1);
                                            final other = adjacent[companion];
                                            final incomingOpacity =
                                                previous != null
                                                ? 1 - .20 * shift.abs()
                                                : .80 + .20 * progress;
                                            return Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                if (other != null)
                                                  Transform.translate(
                                                    offset: Offset(
                                                      (shift + side) *
                                                          gridWidth,
                                                      0,
                                                    ),
                                                    child: Opacity(
                                                      opacity: previous != null
                                                          ? 1
                                                          : .80 +
                                                                .20 *
                                                                    shift.abs(),
                                                      child: IgnorePointer(
                                                        child: ExcludeSemantics(
                                                          child: other,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                Transform.translate(
                                                  key: const ValueKey(
                                                    'week-course-plane',
                                                  ),
                                                  offset: Offset(
                                                    shift * gridWidth,
                                                    0,
                                                  ),
                                                  child: Opacity(
                                                    opacity:
                                                        settling && fadeWeek
                                                        ? incomingOpacity
                                                        : 1,
                                                    child: AbsorbPointer(
                                                      absorbing: shift != 0,
                                                      child: child!,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._extras(extra, notes),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _extras(Iterable<Lesson> lessons, List notes) => [
    for (final l in lessons)
      ListTile(
        leading: const Icon(Icons.event_note_outlined),
        title: Text(l.name),
        subtitle: Text('排课时间待确认 · ${l.data['weeks'] ?? ''} ${l.place}'),
      ),
    for (final n in notes)
      ListTile(
        leading: const Icon(Icons.notes_outlined),
        title: Text(n.toString()),
      ),
  ];
}

class _DateHeader extends StatelessWidget {
  final double axis;
  final DateTime? start;
  final DateTime today;
  const _DateHeader({
    required this.axis,
    required this.start,
    required this.today,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          SizedBox(
            width: axis,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  start != null ? '${start!.month}月' : '节次',
                  maxLines: 1,
                  style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          for (int d = 0; d < 7; d++)
            Expanded(
              child: Builder(
                builder: (_) {
                  final date = start?.add(Duration(days: d)),
                      active = date == today;
                  final col = active ? c.onPrimary : c.onSurface;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 1,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 1,
                    ),
                    decoration: BoxDecoration(
                      color: active ? c.primary : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _days[d],
                            style: TextStyle(
                              color: col,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (date != null)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${date.month}/${date.day}',
                              style: TextStyle(
                                color: active ? col : c.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeRange extends StatelessWidget {
  final int first, end;
  final List times;
  const _TimeRange({
    required this.first,
    required this.end,
    required this.times,
  });
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget label(String value) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        value,
        maxLines: 1,
        style: TextStyle(
          color: c.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Semantics(
      label: '第 ${first + 1} 至 ${end + 1} 节',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            label(first < times.length ? times[first][0] : '第${first + 1}节'),
            Container(
              width: 1,
              height: 10,
              color: c.outlineVariant,
              margin: const EdgeInsets.symmetric(vertical: 3),
            ),
            label(end < times.length ? times[end][1] : '第${end + 1}节'),
          ],
        ),
      ),
    );
  }
}

class _WeekPicker extends StatefulWidget {
  const _WeekPicker({
    required this.selected,
    required this.current,
    required this.total,
    required this.lessons,
    required this.select,
  });
  final int selected, total;
  final int? current;
  final List<Lesson> lessons;
  final ValueChanged<int> select;
  @override
  State<_WeekPicker> createState() => _WeekPickerState();
}

class _WeekPickerState extends State<_WeekPicker> {
  static const _itemWidth = 58.0;
  static const _edge = 4.0;
  late final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      scroll.jumpTo(
        (_edge +
                (widget.selected - .5) * _itemWidth -
                scroll.position.viewportDimension / 2)
            .clamp(0, scroll.position.maxScrollExtent)
            .toDouble(),
      );
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final height = 58.0 + MediaQuery.textScalerOf(context).scale(14);
    return SizedBox(
      height: height,
      child: ListView.builder(
        controller: scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _edge),
        itemCount: widget.total,
        itemExtent: _itemWidth,
        itemBuilder: (ctx, i) {
          final n = i + 1,
              selected = n == widget.selected,
              current = n == widget.current;
          final occupied = <int>{
            for (final l in widget.lessons)
              if (l.weeks!.contains(n))
                for (final section in l.sections!)
                  (l.day - 1) * 5 + math.min(4, (section - 1) ~/ 2),
          };
          return Semantics(
            selected: selected,
            button: true,
            onTap: () => widget.select(n),
            label: '第 $n 周${current ? '，本周' : ''}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(1.5, 2, 1.5, 7),
                child: Material(
                  color: selected ? c.primaryContainer : c.surface,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => widget.select(n),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (current)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c.primary,
                                ),
                              ),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '第 $n 周',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: double.infinity,
                            height: 23,
                            child: CustomPaint(
                              painter: _WeekPreview(
                                occupied,
                                c.primary,
                                c.outlineVariant,
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
          );
        },
      ),
    );
  }
}

class _WeekPreview extends CustomPainter {
  final Set<int> cells;
  final Color fill, empty;
  _WeekPreview(this.cells, this.fill, this.empty);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int day = 0; day < 7; day++)
      for (int block = 0; block < 5; block++) {
        paint.color = cells.contains(day * 5 + block) ? fill : empty;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              day * size.width / 7,
              block * size.height / 5,
              size.width / 7 - 1,
              size.height / 5 - 1,
            ),
            const Radius.circular(1),
          ),
          paint,
        );
      }
  }

  @override
  bool shouldRepaint(_WeekPreview old) =>
      fill != old.fill || empty != old.empty || !setEquals(cells, old.cells);
}

class _DayColumn extends StatelessWidget {
  final int day, week, sections;
  final double unit;
  final List times;
  final List<Lesson> lessons;
  final String campus;
  final Map<String, int> colors;
  final _CourseTouch touch;
  const _DayColumn({
    required this.touch,
    required this.colors,
    required this.day,
    required this.week,
    required this.sections,
    required this.unit,
    required this.times,
    required this.lessons,
    required this.campus,
  });

  @override
  Widget build(BuildContext context) {
    final slots = [
      for (int s = 1; s <= sections; s++)
        lessons.where((l) => l.sections!.contains(s)).toList(),
    ];
    final active = [
      for (final slot in slots)
        slot.where((l) => l.weeks!.contains(week)).toList(),
    ];
    Lesson? front(int i) => active[i].firstOrNull ?? slots[i].firstOrNull;
    final blocks = <Widget>[];
    for (int i = 0; i < sections;) {
      final from = i, course = front(i);
      i++;
      if (course == null) continue;
      // A partial overlap must not cut the same visible lesson in two.
      while (i < sections && identical(front(i), course)) {
        i++;
      }
      final members = <Lesson>{for (int s = from; s < i; s++) ...slots[s]};
      final activeMembers = members
          .where((l) => l.weeks!.contains(week))
          .toList();
      final grey = activeMembers.isEmpty;
      final alternate = members.any(
        (l) => l.name != course.name && l.weeks!.any((w) => w != week),
      );
      final end = i;
      final all = [
        ...activeMembers,
        ...members.where((l) => !activeMembers.contains(l)),
      ];
      blocks.add(
        Positioned(
          top: from * unit + 1.5,
          height: (i - from) * unit - 3,
          left: 1.5,
          right: 1.5,
          child: _CourseCard(
            touch: touch,
            slot: (course, from),
            colorIndex: colors[course.name]!,
            course: course,
            grey: grey,
            alternate: alternate,
            extra: activeMembers.length - 1,
            open: () => showWikiSheet<void>(
              context,
              (_) => _CourseDetails(
                colors: colors,
                lessons: all,
                week: week,
                day: day,
                from: from + 1,
                to: end,
                times: times,
                campus: campus,
              ),
            ),
          ),
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: blocks);
  }
}

// Every visible lesson shares a single Wenku8-style contact/release clock.
class _CourseTouch {
  _CourseTouch(TickerProvider vsync)
    : clock = AnimationController(vsync: vsync);
  final AnimationController clock;
  final active = ValueNotifier<(Lesson, int)?>(null);
  late final scale = clock
      .drive(CurveTween(curve: const Cubic(.2, 1.08, .34, 1)))
      .drive(Tween(begin: 1.0, end: .97));
  void highlight((Lesson, int) slot, bool pressed) {
    if (pressed) {
      if (active.value != slot) {
        clock.value = 0;
        active.value = slot;
      }
      clock.animateTo(1, duration: const Duration(milliseconds: 120));
    } else if (active.value == slot) {
      clock.animateBack(0, duration: const Duration(milliseconds: 420));
    }
  }

  void clear() {
    clock.value = 0;
    active.value = null;
  }

  void dispose() {
    active.dispose();
    clock.dispose();
  }
}

class _CourseCard extends StatelessWidget {
  final _CourseTouch touch;
  final (Lesson, int) slot;

  final int colorIndex;
  const _CourseCard({
    required this.touch,
    required this.slot,
    required this.colorIndex,
    required this.course,
    required this.grey,
    required this.alternate,
    required this.extra,
    required this.open,
  });
  final Lesson course;
  final bool grey, alternate;
  final int extra;
  final VoidCallback open;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = _tone(colorIndex, dark);
    final bg = grey
        ? (dark ? const Color(0xff323844) : const Color(0xffdce1e5))
        : tone.fill;
    final fg = grey
        ? (dark ? const Color(0xffb4beca) : const Color(0xff586370))
        : tone.text;
    final label = [
      course.name,
      course.place,
      if (grey) '其他周',
      if (extra > 0) '本周另有 $extra 门课',
      if (alternate) '其他周还有其他课程',
    ].where((s) => s.isNotEmpty).join('，');
    return ValueListenableBuilder<(Lesson, int)?>(
      valueListenable: touch.active,
      builder: (_, active, child) => ScaleTransition(
        scale: active == slot ? touch.scale : const AlwaysStoppedAnimation(1.0),
        child: child,
      ),
      child: Semantics(
        button: true,
        label: label,
        onTap: open,
        child: ExcludeSemantics(
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              splashFactory: WikiMotion.reduced(context)
                  ? NoSplash.splashFactory
                  : InkRipple.splashFactory,
              splashColor: fg.withValues(alpha: .22),
              highlightColor: Colors.transparent,
              onHighlightChanged: (down) {
                if (!MediaQuery.disableAnimationsOf(context))
                  touch.highlight(slot, down);
              },
              onTapCancel: () {
                if (touch.active.value == slot) touch.clear();
              },
              onTap: open,
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final systemScale = MediaQuery.textScalerOf(context);
                  // Keep two Chinese characters across the narrowest columns. Full course
                  // details below use the system scale without a cap.
                  final cellScaler = systemScale.clamp(
                    maxScaleFactor: math
                        .max(1.0, (bounds.maxWidth - 9) / 27)
                        .clamp(1, 1.25)
                        .toDouble(),
                  );
                  final pad = alternate || extra > 0 ? 7.0 : 4.0;
                  const gap = 4.0;
                  final nameStyle = TextStyle(
                    fontSize: 12.5,
                    height: 1.18,
                    color: fg,
                    fontWeight: grey ? FontWeight.w500 : FontWeight.w600,
                  );
                  final placeStyle = TextStyle(
                    fontSize: 11.5,
                    height: 1.18,
                    color: fg.withValues(alpha: .93),
                    fontWeight: FontWeight.w400,
                  );
                  final room = course.place.replaceAllMapped(
                    RegExp(r'([楼区馆])(?=[A-Za-z0-9])'),
                    (m) => '${m[0]}​',
                  );
                  final nameLine =
                      cellScaler.scale(nameStyle.fontSize!) * nameStyle.height!;
                  final roomLine =
                      cellScaler.scale(placeStyle.fontSize!) *
                      placeStyle.height!;
                  final available = bounds.maxHeight - 2 * pad - 3;
                  // Keep a line for the title, then reserve only the room lines
                  // the actual text needs at this column width.
                  final roomCapacity = math.max(
                    0,
                    (available - 2 * nameLine - gap) ~/ roomLine,
                  );
                  final painter = TextPainter(
                    text: TextSpan(text: room, style: placeStyle),
                    textDirection: Directionality.of(context),
                    textScaler: cellScaler,
                    maxLines: 3,
                  )..layout(maxWidth: math.max(0, bounds.maxWidth - 6));
                  final roomLines = room.isEmpty
                      ? 0
                      : math.min(
                          roomCapacity,
                          painter.computeLineMetrics().length,
                        );
                  painter.dispose();
                  final nameSpace =
                      available -
                      (roomLines == 0 ? 0 : gap + roomLines * roomLine);
                  final nameLines = (nameSpace ~/ nameLine).clamp(
                    1,
                    roomLines > 0 ? 3 : 4,
                  );

                  Widget centered(String text, TextStyle style, int lines) =>
                      Text(
                        text,
                        textScaler: cellScaler,
                        textAlign: TextAlign.center,
                        maxLines: lines,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                        strutStyle: StrutStyle.fromTextStyle(
                          style,
                          forceStrutHeight: true,
                        ),
                      );

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: pad,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              centered(
                                course.name.trim(),
                                nameStyle,
                                nameLines,
                              ),
                              if (roomLines > 0) ...[
                                const SizedBox(height: gap),
                                centered(room, placeStyle, roomLines),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (alternate)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: CustomPaint(
                            key: const ValueKey('other-week-corner'),
                            painter: _OtherWeekCorner(
                              dark
                                  ? const Color(0xffe9e6ef)
                                  : Color.lerp(bg, fg, .68)!,
                            ),
                            size: const Size.square(8),
                          ),
                        ),
                      if (extra > 0)
                        Positioned(
                          left: 2,
                          top: 1,
                          child: Text(
                            '+$extra',
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontSize: 9,
                              height: 1,
                              color: fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtherWeekCorner extends CustomPainter {
  const _OtherWeekCorner(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final triangle = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_OtherWeekCorner oldDelegate) =>
      oldDelegate.color != color;
}

class _CourseDetails extends StatelessWidget {
  final Map<String, int> colors;
  const _CourseDetails({
    required this.colors,
    required this.lessons,
    required this.week,
    required this.day,
    required this.from,
    required this.to,
    required this.times,
    required this.campus,
  });
  final List<Lesson> lessons;
  final int week, day, from, to;
  final List times;
  final String campus;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final time = to <= times.length
        ? '${times[from - 1][0]}–${times[to - 1][1]}'
        : '';
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .74,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            ArchivePart(
              start: .12,
              end: .78,
              child: Text(
                '${_days[day - 1]} · 第 ${from == to ? from : "$from–$to"} 节',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: ArchivePart(
                  start: .20,
                  end: .90,
                  travel: const Offset(-8, 0),
                  child: Text(
                    '$time · ${campus}作息',
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            for (final l in lessons)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surfaceContainerLow,
                    border: Border.all(color: c.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _tone(colors[l.name]!, dark).fill,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ArchivePart(
                                start: .28,
                                end: .96,
                                travel: const Offset(-8, 0),
                                child: Text(
                                  l.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l.weeks!.contains(week) ? '本周' : '其他周',
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        for (final e in <String, String>{
                          if (l.place.isNotEmpty) '教室': l.place,
                          if ((l.data['teacher'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            '教师': l.data['teacher'].toString(),
                          if ((l.data['campus'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            '校区': l.data['campus'].toString(),
                          if ((l.data['group'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            '分组': l.data['group'].toString(),
                          '周次': '${l.data['weeks']}',
                          '节次':
                              '${_days[l.day - 1]} · 第 ${_runs(l.sections!)} 节',
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.key,
                                  style: TextStyle(color: c.onSurfaceVariant),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Text(e.value)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _runs(List<int> values) {
    final labels = <String>[];
    for (int i = 0; i < values.length;) {
      final first = values[i++];
      while (i < values.length && values[i] == values[i - 1] + 1) {
        i++;
      }
      labels.add(first == values[i - 1] ? '$first' : '$first–${values[i - 1]}');
    }
    return labels.join('、');
  }
}
