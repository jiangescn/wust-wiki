import 'package:flutter/material.dart';

import 'academic.dart' show Lesson;
import 'countdown.dart';
import 'daily_timeline.dart';
import 'exam_schedule.dart';
import 'personal_schedule.dart';

class HomeExamRow extends StatelessWidget {
  const HomeExamRow({required this.exam, required this.now});

  final ScheduledExam exam;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = exam.startsAt!;
    final local = start.toUtc().add(const Duration(hours: 8));
    final date = '${local.month}月${local.day}日';
    final time = clockLabel(local.hour * 60 + local.minute);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (exam.room.isNotEmpty) Text(exam.room, style: secondary),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ExamTimeBadge(start.difference(now)),
                const SizedBox(height: 4),
                Text('$date $time', textAlign: TextAlign.end, style: secondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TodayPeriodRow extends StatelessWidget {
  const TodayPeriodRow({
    required this.lesson,
    required this.sections,
    required this.start,
    required this.end,
    required this.now,
    required this.accent,
    required this.next,
  });
  final Lesson lesson;
  final String sections;
  final int now;
  final bool next;
  final Color accent;
  final String? start, end;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasTime = start != null && end != null;
    final startMinute = clockMinutes(start), endMinute = clockMinutes(end);
    final active =
        startMinute != null &&
        endMinute != null &&
        now >= startMinute &&
        now < endMinute;
    final finished = endMinute != null && now >= endMinute;
    final until = startMinute == null ? null : startMinute - now;
    final status = active
        ? '上课中'
        : next && until != null && until > 0
        ? [
            if (until >= 60) '${until ~/ 60} 小时',
            if (until % 60 != 0) '${until % 60} 分钟',
            '后开始',
          ].join(' ').replaceFirst(' 后开始', '后开始')
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 6),
            child: Icon(
              Icons.circle,
              size: 8,
              color: finished ? accent.withValues(alpha: .54) : accent,
            ),
          ),
          SizedBox(
            width: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasTime ? start! : sections,
                  style: TextStyle(
                    color: finished ? colors.onSurfaceVariant : accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasTime)
                  Text(end!, style: TextStyle(color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      if (status != null)
                        TextSpan(
                          text: '$status · ',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      TextSpan(text: lesson.name),
                    ],
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: finished
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                ),
                Text(
                  [
                    if (hasTime) sections,
                    if (lesson.place.isNotEmpty) lesson.place,
                    if (lesson case final PersonalLesson course)
                      course.sourceLabel,
                  ].join(' · '),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
