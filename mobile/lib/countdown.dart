import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'academic.dart' show AcademicStore, platform;
import 'archive_motion.dart';
import 'blog_surface.dart';
import 'delayed_loading.dart';
import 'exam_schedule.dart';

class _Exam {
  const _Exam(this.name, this.startsAt, this.note);

  factory _Exam.fromJson(Map<String, dynamic> json) => _Exam(
    json['name'] as String,
    DateTime.fromMillisecondsSinceEpoch(json['startsAt'] as int),
    json['note'] as String,
  );

  final String name, note;
  final DateTime startsAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'startsAt': startsAt.millisecondsSinceEpoch,
    'note': note,
  };
}

class CountdownPage extends StatefulWidget {
  const CountdownPage({this.mark, this.store, super.key});

  final WikiPageMark? mark;
  final AcademicStore? store;

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage> {
  List<_Exam>? _exams;
  bool _loadFailed = false, _saving = false;
  DateTime _now = DateTime.now();
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _load();
    widget.store?.addListener(_examScheduleChanged);
    widget.store?.ensureExamSchedule();
    _clock = Timer.periodic(const Duration(seconds: 15), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    widget.store?.removeListener(_examScheduleChanged);
    _clock.cancel();
    super.dispose();
  }

  void _examScheduleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final raw = await platform.invokeMethod<String>('loadCountdowns');
      final records = jsonDecode(raw ?? '[]') as List<dynamic>;
      final exams = records
          .map((record) => _Exam.fromJson(record as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() => _exams = exams);
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _save(List<_Exam> exams) async {
    setState(() => _saving = true);
    try {
      await platform.invokeMethod<void>('saveCountdowns', jsonEncode(exams));
      if (mounted) setState(() => _exams = exams);
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit({_Exam? original}) async {
    final changed = await showDialog<_Exam>(
      context: context,
      builder: (_) => _ExamEditor(
        editing: original != null,
        name: original?.name ?? '',
        note: original?.note ?? '',
        startsAt: original?.startsAt,
      ),
    );
    if (!mounted || changed == null) return;
    await _save([
      for (final exam in _exams!) identical(exam, original) ? changed : exam,
      if (original == null) changed,
    ]);
  }

  Future<void> _remove(_Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除倒计时？'),
        content: Text(exam.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _save(_exams!.where((item) => !identical(item, exam)).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final school = widget.store?.examSchedule ?? const <ScheduledExam>[];
    final schoolUpcoming = upcomingExams(school, _now);
    final schoolUnscheduled = school.where((exam) => exam.startsAt == null);
    final schoolPast =
        school.where((exam) => exam.startsAt?.isBefore(_now) ?? false).toList()
          ..sort((a, b) => b.startsAt!.compareTo(a.startsAt!));
    final exams = _exams
        ?.where(
          (manual) => !school.any(
            (exam) =>
                exam.name == manual.name &&
                exam.startsAt?.isAtSameMomentAs(manual.startsAt) == true,
          ),
        )
        .toList();
    final upcoming =
        exams?.where((exam) => exam.startsAt.isAfter(_now)).toList()
          ?..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = exams?.where((exam) => !exam.startsAt.isAfter(_now)).toList()
      ?..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return Scaffold(
      appBar: AppBar(title: WikiPageTitle('考试倒计时', mark: widget.mark)),
      floatingActionButton:
          exams != null && (exams.isNotEmpty || school.isNotEmpty)
          ? FloatingActionButton(
              tooltip: '添加倒计时',
              onPressed: _saving ? null : _edit,
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(
        top: false,
        child: exams == null
            ? Center(
                child: _loadFailed
                    ? OutlinedButton(
                        onPressed: _load,
                        child: const Text('重新读取倒计时'),
                      )
                    : const DelayedLoading(child: CircularProgressIndicator()),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  BlogPanel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatFullDate(_now),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${upcoming!.length + schoolUpcoming.length} 门待考',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (school.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '教务考试',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final exam in [
                      ...schoolUpcoming,
                      ...schoolUnscheduled,
                    ])
                      _SchoolExamRow(exam, now: _now),
                    if (schoolPast.isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('已开考 ${schoolPast.length} 门'),
                        children: [
                          for (final exam in schoolPast)
                            _SchoolExamRow(exam, now: _now),
                        ],
                      ),
                  ],
                  if (exams.isEmpty && school.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Center(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _edit,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('添加倒计时'),
                        ),
                      ),
                    )
                  else if (exams.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (school.isNotEmpty)
                      Text('手动添加', style: theme.textTheme.titleMedium),
                    ContentReveal.sequence(
                      Column(
                        children: [
                          for (final (index, exam) in [
                            ...upcoming,
                            ...past!,
                          ].indexed)
                            ArchivePart.staggered(
                              index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _CountdownCard(
                                  exam,
                                  now: _now,
                                  onEdit: _saving
                                      ? null
                                      : () => _edit(original: exam),
                                  onRemove: _saving
                                      ? null
                                      : () => _remove(exam),
                                ),
                              ),
                            ),
                        ],
                      ),
                      revision: exams,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SchoolExamRow extends StatelessWidget {
  const _SchoolExamRow(this.exam, {required this.now});

  final ScheduledExam exam;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final remaining = exam.startsAt?.difference(now);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: BlogPanel(
        ListTile(
          title: Text(exam.name),
          subtitle: Text(
            [
              exam.time.isEmpty ? '时间待公布' : exam.time,
              if (exam.room.isNotEmpty) exam.room,
            ].join('\n'),
          ),
          trailing: remaining != null && !remaining.isNegative
              ? ExamTimeBadge(remaining)
              : null,
        ),
        quiet: true,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class ExamTimeBadge extends StatelessWidget {
  const ExamTimeBadge(this.remaining, {super.key});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (count, unit) = remaining.inDays > 0
        ? (remaining.inDays, '天')
        : remaining.inHours > 0
        ? (remaining.inHours, '小时')
        : (
            (remaining.inMilliseconds / Duration.millisecondsPerMinute).ceil(),
            '分钟',
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text.rich(
          TextSpan(
            text: '还有 ',
            children: [
              TextSpan(
                text: '$count',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(text: ' $unit'),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _formatTime(BuildContext context, DateTime value) {
  final locale = MaterialLocalizations.of(context);
  final time = locale.formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: true,
  );
  return '${locale.formatCompactDate(value)}  $time';
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard(
    this.exam, {
    required this.now,
    this.onEdit,
    this.onRemove,
  });

  final _Exam exam;
  final DateTime now;
  final VoidCallback? onEdit, onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final remaining = exam.startsAt.difference(now);
    final done = remaining <= Duration.zero;
    final (count, unit) = remaining.inDays > 0
        ? (remaining.inDays, '天')
        : remaining.inHours > 0
        ? (remaining.inHours, '小时')
        : ((remaining.inSeconds / 60).ceil(), '分钟');
    final accent = done ? colors.onSurfaceVariant : colors.onPrimaryContainer;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: colors.outlineVariant),
    );
    return Material(
      color: colors.surface,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 4, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 30,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(context, exam.startsAt),
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (exam.note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          exam.note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: done
                    ? Text(
                        '已到时间',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                        ),
                      )
                    : Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            '$count',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [
                                const FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Text(unit, style: TextStyle(color: accent)),
                        ],
                      ),
              ),
              PopupMenuButton<String>(
                tooltip: '倒计时选项',
                enabled: onEdit != null,
                onSelected: (choice) =>
                    choice == 'edit' ? onEdit?.call() : onRemove?.call(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'remove', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamEditor extends StatefulWidget {
  const _ExamEditor({
    required this.editing,
    required this.name,
    required this.note,
    this.startsAt,
  });

  final bool editing;
  final String name, note;
  final DateTime? startsAt;

  @override
  State<_ExamEditor> createState() => _ExamEditorState();
}

class _ExamEditorState extends State<_ExamEditor> {
  final _form = GlobalKey<FormState>();
  late String _name = widget.name, _note = widget.note;
  late DateTime? _startsAt = widget.startsAt;
  bool _missingTime = false;

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final value = _startsAt ?? DateTime.now().add(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null || !mounted) return;
    setState(() {
      _startsAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      _missingTime = false;
    });
  }

  void _submit() {
    final valid = _form.currentState!.validate();
    final time = _startsAt;
    if (time == null) setState(() => _missingTime = true);
    if (valid && time != null)
      Navigator.pop(context, _Exam(_name.trim(), time, _note.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.editing ? '编辑倒计时' : '添加倒计时'),
    content: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: _name,
            decoration: const InputDecoration(labelText: '考试科目'),
            textInputAction: TextInputAction.next,
            maxLength: 60,
            onChanged: (value) => _name = value,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '输入考试科目' : null,
          ),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _startsAt == null ? '选择考试时间' : _formatTime(context, _startsAt!),
            ),
          ),
          if (_missingTime)
            Text(
              '选择考试时间后再保存',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _note,
            decoration: const InputDecoration(labelText: '地点或备注'),
            maxLength: 160,
            maxLines: 2,
            onChanged: (value) => _note = value,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}
