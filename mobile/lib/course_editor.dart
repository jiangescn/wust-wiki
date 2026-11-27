import 'package:flutter/material.dart';

import 'academic.dart';
import 'blog_surface.dart';
import 'personal_schedule.dart';
import 'wiki_motion.dart';
import 'wiki_page.dart';

Future<void> openCourseEditor(
  BuildContext context,
  AcademicStore store,
  int week, {
  Lesson? source,
  bool edit = false,
}) async {
  final data = await nativeData;
  if (!context.mounted) return;
  final times = data['times']?[store.campus] as List? ?? [];
  if (times.isEmpty) return;
  await Navigator.of(context).push(
    WikiRoute(
      _CourseEditor(
        store: store,
        week: week,
        bellTimes: times,
        source: source,
        edit: edit,
      ),
      WikiMotion.reduced(context),
    ),
  );
}

enum _Repeat { once, weekly }

class _TimeDraft {
  _TimeDraft({
    required this.week,
    required this.day,
    required this.first,
    required this.last,
    PersonalTime? time,
    String initialTeacher = '',
  }) : id = time?.id ?? newScheduleId(),
       date = time?.date,
       repeat = time?.date == null ? _Repeat.weekly : _Repeat.once,
       weeks = time == null || time.weeks.isEmpty
           ? [week]
           : time.weeks.toList(),
       place = TextEditingController(text: time?.place),
       teacher = TextEditingController(text: time?.teacher ?? initialTeacher);

  final String id;
  final TextEditingController place, teacher;
  int week, day, first, last;
  _Repeat repeat;
  List<int> weeks;
  DateTime? date;

  DateTime? occurrence(DateTime? monday) =>
      date ?? monday?.add(Duration(days: (week - 1) * 7 + day - 1));

  PersonalTime build(DateTime monday) => PersonalTime(
    id: id,
    day: day,
    first: first,
    last: last,
    weeks: repeat == _Repeat.weekly ? weeks : const [],
    date: repeat == _Repeat.once ? occurrence(monday) : null,
    place: place.text.trim(),
    teacher: teacher.text.trim(),
  );

  void dispose() {
    place.dispose();
    teacher.dispose();
  }
}

class _CourseEditor extends StatefulWidget {
  const _CourseEditor({
    required this.store,
    required this.week,
    required this.bellTimes,
    this.source,
    required this.edit,
  });

  final AcademicStore store;
  final int week;
  final List bellTimes;
  final Lesson? source;
  final bool edit;

