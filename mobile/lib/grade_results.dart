import 'package:flutter/material.dart';

import 'academic.dart';
import 'archive_motion.dart';
import 'blog_surface.dart';

class GradeResults extends StatefulWidget {
  const GradeResults(this.courses, {super.key});

  final List<Json> courses;

  @override
  State<GradeResults> createState() => _GradeResultsState();
}

class _GradeResultsState extends State<GradeResults> {
  final _search = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final query = _search.text.trim().toLowerCase();
    final terms = <String>{};
    final groups = <String, List<Json>>{};
    var count = 0;
    for (final course in widget.courses) {
      final term = _value(course, 'term');
      if (term.isNotEmpty) terms.add(term);
      if (_term.isNotEmpty && term != _term) continue;
      final nameAndCode = '${_value(course, 'name')} ${_value(course, 'code')}';
      if (!nameAndCode.toLowerCase().contains(query)) continue;
      (groups[term] ??= []).add(course);
      count++;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: '搜索课程或编号',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: terms.contains(_term) ? _term : '',
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(14),
                        icon: const Icon(Icons.expand_more_rounded),
                        items: [
                          for (final term in ['', ...terms])
                            DropdownMenuItem(
                              value: term,
                              child: Text(
                                term.isEmpty ? '全部学期' : term,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _term = value ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '$count 门课程',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ContentReveal.sequence(
            groups.isEmpty
                ? Center(
                    child: Text(widget.courses.isEmpty ? '暂无成绩' : '没有符合条件的成绩'),
                  )
                : CustomScrollView(
                    key: ValueKey((query, _term)),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      for (final group in groups.entries) ...[
                        if (_term.isEmpty && group.key.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  group.key,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          sliver: SliverList.builder(
                            itemCount: group.value.length,
                            itemBuilder: (_, index) => ArchivePart.staggered(
                              index,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _GradeCard(group.value[index]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
            revision: (query, _term),
          ),
        ),
      ],
    );
  }
}

String _value(Json course, String key) => course[key]?.toString().trim() ?? '';

class _GradeCard extends StatelessWidget {
  const _GradeCard(this.course);

  final Json course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final details = [
      for (final key in ['code', 'nature', 'assessment', 'attempt', 'mark'])
        if (_value(course, key).isNotEmpty) _value(course, key),
    ];
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _value(course, 'name'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (label, key) in [
              ('成绩', 'score'),
              ('学分', 'credit'),
              ('绩点', 'point'),
            ])
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _value(course, key).isEmpty ? '—' : _value(course, key),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: key == 'score'
                            ? colors.onPrimaryContainer
                            : colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
    return BlogPanel(
      details.isEmpty
          ? Padding(padding: const EdgeInsets.all(14), child: header)
          : ExpansionTile(
              key: PageStorageKey(ObjectKey(course)),
              shape: shape,
              collapsedShape: shape,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              expandedAlignment: AlignmentDirectional.centerStart.resolve(
                Directionality.of(context),
              ),
              expansionAnimationStyle: MediaQuery.disableAnimationsOf(context)
                  ? AnimationStyle.noAnimation
                  : null,
              title: header,
              children: [
                const Divider(height: 16),
                Text(
                  details.join(' · '),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
      padding: EdgeInsets.zero,
      quiet: true,
    );
  }
}
