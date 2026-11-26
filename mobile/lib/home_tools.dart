import 'package:flutter/material.dart';

import 'academic.dart' show AcademicStore;
import 'archive_motion.dart';
import 'blog_surface.dart';
import 'wiki_page.dart';

const _groups = <String, List<Entry>>{
  '学习': [
    (label: '绩点计算', path: '/tools/gpa', icon: Icons.calculate_outlined),
    (label: '成绩查询', path: '/study/grades', icon: Icons.bar_chart_outlined),
    (label: '主修进度', path: '/study/credits', icon: Icons.fact_check_outlined),
    (label: '培养方案', path: '/study/status', icon: Icons.school_outlined),
    (label: '竞赛查询', path: '/tools/contests', icon: Icons.emoji_events_outlined),
    (label: '上课时间', path: '/tools/times', icon: Icons.schedule_outlined),
    (
      label: '第二课堂',
      path: '/services/second-class',
      icon: Icons.volunteer_activism_outlined,
    ),
    (
      label: '图书馆',
      path: '/services/library',
      icon: Icons.local_library_outlined,
    ),
  ],
  '生活': [
    (label: '查宿舍', path: '/tools/dorm', icon: Icons.apartment_outlined),
    (
      label: '洗衣机',
      path: '/services/laundry',
      icon: Icons.local_laundry_service_outlined,
    ),
    (
      label: '学校通知',
      path: '/services/notices',
      icon: Icons.notifications_outlined,
    ),
    (
      label: '校车',
      path: '/services/shuttle',
      icon: Icons.directions_bus_outlined,
    ),
  ],
};

typedef _OpenTool = void Function(Entry entry, WikiPageMark source);

class HomeTools extends StatelessWidget {
  const HomeTools({
    required this.store,
    required this.open,
    required this.mark,
    super.key,
  });

  final AcademicStore store;
  final _OpenTool open;
  final WikiPageMark Function(Entry) mark;

  void _openDirectory(BuildContext context) => Navigator.of(context).push(
    WikiRoute(
      _ToolDirectory(store: store, open: open, mark: mark),
      MediaQuery.disableAnimationsOf(context),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final theme = Theme.of(context);
      final pinned = store.pinnedHomeTools.toSet();
      List<Entry> ordered(List<Entry> entries) {
        final byPath = {for (final entry in entries) entry.path: entry};
        return [
          for (final path in pinned)
            if (byPath[path] case final entry?) entry,
          for (final entry in entries)
            if (!pinned.contains(entry.path)) entry,
        ];
      }

      final columns =
          MediaQuery.textScalerOf(context).scale(15) > 21 ||
              bounds.maxWidth < 300
          ? 1
          : bounds.maxWidth >= 680
          ? 4
          : 2;
      const gap = 8.0;
      final width = (bounds.maxWidth - (columns - 1) * gap) / columns - .01;
      Widget tiles(List<Entry> entries) => ContentReveal.sequence(
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (index, entry) in entries.indexed)
              SizedBox(
                width: width,
                child: ArchivePart.staggered(
                  index,
                  child: Material(
                    color: Color.alphaBlend(
                      blogTint(context, mark(entry).hue).withValues(alpha: .07),
                      theme.colorScheme.surface,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: WikiPress(
                      onTap: () => open(entry, mark(entry)),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 62),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              mark(entry),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.label,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (width >= 174)
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, group) in _groups.entries.indexed) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: ArchivePart(
                child: Row(
                  children: [
                    Expanded(child: _heading(context, group.key)),
                    if (index == 0)
                      TextButton.icon(
                        onPressed: () => _openDirectory(context),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        label: const Text('更多工具'),
                      ),
                  ],
                ),
              ),
            ),
            tiles(ordered(group.value)),
          ],
        ],
      );
    },
  );
}

Widget _heading(BuildContext context, String title) => Semantics(
  header: true,
  child: Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  ),
);

class _ToolDirectory extends StatelessWidget {
  const _ToolDirectory({
    required this.store,
    required this.open,
    required this.mark,
  });

  final AcademicStore store;
  final _OpenTool open;
  final WikiPageMark Function(Entry) mark;

  Widget _toolRow(BuildContext context, Entry entry) {
    final base = mark(entry);
    final source = WikiPageMark(
      'tool-directory:${base.path}',
      base.icon,
      hue: base.hue,
    );
    final pinned = store.pinnedHomeTools.contains(entry.path);
    return WikiPress(
      onTap: () => open(entry, source),
      child: ListTile(
        minTileHeight: 52,
        leading: source,
        title: Text(entry.label),
        trailing: IconButton(
          isSelected: pinned,
          color: pinned
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : null,
          tooltip: pinned ? '取消固定${entry.label}' : '固定${entry.label}到首页',
          icon: const Icon(Icons.push_pin_outlined, size: 21),
          selectedIcon: const Icon(Icons.push_pin, size: 21),
          onPressed: store.initialized
              ? () => store.setHomeToolPinned(entry.path, !pinned)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const WikiPageTitle('更多工具')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          children: [
            for (final group in _groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: ArchivePart(child: _heading(context, group.key)),
              ),
              BlogPanel(
                ContentReveal.sequence(
                  Column(
                    children: [
                      for (final (index, entry) in group.value.indexed) ...[
                        if (index > 0) const Divider(height: 1, indent: 56),
                        ArchivePart.staggered(
                          index,
                          child: _toolRow(context, entry),
                        ),
                      ],
                    ],
                  ),
                ),
                padding: EdgeInsets.zero,
                quiet: true,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
