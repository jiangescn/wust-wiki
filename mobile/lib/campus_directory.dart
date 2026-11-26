import 'package:flutter/material.dart';

import 'academic.dart';
import 'delayed_loading.dart';
import 'archive_motion.dart';
import 'blog_surface.dart';
import 'wiki_page.dart';

enum _Topic {
  campus('校园', '校园指南', '/campus'),
  study('学习', '学业服务', '/study'),
  life('生活', '校园生活', '/life'),
  coder('Coder', '技术交流', '/coder'),
  about('关于', '站点资料', '');

  const _Topic(this.label, this.heading, this.path);
  final String label, heading, path;

  bool includes(String route) => this == about
      ? !_Topic.values.any((topic) => topic != about && topic.includes(route))
      : route == path || route.startsWith('$path/');
}

class CampusDirectory extends StatefulWidget {
  const CampusDirectory({
    required this.controller,
    required this.onOpen,
    super.key,
  });

  final ScrollController controller;
  final ValueChanged<Entry> onOpen;

  @override
  State<CampusDirectory> createState() => _CampusDirectoryState();
}

class _CampusDirectoryState extends State<CampusDirectory> {
  _Topic? selected;

  Entry entry(String path, String title) => (
    path: path,
    label: title,
    icon: switch (path) {
      '/study/curriculum' => Icons.calendar_month_outlined,
      '/study/grades' => Icons.bar_chart_outlined,
      '/study/contest' => Icons.emoji_events_outlined,
      '/life/nearby' => Icons.map_outlined,
      _ => Icons.article_outlined,
    },
  );

  void select(_Topic? topic) {
    if (topic == selected) return;
    if (widget.controller.hasClients) widget.controller.jumpTo(0);
    setState(() => selected = topic);
  }

  Widget cards(List<Json> items) => LayoutBuilder(
    builder: (context, bounds) {
      const gap = 10.0;
      final columns =
          bounds.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(16) > 22
          ? 1
          : bounds.maxWidth >= 620
          ? 3
          : 2;
      final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (index, item) in items.indexed)
            SizedBox(
              width: width,
              child: ArchivePart.staggered(
                index,
                child: _CampusCard(
                  entry: entry(item['to'], item['title']),
                  description: item['description'],
                  illustration: item['icon'],
                  onTap: () => widget.onOpen(entry(item['to'], item['title'])),
                ),
              ),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topics = selected == null
        ? _Topic.values.where((topic) => topic != _Topic.about)
        : [selected!];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 6,
              children: [
                for (final topic in [null, ..._Topic.values])
                  ChoiceChip(
                    label: Text(topic?.label ?? '概览'),
                    selected: selected == topic,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 5),
                    selectedColor: colors.primaryContainer,
                    backgroundColor: colors.surface,
                    onSelected: (_) => select(topic),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<Json>(
            future: nativeData,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: snapshot.hasError
                      ? const Text('校园目录暂时无法读取')
                      : const DelayedLoading(
                          child: CircularProgressIndicator(),
                        ),
                );
              }
              final data = snapshot.data!;
              final featured = (data['homeEntries'] as List).cast<Json>();
              final featuredPaths = featured.map((item) => item['to']).toSet();
              final extra = selected == null
                  ? const <MapEntry<String, dynamic>>[]
                  : (data['articles'] as Json).entries.where((article) {
                      return selected!.includes(article.key) &&
                          !featuredPaths.contains(article.key) &&
                          article.key != '/navigation' &&
                          article.key != '/study/clubs';
                    });
              return ContentReveal.sequence(
                ListView(
                  controller: widget.controller,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                  children: [
                    for (final topic in topics)
                      if (topic != _Topic.about) ...[
                        _Heading(topic.heading),
                        cards(
                          featured
                              .where((item) => topic.includes(item['to']))
                              .toList(),
                        ),
                      ],
                    if (extra.isNotEmpty) ...[
                      _Heading(
                        selected == _Topic.about ? selected!.heading : '更多文章',
                      ),
                      Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final (index, article) in extra.indexed) ...[
                              if (index != 0)
                                const Divider(height: 1, indent: 16),
                              ArchivePart.staggered(
                                index,
                                child: WikiPress(
                                  onTap: () => widget.onOpen(
                                    entry(article.key, article.value['title']),
                                  ),
                                  child: ListTile(
                                    leading: WikiPageMark(
                                      article.key,
                                      Icons.article_outlined,
                                    ),
                                    title: Text(article.value['title']),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                revision: selected,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 10),
    child: Semantics(
      header: true,
      child: ArchivePart(
        travel: const Offset(-8, 0),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

class _CampusCard extends StatelessWidget {
  const _CampusCard({
    required this.entry,
    required this.description,
    required this.illustration,
    required this.onTap,
  });

  final Entry entry;
  final String description, illustration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: WikiPress(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              PositionedDirectional(
                end: 5,
                bottom: -12,
                child: ExcludeSemantics(
                  child: WikiPageMark(
                    entry.path,
                    entry.icon,
                    face: Opacity(
                      opacity: theme.brightness == Brightness.dark ? .13 : .18,
                      child: Text(
                        illustration,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(fontSize: 59),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
