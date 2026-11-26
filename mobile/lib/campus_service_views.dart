import 'package:flutter/material.dart';

import 'academic.dart' show Json;
import 'archive_motion.dart';
import 'blog_surface.dart';

String _label(Object? value) =>
    value is String || value is num ? '$value'.trim() : '';

class LibraryCirculation extends StatefulWidget {
  const LibraryCirculation({
    required this.current,
    required this.dueSoon,
    required this.onMore,
    super.key,
  });

  final Json current, dueSoon;
  final ValueChanged<bool> onMore;

  @override
  State<LibraryCirculation> createState() => _LibraryCirculationState();
}

class _LibraryCirculationState extends State<LibraryCirculation> {
  bool _dueOnly = false;

  @override
  Widget build(BuildContext context) {
    final page = _dueOnly ? widget.dueSoon : widget.current;
    final items = (page['items'] as List).whereType<Json>().toList();
    final more =
        page['currentPage'] is int &&
        page['totalPage'] is int &&
        (page['currentPage'] as int) < (page['totalPage'] as int);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text('借阅中 ${widget.current['total']}'),
            ),
            ButtonSegment(
              value: true,
              label: Text('即将到期 ${widget.dueSoon['total']}'),
            ),
          ],
          selected: {_dueOnly},
          onSelectionChanged: (selected) =>
              setState(() => _dueOnly = selected.single),
        ),
        const SizedBox(height: 12),
        LibraryLoanList(items, empty: _dueOnly ? '暂无即将到期的图书' : '暂无借阅'),
        if (more)
          TextButton(
            onPressed: () => widget.onMore(_dueOnly),
            child: const Text('查看全部'),
          ),
      ],
    );
  }
}

class LibraryLoanList extends StatelessWidget {
  const LibraryLoanList(this.items, {required this.empty, super.key});

  final List<Json> items;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ContentReveal.sequence(
      BlogPanel(
        items.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    empty,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              )
            : Column(
                children: [
                  for (final (index, book) in items.indexed) ...[
                    if (index > 0) const Divider(height: 1),
                    ArchivePart.staggered(
                      index,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        title: Text(
                          _label(book['title']).isEmpty
                              ? '未命名图书'
                              : _label(book['title']),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_label(book['dueDate']).isNotEmpty)
                              Text(
                                '应还 ${_label(book['dueDate'])}',
                                style: TextStyle(
                                  color: colors.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (_label(book['author']).isNotEmpty ||
                                _label(book['location']).isNotEmpty)
                              Text(
                                [
                                  if (_label(book['author']).isNotEmpty)
                                    _label(book['author']),
                                  if (_label(book['location']).isNotEmpty)
                                    _label(book['location']),
                                ].join(' · '),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        quiet: true,
        padding: EdgeInsets.zero,
      ),
      revision: (empty, items.length, items.firstOrNull?['title']),
    );
  }
}

class LibraryAccount extends StatelessWidget {
  const LibraryAccount(this.stats, {super.key});

  final Json stats;

  @override
  Widget build(BuildContext context) {
    const labels = {
      'loanCount': '当前借阅',
      'fineSum': '欠费',
      'requestCount': '我的请求',
      'booklistCount': '我的书单',
    };
    final entries = labels.entries
        .where((entry) => _label(stats[entry.key]).isNotEmpty)
        .toList();
    return BlogPanel(
      entries.isEmpty
          ? const Text('暂无账户概览')
          : Column(
              children: [
                for (final (index, entry) in entries.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    trailing: Text(_label(stats[entry.key])),
                  ),
                ],
              ],
            ),
      quiet: true,
    );
  }
}

class LaundryShops extends StatelessWidget {
  const LaundryShops(this.shops, {required this.onOpen, super.key});

  final List<Json> shops;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BlogPanel(
      shops.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: Text('附近暂无洗衣点'))
          : Column(
              children: [
                for (final (index, shop) in shops.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(_label(shop['name'])),
                    subtitle: shop['freeMachine'] == null
                        ? null
                        : Text(
                            '空闲 ${shop['freeMachine']} 台',
                            style: TextStyle(color: colors.onPrimaryContainer),
                          ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => onOpen(index),
                  ),
                ],
              ],
            ),
      padding: EdgeInsets.zero,
      quiet: true,
    );
  }
}

class LaundryMachines extends StatefulWidget {
  const LaundryMachines(
    this.devices, {
    required this.shopName,
    this.filter = '',
    this.onFilterChanged,
    super.key,
  });

  final List<Json> devices;
  final String shopName, filter;
  final ValueChanged<String>? onFilterChanged;

  @override
  State<LaundryMachines> createState() => _LaundryMachinesState();
}

class _LaundryMachinesState extends State<LaundryMachines> {
  late final _filter = TextEditingController(text: widget.filter);

  static String _normalize(String value) => value
      .replaceAll(RegExp(r'\s'), '')
      .replaceFirstMapped(RegExp(r'^([南北])楼'), (match) => match[1]!)
      .replaceAll(RegExp(r'[－—–]'), '-')
      .toLowerCase();

  void _filterChanged(String value) {
    setState(() {});
    widget.onFilterChanged?.call(value.trim());
  }

  void _selectFilter(String value) {
    _filter.text = value;
    FocusScope.of(context).unfocus();
    _filterChanged(value);
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final input = _normalize(_filter.text);
    final keyword = input.replaceFirst(RegExp(r'(?<=\d)[层楼]$'), '-');
    final devices = widget.devices
        .where((device) => _normalize(_label(device['name'])).contains(keyword))
        .toList();
    final wings = [
      for (final wing in ['南', '北'])
        if (input.startsWith(wing) ||
            widget.devices.any(
              (device) => _normalize(_label(device['name'])).startsWith(wing),
            ))
          '${wing}楼',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.shopName.isNotEmpty)
          Text(
            widget.shopName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          child: TextField(
            controller: _filter,
            onChanged: _filterChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索楼栋、楼层或机号',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: input.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空筛选',
                      onPressed: () => _selectFilter(''),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        if (wings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (label, value) in [
                  ('全部', ''),
                  for (final wing in wings) (wing, wing),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: input == _normalize(value),
                    onSelected: (_) => _selectFilter(value),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
          devices.isNotEmpty
              ? '${devices.length} 台空闲'
              : input.isEmpty
              ? '暂无空闲洗衣机'
              : '当前范围暂无空闲洗衣机',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colors.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (devices.isNotEmpty) ...[
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, bounds) {
              const gap = 8.0;
              final columns = MediaQuery.textScalerOf(context).scale(16) > 23
                  ? 1
                  : bounds.maxWidth >= 510
                  ? 3
                  : 2;
              final width =
                  (bounds.maxWidth - (columns - 1) * gap) / columns - .01;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final device in devices)
                    SizedBox(
                      width: width,
                      child: BlogPanel(
                        Text(
                          _label(device['name']),
                          style: theme.textTheme.titleMedium,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        quiet: true,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}
