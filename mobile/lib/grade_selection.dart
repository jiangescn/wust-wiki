import 'blog_surface.dart';
import 'archive_motion.dart';
import 'dart:convert';
import 'package:flutter/material.dart';

typedef RecordData = Map<String, dynamic>;
int? termOrder(String value) {
  final m = RegExp(
    r'^(\d{4})\s*[-–—/]\s*\d{4}\s*(?:学年)?\s*[-–—/ ]\s*(?:第)?([123一二三])(?:学期)?$',
  ).firstMatch(value.trim());
  if (m == null) return null;
  return int.parse(m[1]!) * 10 +
      ({'一': 1, '二': 2, '三': 3}[m[2]] ?? int.parse(m[2]!));
}

int? latestAttempt(List<RecordData> rows) {
  if (rows.length == 1) return 0;
  final terms = <int>[];
  for (final r in rows) {
    final makeup = (r['makeupTerm'] ?? '').toString().trim();
    final t = termOrder(
      makeup.isNotEmpty && !RegExp(r'^[-—–/]+$').hasMatch(makeup)
          ? makeup
          : r['term'] ?? '',
    );
    if (t == null) return null;
    terms.add(t);
  }
  final latest = terms.reduce((a, b) => a > b ? a : b);
  final candidates = [
    for (int i = 0; i < terms.length; i++)
      if (terms[i] == latest) i,
  ];
  final repeats = candidates
      .where((i) => RegExp('重修|补考|补修').hasMatch(rows[i]['attempt'] ?? ''))
      .toList();
  final pool = repeats.isEmpty ? candidates : repeats;
  return pool.every((i) => jsonEncode(rows[i]) == jsonEncode(rows[pool.first]))
      ? pool.first
      : null;
}

class GradeSelection extends StatefulWidget {
  final List<RecordData> courses;
  final WikiPageMark? mark;
  final VoidCallback? onManual;
  const GradeSelection(this.courses, {this.mark, this.onManual, super.key});
  @override
  State<GradeSelection> createState() => _GradeState();
}

class _GradeState extends State<GradeSelection> {
  final groups = <String, List<RecordData>>{}, chosen = <String, int>{};
  @override
  void initState() {
    super.initState();
    for (final (i, r) in widget.courses.indexed) {
      final code = (r['code'] ?? '').toString().trim();
      (groups[code.isEmpty ? 'row-$i' : 'code-$code'] ??= []).add(r);
    }
    for (final e in groups.entries) {
      final i = latestAttempt(e.value);
      if (i != null) chosen[e.key] = i;
    }
  }

  @override
  Widget build(BuildContext context) {
    double sum = 0, credits = 0;
    int skipped = 0;
    for (final e in chosen.entries) {
      final r = groups[e.key]![e.value];
      final c = double.tryParse(r['credit'] ?? ''),
          p = double.tryParse(r['point'] ?? '');
      if (c == null ||
          p == null ||
          !c.isFinite ||
          !p.isFinite ||
          c <= 0 ||
          p < 0) {
        skipped++;
        continue;
      }
      sum += c * p;
      credits += c;
    }
    final scheme = Theme.of(context).colorScheme;
    final entries = groups.entries.toList();
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return Scaffold(
      appBar: AppBar(title: WikiPageTitle('绩点计算', mark: widget.mark)),
      bottomNavigationBar: widget.onManual == null
          ? null
          : ManualGpaFooter(onPressed: widget.onManual!),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ContentReveal.grouped(
              BlogPanel(
                ListTile(
                  leading: const BlogIcon(Icons.calculate_outlined, hue: 266),
                  title: ArchivePart(
                    travel: const Offset(-8, 0),
                    child: Text(
                      credits == 0
                          ? '请选择可计入的课程'
                          : '加权平均绩点  ${(sum / credits).toStringAsFixed(2)}',
                    ),
                  ),
                  subtitle: ArchivePart(
                    start: .25,
                    end: 1,
                    axis: ArchiveRevealAxis.vertical,
                    travel: const Offset(0, 5),
                    child: Text(
                      '选中 ${chosen.length} 门 · $credits 学分' +
                          (skipped > 0 ? ' · $skipped 条缺少有效学分或绩点' : ''),
                    ),
                  ),
                ),
                hue: 266,
                padding: EdgeInsets.zero,
              ),
              revision: (sum, credits, chosen.length),
            ),
          ),
          Expanded(
            child: ContentReveal.sequence(
              ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final e = entries[index];
                  return ArchivePart.staggered(
                    index,
                    child: Material(
                      color: scheme.surface,
                      shape: shape.copyWith(
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final (i, r) in e.value.indexed) ...[
                            if (i > 0)
                              Divider(height: 1, color: scheme.outlineVariant),
                            CheckboxListTile(
                              value: chosen[e.key] == i,
                              selected: chosen[e.key] == i,
                              selectedTileColor: scheme.primary.withValues(
                                alpha: .09,
                              ),
                              activeColor: scheme.primary,
                              checkColor: scheme.onPrimary,
                              onChanged: (yes) => setState(() {
                                if (yes == true) {
                                  chosen[e.key] = i;
                                } else {
                                  chosen.remove(e.key);
                                }
                              }),
                              title: Text(
                                r['name'] ?? '',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: chosen[e.key] == i
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                      fontWeight: chosen[e.key] == i
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                              ),
                              subtitle: Text(
                                [
                                      r['term'],
                                      r['attempt'],
                                      '学分 ${r['credit']} · 绩点 ${r['point']}',
                                    ]
                                    .whereType<String>()
                                    .where((v) => v.isNotEmpty)
                                    .join(' · '),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ManualGpaFooter extends StatelessWidget {
  const ManualGpaFooter({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('从零开始计算'),
      ),
    ),
  );
}
