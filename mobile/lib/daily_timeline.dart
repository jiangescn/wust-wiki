import 'dart:math' as math;

import 'package:flutter/material.dart';

int? clockMinutes(String? value) {
  if (value == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (m == null) return null;
  final hour = int.parse(m[1]!), minute = int.parse(m[2]!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String clockLabel(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

typedef DailySegment = ({int start, int end, Color color});

class DailyTimeline extends StatelessWidget {
  const DailyTimeline({required this.segments, required this.now, super.key});

  final List<DailySegment> segments;
  final int now;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final first = segments.map((segment) => segment.start).reduce(math.min);
    final last = segments.map((segment) => segment.end).reduce(math.max);
    final start = (first - 15).clamp(0, 1440) ~/ 60 * 60;
    final end = ((last + 15 + 59) ~/ 60 * 60).clamp(start + 60, 1440);
    final track = colors.outlineVariant;
    final current = now >= start && now <= end;
    final text = theme.textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (current)
            Text(
              '现在 ${clockLabel(now)}',
              style: text?.copyWith(color: colors.onPrimaryContainer),
            ),
          Semantics(
            label: '课程时间轴，${clockLabel(start)}至${clockLabel(end)}',
            child: LayoutBuilder(
              builder: (context, bounds) {
                double x(int minute) =>
                    (minute - start) / (end - start) * bounds.maxWidth;
                return SizedBox(
                  height: 29,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 13,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: track,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      for (final segment in segments)
                        Positioned(
                          left: x(segment.start),
                          width: x(segment.end) - x(segment.start),
                          top: 10,
                          height: 9,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: segment.end <= now
                                  ? segment.color.withValues(alpha: .54)
                                  : segment.color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      if (current)
                        Positioned(
                          left: x(now)
                              .clamp(0, math.max(0, bounds.maxWidth - 2))
                              .toDouble(),
                          top: 3,
                          height: 23,
                          width: 2,
                          child: ColoredBox(color: colors.onSurface),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(clockLabel(start), style: text),
              if (MediaQuery.textScalerOf(context).scale(12) <= 19 &&
                  end - start >= 180)
                Text(clockLabel((start + end) ~/ 2), style: text),
              Text(clockLabel(end), style: text),
            ],
          ),
        ],
      ),
    );
  }
}
