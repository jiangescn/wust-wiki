import 'package:flutter/material.dart';

import 'archive_motion.dart';
import 'blog_surface.dart';
import 'wiki_page.dart';

typedef _Fields = Map<String, String>;

const _statistics = [
  ('学期数', '统计学期', '个'),
  ('已修门数', '已修门数', '门'),
  ('已修学分', '已修学分', '学分'),
  ('学期平均学分', '学期平均学分', '学分'),
  ('不及格门数', '不及格门数', '门'),
  ('不及格学分', '不及格学分', '学分'),
  ('未选门数', '未选门数', '门'),
  ('未选学分', '未选学分', '学分'),
  ('必修未获学分门数', '必修未获门数', '门'),
  ('必修未获学分', '必修未获学分', '学分'),
];

class MajorProgress extends StatelessWidget {
  const MajorProgress({
    required this.statistics,
    required this.graduation,
    required this.generalEducation,
    required this.courses,
    super.key,
  });

  final _Fields? statistics;
  final List<_Fields> graduation, generalEducation, courses;

  @override
  Widget build(BuildContext context) {
    final stats = statistics ?? const <String, String>{};
    if (stats.isEmpty &&
        graduation.isEmpty &&
        generalEducation.isEmpty &&
        courses.isEmpty) {
      return const ListTile(title: Text('暂无主修进度'));
    }
    final theme = Theme.of(context), colors = theme.colorScheme;
    final metrics = [
      for (final (key, label, unit) in const [
        ('已修门数', '已修课程', '门'),
        ('不及格门数', '不及格', '门'),
        ('必修未获学分门数', '必修未获', '门'),
        ('未选学分', '未选学分', '分'),
      ])
        if (stats[key] case final value?) (label, '$value $unit'),
    ];
    final details = [
      (
        '课程统计',
        stats['学期数'] == null ? null : '${stats['学期数']} 个学期',
        _statisticsDetails,
      ),
      (
        '毕业学分完成情况',
        '${graduation.length} 个类别',
        () => _creditDetails(graduation),
      ),
      (
        '通识选修类别',
        '${generalEducation.length} 个类别',
        () => _creditDetails(generalEducation),
      ),
      ('培养方案课程明细', '${courses.length} 门课程', _courseDetails),
    ];
    return ContentReveal.sequence(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats['已修学分'] case final earned?)
            ArchivePart.staggered(
              0,
              child: BlogPanel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('已修学分', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        text: earned,
                        children: [
                          TextSpan(
                            text: ' 分',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (metrics.isNotEmpty) ...[
            _section(context, '完成概览'),
            ArchivePart.staggered(
              1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 8.0;
                  final columns =
                      constraints.maxWidth >= 260 &&
                          MediaQuery.textScalerOf(context).scale(16) <= 24
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * gap) / columns -
                      .01;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final (label, value) in metrics)
                        SizedBox(
                          width: width,
                          child: BlogPanel(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 4),
                                Text(value, style: theme.textTheme.titleLarge),
                              ],
                            ),
                            quiet: true,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
          _section(context, '查看明细'),
          ArchivePart.staggered(
            2,
            child: BlogPanel(
              Column(
                children: [
                  for (final (index, (title, caption, content))
                      in details.indexed) ...[
                    if (index > 0) const Divider(height: 1, indent: 16),
                    ListTile(
                      title: Text(title),
                      subtitle: caption == null ? null : Text(caption),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(context, title, content()),
                    ),
                  ],
                ],
              ),
              padding: EdgeInsets.zero,
              quiet: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );

  void _open(BuildContext context, String title, List<Widget> content) {
    Navigator.of(context).push(
      WikiRoute(
        Scaffold(
          appBar: AppBar(title: WikiPageTitle(title)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: content,
            ),
          ),
        ),
        MediaQuery.disableAnimationsOf(context),
      ),
    );
  }

  List<Widget> _statisticsDetails() => [
    if (statistics case final stats? when stats.isNotEmpty)
      BlogPanel(
        Column(
          children: [
            for (final (key, label, unit) in _statistics)
              if (stats[key] case final value?)
                _ProgressMetric(label, '$value $unit'),
          ],
        ),
        padding: EdgeInsets.zero,
        quiet: true,
      )
    else
      const ListTile(title: Text('暂无课程统计')),
  ];

  List<Widget> _creditDetails(List<_Fields> credits) => [
    if (credits.isEmpty)
      const ListTile(title: Text('暂无学分记录'))
    else
      BlogPanel(
        Column(
          children: [
            for (final (index, row) in credits.indexed) ...[
              if (index > 0) const Divider(height: 1),
              _ProgressCredits(row),
            ],
          ],
        ),
        quiet: true,
      ),
  ];

  List<Widget> _courseDetails() {
    final terms = <String, List<_Fields>>{};
    for (final course in courses) {
      terms.putIfAbsent(course['学期'] ?? '未分学期', () => []).add(course);
    }
    return [
      if (terms.isEmpty) const ListTile(title: Text('暂无课程明细')),
      for (final term in terms.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Text(term.key),
        ),
        BlogPanel(
          Column(
            children: [
              for (final (index, course) in term.value.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 16),
                ListTile(
                  title: Text(course['课程']!),
                  subtitle: Text(
                    [
                      for (final name in ['课程性质', '课程属性', '状态'])
                        if (course[name] case final value?) value,
                    ].toSet().join(' · '),
                  ),
                  trailing: course['学分'] == '未提供' || course['学分'] == null
                      ? null
                      : Text('${course['学分']} 学分'),
                ),
              ],
            ],
          ),
          quiet: true,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(label),
    trailing: Text(value, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _ProgressCredits extends StatelessWidget {
  const _ProgressCredits(this.fields);
  final _Fields fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final earned = fields['已获学分'] ?? '未提供';
    final required = fields['要求学分'] ?? '未提供';
    final left = fields['还需学分'] ?? '';
    final a = double.tryParse(earned), b = double.tryParse(required);
    final remaining = double.tryParse(left);
    final progress = a != null && b != null && b > 0
        ? (a / b).clamp(0.0, 1.0)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(fields['类别']!, style: theme.textTheme.titleMedium),
          if (fields['课程属性'] case final property?) Text(property),
          const SizedBox(height: 4),
          Text('已获 $earned · 要求 $required', style: theme.textTheme.bodyMedium),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
          if (remaining != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                remaining == 0 ? '已完成' : '还需 $left 学分',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