  @override
  State<_CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<_CourseEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.source?.name);
  late final _note = TextEditingController(text: _existing?.note);
  late final String _term, _owner;
  late final String _id = _existing?.id ?? newScheduleId();
  DateTime? _monday;
  late final List<_TimeDraft> _drafts;
  final _removed = <_TimeDraft>[];
  bool _saving = false;

  PersonalLesson? get _personal => switch (widget.source) {
    final PersonalLesson value => value,
    _ => null,
  };
  PersonalCourse? get _existing => _personal?.course;
  bool get _supplement => _existing?.supplement ?? (widget.source != null);
  bool get _newCourse => widget.source == null;

  _TimeDraft _initialTime() {
    final source = widget.source;
    final old = widget.edit ? _personal?.time : null;
    final min = (old?.first ?? source?.sections?.firstOrNull ?? 1).clamp(
      1,
      widget.bellTimes.length,
    );
    final max = (old?.last ?? source?.sections?.lastOrNull ?? min).clamp(
      min,
      widget.bellTimes.length,
    );
    return _TimeDraft(
      week: widget.week.clamp(1, maxPersonalWeeks),
      day:
          old?.day ??
          ((source?.day ?? 0) >= 1 ? source!.day : chinaDay().weekday),
      first: min,
      last: max,
      time: old,
      initialTeacher: source?.data['teacher']?.toString() ?? '',
    );
  }

  @override
  void initState() {
    super.initState();
    _term = widget.store.courseTerm;
    _owner = _existing?.owner ?? widget.store.courseOwner;
    _monday = widget.store.courseTermMonday;
    _drafts = [_initialTime()];
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    for (final draft in [..._drafts, ..._removed]) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseMonday() async {
    final today = chinaDay();
    final date = await showDatePicker(
      context: context,
      helpText: '选择第 1 教学周的周一',
      initialDate: _monday ?? today.subtract(Duration(days: today.weekday - 1)),
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 3),
      selectableDayPredicate: (value) => value.weekday == DateTime.monday,
    );
    if (date != null && mounted) setState(() => _monday = calendarDate(date));
  }

  Future<void> _chooseDate(_TimeDraft draft) async {
    final monday = _monday;
    if (monday == null) return;
    final date = await showDatePicker(
      context: context,
      helpText: '选择上课日期',
      initialDate: draft.occurrence(monday),
      firstDate: monday,
      lastDate: monday.add(const Duration(days: maxPersonalWeeks * 7 - 1)),
    );
    if (date == null || !mounted) return;
    setState(() {
      draft.date = calendarDate(date);
      draft.day = date.weekday;
      draft.week = weekAt(monday, date)!;
    });
  }

  Future<void> _chooseWeeks(_TimeDraft draft) async {
    final weeks = await showWikiDialog<List<int>>(
      context,
      (_) => _ChooseWeeks(draft.weeks),
    );
    if (weeks != null && mounted) setState(() => draft.weeks = weeks);
  }

  void _addTime() {
    final previous = _drafts.last;
    setState(
      () => _drafts.add(
        _TimeDraft(
          week: previous.week,
          day: previous.day % 7 + 1,
          first: previous.first,
          last: previous.last,
          initialTeacher: previous.teacher.text,
        ),
      ),
    );
  }

  PersonalCourse _course(List<PersonalTime> times) => PersonalCourse(
    id: _id,
    owner: _owner,
    term: _term,
    name: _name.text.trim(),
    note: _note.text.trim(),
    supplement: _supplement,
    times: times,
  );

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入课程名称')));
      return;
    }
    FocusScope.of(context).unfocus();
    final monday = _monday;
    if (monday == null) {
      await _chooseMonday();
      return;
    }
    setState(() => _saving = true);
    try {
      final times = _drafts.map((draft) => draft.build(monday)).toList();
      final editedId = widget.edit ? _personal?.time.id : null;
      final conflicts = courseConflicts(
        widget.store.displayedLessons.where(
          (item) => item is! PersonalLesson || item.time.id != editedId,
        ),
        _course(times).lessons(monday),
      );
      if (conflicts.isNotEmpty) {
        final approved = await showWikiDialog<bool>(
          context,
          (dialog) => AlertDialog(
            title: const Text('上课时间有重叠'),
            content: SingleChildScrollView(child: Text(conflicts.join('\n'))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('返回修改'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('仍然保存'),
              ),
            ],
          ),
        );
        if (approved != true || !mounted) return;
      }
      final previous = _existing?.times ?? const <PersonalTime>[];
      final next = widget.edit
          ? [
              for (final time in previous)
                time.id == editedId ? times.single : time,
            ]
          : [...previous, ...times];
      await _persist(_course(next), monday);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_saving) return;
    final lesson = _personal!;
    final confirmed = await showWikiDialog<bool>(
      context,
      (dialog) => AlertDialog(
        title: const Text('删除这个上课时段？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _persist(
        lesson.course.withTimes([
          for (final time in lesson.course.times)
            if (time.id != lesson.time.id) time,
        ]),
        _monday!,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _persist(PersonalCourse course, DateTime monday) async {
    try {
      await widget.store.savePersonalCourse(course, monday: monday);
      if (mounted) Navigator.pop(context);
    } on Exception catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is FormatException ? error.message : '保存失败，请重试',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semester = _term.substring(_term.length - 1);
    final year = _term.substring(0, _term.length - 2);
    final title = widget.edit
        ? '编辑上课时间'
        : _newCourse
        ? '添加课程'
        : '添加上课时间';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              BlogPanel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$year · 第 $semester 学期',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    if (_newCourse || (widget.edit && !_supplement))
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '课程名称'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请输入课程名称'
                            : null,
                      )
                    else
                      Text(
                        _name.text,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    if (_newCourse || (widget.edit && !_supplement)) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _note,
                        decoration: const InputDecoration(labelText: '备注'),
                      ),
                    ],
                    if (_monday == null)
                      TextButton.icon(
                        onPressed: _chooseMonday,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('设置第 1 教学周'),
                      ),
                  ],
                ),
              ),
              for (final (index, draft) in _drafts.indexed) ...[
                const SizedBox(height: 12),
                _timePanel(draft, index),
              ],
              if (_newCourse)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: _addTime,
                    icon: const Icon(Icons.add),
                    label: const Text('再加一个上课时间'),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('保存'),
              ),
              if (widget.edit && _monday != null)
                TextButton(
                  onPressed: _saving ? null : _delete,
                  child: const Text('删除这个时段'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timePanel(_TimeDraft draft, int index) {
    final date = draft.occurrence(_monday);
    final times = widget.bellTimes;
    return BlogPanel(
      key: ValueKey(draft.id),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_drafts.length > 1)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '上课时间 ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: '移除这个时段',
                  onPressed: () =>
                      setState(() => _removed.add(_drafts.removeAt(index))),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          SegmentedButton<_Repeat>(
            segments: const [
              ButtonSegment(value: _Repeat.once, label: Text('仅此一次')),
              ButtonSegment(value: _Repeat.weekly, label: Text('按周重复')),
            ],
            selected: {draft.repeat},
            onSelectionChanged: (value) =>
                setState(() => draft.repeat = value.single),
          ),
          const SizedBox(height: 8),
          if (draft.repeat == _Repeat.once && date != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('上课日期'),
              subtitle: Text(
                '${date.month}月${date.day}日 · ${weekDays[date.weekday - 1]} · 第 ${weekAt(_monday!, date)} 周',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () => _chooseDate(draft),
            )
          else if (draft.repeat == _Repeat.weekly) ...[
            _numberField(
              '星期',
              draft.day,
              1,
              7,
              (value) => setState(() => draft.day = value),
              labels: weekDays,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('上课周次'),
              subtitle: Text('第 ${formatNumberRanges(draft.weeks)} 周'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _chooseWeeks(draft),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _numberField(
                  '开始节次',
                  draft.first,
                  1,
                  times.length,
                  (value) => setState(() {
                    draft.first = value;
                    if (draft.last < value) draft.last = value;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(
                  '结束节次',
                  draft.last,
                  draft.first,
                  times.length,
                  (value) => setState(() => draft.last = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${times[draft.first - 1][0]}–${times[draft.last - 1][1]}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: draft.place,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '教室'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: draft.teacher,
            decoration: const InputDecoration(labelText: '教师'),
          ),
        ],
      ),
    );
  }
}

Widget _numberField(
  String label,
  int value,
  int min,
  int max,
  ValueChanged<int> changed, {
  List<String>? labels,
}) => InputDecorator(
  decoration: InputDecoration(labelText: label),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<int>(
      isDense: true,
      isExpanded: true,
      value: value,
      onChanged: (value) {
        if (value != null) changed(value);
      },
      items: [
        for (var number = min; number <= max; number++)
          DropdownMenuItem(
            value: number,
            child: Text(labels?[number - 1] ?? '$number'),
          ),
      ],
    ),
  ),
);

class _ChooseWeeks extends StatefulWidget {
  const _ChooseWeeks(this.weeks);
  final List<int> weeks;
  @override
  State<_ChooseWeeks> createState() => _ChooseWeeksState();
}

class _ChooseWeeksState extends State<_ChooseWeeks> {
  late final _selected = widget.weeks.toSet();
  int? _start, _end;
  Set<int>? _beforeDrag;

  void _select(Iterable<int> weeks) => setState(() {
    _selected
      ..clear()
      ..addAll(weeks);
  });

  void _extendDrag(int? week) {
    final start = _start, original = _beforeDrag;
    if (start == null || original == null || week == null || week == _end)
      return;
    _end = week;
    final first = start < week ? start : week;
    final last = start > week ? start : week;
    final range = List.generate(last - first + 1, (index) => first + index);
    final next = original.toSet();
    if (original.contains(start)) {
      next.removeAll(range);
    } else {
      next.addAll(range);
    }
    _select(next);
  }

  void _endDrag() {
    _start = _end = null;
    _beforeDrag = null;
  }

  Widget _grid(ColorScheme colors) => LayoutBuilder(
    builder: (context, bounds) {
      const gap = 4.0, height = 44.0;
      final columns = ((bounds.maxWidth + gap) / 52).floor().clamp(4, 9);
      final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
      final rows = (maxPersonalWeeks / columns).ceil();
      final gridHeight = rows * (height + gap) - gap;

      int? weekAtPosition(Offset offset) {
        if (offset.dx < 0 ||
            offset.dx >= bounds.maxWidth ||
            offset.dy < 0 ||
            offset.dy >= gridHeight)
          return null;
        final column = (offset.dx / (width + gap)).floor();
        final row = (offset.dy / (height + gap)).floor();
        final week = row * columns + column + 1;
        return week <= maxPersonalWeeks ? week : null;
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) => _start = weekAtPosition(details.localPosition),
        onPanStart: (details) {
          _beforeDrag = _selected.toSet();
          _extendDrag(weekAtPosition(details.localPosition) ?? _start);
        },
        onPanUpdate: (details) =>
            _extendDrag(weekAtPosition(details.localPosition)),
        onPanEnd: (_) => _endDrag(),
        onPanCancel: () {
          if (_beforeDrag case final original?) _select(original);
          _endDrag();
        },
        child: SizedBox(
          height: gridHeight,
          child: Stack(
            children: [
              for (var index = 0; index < maxPersonalWeeks; index++)
                Positioned(
                  key: ValueKey('course-week-${index + 1}'),
                  left: index % columns * (width + gap),
                  top: index ~/ columns * (height + gap),
                  width: width,
                  height: height,
                  child: _weekCell(index + 1, colors),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _weekCell(int week, ColorScheme colors) {
    final selected = _selected.contains(week);
    return Semantics(
      label: '第 $week 周',
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => setState(() {
            if (!_selected.remove(week)) _selected.add(week);
          }),
          child: Center(
            child: ExcludeSemantics(
              child: Text(
                '$week',
                style: TextStyle(
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeks = List.generate(maxPersonalWeeks, (index) => index + 1);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('选择上课周次', style: theme.textTheme.titleMedium),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _select(weeks),
                    child: const Text('全选'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _select(weeks.where((week) => week.isOdd)),
                    child: const Text('单周'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        _select(weeks.where((week) => week.isEven)),
                    child: const Text('双周'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => _select(const []),
                    child: const Text('清空'),
                  ),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(child: _grid(theme.colorScheme)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已选 ${_selected.length} 周',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () =>
                            Navigator.pop(context, _selected.toList()..sort()),
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
