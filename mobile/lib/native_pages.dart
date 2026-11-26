import 'archive_motion.dart';
import 'blog_surface.dart';
import 'package:flutter/material.dart';
import 'article_reader.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'academic.dart';
import 'countdown.dart';
import 'local_academic.dart';
import 'dorm.dart';
import 'wiki_page.dart';
import 'wiki_motion.dart';

Future<void> openNative(
  BuildContext context,
  AcademicStore store,
  String path,
  String title, {
  required ValueChanged<WikiTab> selectTab,
  WikiPageMark? mark,
}) async {
  final uri = Uri.parse(path);
  if (uri.hasScheme && uri.scheme != 'https' && uri.scheme != 'http') return;
  if ((uri.hasScheme && uri.host != 'wiki.wustacm.com') ||
      uri.path.startsWith('/files/')) {
    final url = Uri.parse(
      'https://wiki.wustacm.com',
    ).resolveUri(uri).toString();
    final ok = await platform.invokeMethod<bool>('external', url);
    if (ok != true && context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手机上没有能打开此链接的应用。')));
    return;
  }
  final route = uri.path.replaceFirst(RegExp(r'/$'), '');
  final p = route == '/study/clubs' ? '/coder' : route;
  final tab = const {
    '': WikiTab.home,
    '/study/curriculum': WikiTab.schedule,
    '/study/calendar': WikiTab.schedule,
    '/articles': WikiTab.campus,
  }[p];
  if (tab != null) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    selectTab(tab);
    return;
  }
  final resource = const {
    '/study/exams': 'exams',
    '/study/credits': 'credits',
    '/study/student': 'student',
    '/services/notices': 'notices',
    '/services/library': 'library',
    '/services/shuttle': 'shuttle',
    '/services/second-class': 'second-class',
    '/services/laundry': 'laundry-shops',
    '/services/training-plan': 'training-plan',
    '/services/captures': 'raw-schedule',
  }[p];
  final page = resource != null
      ? FoundationResourcePage(store, resource, title, mark: mark)
      : p == '/study/grades'
      ? AcademicQuery(store, 'grades', mark: mark)
      : p == '/tools/gpa' || p == '/study/gpa'
      ? AcademicQuery(
          store,
          'gpa',
          mark: mark,
          manualGpa: (_) =>
              NativePage(store, p, '从零开始计算', selectTab: selectTab),
        )
      : p == '/tools/countdown'
      ? CountdownPage(mark: mark, store: store)
      : NativePage(store, p, title, selectTab: selectTab, mark: mark);
  if (context.mounted)
    await Navigator.of(context).push(
      WikiRoute(
        page,
        MediaQuery.disableAnimationsOf(context),
        hasSticker: mark != null,
      ),
    );
}

class NativePage extends StatefulWidget {
  final AcademicStore store;
  final String path, title;
  final WikiPageMark? mark;
  final ValueChanged<WikiTab> selectTab;
  const NativePage(
    this.store,
    this.path,
    this.title, {
    required this.selectTab,
    this.mark,
    super.key,
  });
  @override
  State<NativePage> createState() => _NativeState();
}

class _NativeState extends State<NativePage>
    with SingleTickerProviderStateMixin {
  String query = '', year = '2025', level = '';
  final searchText = TextEditingController();
  final rows = [
    ['', ''],
  ];
  final map = MapController();
  late final AnimationController pan;
  @override
  void initState() {
    super.initState();
    pan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(moveCamera);
  }

  LatLng panFrom = const LatLng(0, 0), panTo = const LatLng(0, 0);
  double fromZoom = 14, toZoom = 14;
  void moveCamera() {
    final t = Curves.easeOutCubic.transform(pan.value);
    map.move(
      LatLng(
        panFrom.latitude + (panTo.latitude - panFrom.latitude) * t,
        panFrom.longitude + (panTo.longitude - panFrom.longitude) * t,
      ),
      fromZoom + (toZoom - fromZoom) * t,
    );
  }

  int place = 0;
  @override
  void dispose() {
    pan.dispose();
    searchText.dispose();
    map.dispose();
    super.dispose();
  }

  void open(String path, String title) => openNative(
    context,
    widget.store,
    path,
    title,
    selectTab: widget.selectTab,
  );
  Widget list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: children);
  Widget search(String hint) => TextField(
    controller: searchText,
    decoration: InputDecoration(
      prefixIcon: const Icon(Icons.search),
      labelText: hint,
      suffixIcon: searchText.text.isEmpty
          ? null
          : IconButton(
              tooltip: '清空搜索',
              icon: const Icon(Icons.close),
              onPressed: () {
                searchText.clear();
                setState(() => query = '');
              },
            ),
    ),
    onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
  );
  Widget select(
    String value,
    Map<String, String> items,
    ValueChanged<String> change,
  ) => Material(
    clipBehavior: Clip.antiAlias,
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(
            Icons.expand_more_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          selectedItemBuilder: (_) => [
            for (final label in items.values)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: [
            for (final e in items.entries)
              DropdownMenuItem(
                value: e.key,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (e.key == value) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null)
              setState(() {
                change(v);
              });
          },
        ),
      ),
    ),
  );
  bool matches(Object? value) => value.toString().toLowerCase().contains(query);
  Future<void> changeCampus(String value) async {
    try {
      await widget.store.saveCampus(value);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('本次作息已切换，未能保存校区偏好。')));
    }
  }

  Widget times(Json d) {
    final campus = widget.store.campus;
    final times = d['times'][campus] as List;
    final theme = Theme.of(context);
    final groups = <String, List<int>>{};
    for (final (index, row) in times.indexed) {
      final hour = int.parse(row[0].toString().split(':').first);
      final period = hour < 12
          ? '上午'
          : hour < 18
          ? '下午'
          : '晚上';
      (groups[period] ??= []).add(index);
    }
    return list([
      select(campus, {'huangjiahu': '黄家湖校区', 'qingshan': '青山校区'}, changeCampus),
      const SizedBox(height: 12),
      ContentReveal.sequence(
        Column(
          children: [
            for (final group in groups.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BlogPanel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        group.key,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final i in group.value) ...[
                        if (i != group.value.first) const Divider(height: 1),
                        ArchivePart(
                          start: .055 * i.clamp(0, 6),
                          end: .55 + .07 * i.clamp(0, 6),
                          axis: ArchiveRevealAxis.vertical,
                          travel: const Offset(0, 6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(child: Text('第 ${i + 1} 节')),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    '${times[i][0]} — ${times[i][1]}',
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  quiet: true,
                ),
              ),
          ],
        ),
        revision: campus,
      ),
    ]);
  }

  Widget gpa() {
    double total = 0, weighted = 0;
    bool valid = true;
    for (final r in rows) {
      if (r.every((v) => v.trim().isEmpty)) continue;
      final nums = r
          .map(
            (v) => RegExp(r'^\d+(?:\.\d+)?$').hasMatch(v.trim())
                ? double.tryParse(v)
                : null,
          )
          .toList();
      final c = nums.first, p = nums.last;
      if (c == null || p == null || !c.isFinite || !p.isFinite || c <= 0) {
        valid = false;
        continue;
      }
      total += c;
      weighted += c * p;
    }
    return list([
      ContentReveal.grouped(
        BlogPanel(
          ArchivePart(
            axis: ArchiveRevealAxis.vertical,
            travel: const Offset(0, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('加权平均绩点'),
                const SizedBox(height: 6),
                Text(
                  valid && total > 0
                      ? (weighted / total).toStringAsFixed(2)
                      : '—',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: blogTint(context, 266),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!valid) const Text('请补全学分和课程绩点。'),
              ],
            ),
          ),
          hue: 266,
        ),
        revision: (
          valid,
          total == 0 ? null : (weighted / total).toStringAsFixed(2),
        ),
      ),
      const SizedBox(height: 16),
      const Text('手动录入', style: TextStyle(fontWeight: FontWeight.w700)),
      AnimatedSize(
        alignment: Alignment.topCenter,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 260),
        reverseDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: Column(
          children: [
            for (final r in rows)
              ContentReveal(
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      for (int j = 0; j < 2; j++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextFormField(
                              initialValue: r[j],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: j == 0 ? '学分' : '课程绩点',
                              ),
                              onChanged: (v) => setState(() => r[j] = v),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: '移除课程',
                        onPressed: () => setState(() => rows.remove(r)),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
                key: ObjectKey(r),
              ),
          ],
        ),
      ),
      TextButton.icon(
        onPressed: () => setState(() => rows.add(['', ''])),
        icon: const Icon(Icons.add),
        label: const Text('添加课程'),
      ),
    ]);
  }

  Widget directory(Json d) {
    final contests =
            widget.path == '/tools/contests' || widget.path == '/study/contest',
        nav = widget.path == '/navigation';
    final List<Json> records =
        (contests
                ? d['contests'][year]
                : nav
                ? [
                    for (final g in d['navigation'])
                      for (final e in g['links'])
                        <String, dynamic>{...e as Json, 'category': g['title']},
                  ]
                : d['curricula']['records'])
            .cast<Json>();
    final visible = records
        .where(
          (r) => matches(
            contests
                ? [r['name'], r['organizers'], r['host'], r['audience']]
                : nav
                ? [r['title'], r['description'], r['category'], r['keywords']]
                : [r['program'], r['college'], r['level']],
          ),
        )
        .where((r) => !contests || level.isEmpty || r['level'] == level)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              search(
                contests
                    ? '竞赛名称或主办单位'
                    : nav
                    ? '搜索导航'
                    : '搜索专业或学院',
              ),
              if (contests) const SizedBox(height: 8),
              if (contests)
                Row(
                  children: [
                    Expanded(
                      child: select(
                        year,
                        {'2025': '2025 年目录', '2024': '2024 年目录'},
                        (v) {
                          year = v;
                          level = '';
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: select(level, {
                        '': '全部类别',
                        for (final r in records) r['level']: '${r['level']} 类',
                      }, (v) => level = v),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: ContentReveal(
              Text(
                '共 ${visible.length} 项',
                style: TextStyle(
                  color: blogTint(context, 220),
                  fontWeight: FontWeight.w600,
                ),
              ),
              axis: ArchiveRevealAxis.horizontal,
              revision: visible.length,
            ),
          ),
        ),
        Expanded(
          child: ContentReveal.sequence(
            visible.isEmpty
                ? Center(
                    child: ArchivePart.staggered(
                      0,
                      child: const Text('没有符合条件的条目'),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final r = visible[i];
                      if (contests)
                        return ArchivePart.staggered(
                          i,
                          child: BlogPanel(
                            ListTile(
                              title: Text(
                                r['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                (r['organizers'] as List).join('、'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                '${r['level']} 类',
                                style: TextStyle(color: blogTint(context, 32)),
                              ),
                              onTap: () => showWikiSheet<void>(
                                context,
                                (sheetContext) => SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        r['name'],
                                        style: Theme.of(
                                          sheetContext,
                                        ).textTheme.titleLarge,
                                      ),
                                      for (final (label, value) in [
                                        ('类别', '${r['level']} 类'),
                                        (
                                          '主办单位',
                                          (r['organizers'] as List).join('、'),
                                        ),
                                        ('承办单位', r['host']),
                                        ('参赛对象', r['audience']),
                                      ])
                                        if (value is String &&
                                            value.trim().isNotEmpty)
                                          ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(label),
                                            subtitle: SelectableText(value),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            hue: 32,
                            quiet: true,
                          ),
                        );
                      if (nav)
                        return ArchivePart.staggered(
                          i,
                          child: BlogPanel(
                            ListTile(
                              leading: const BlogIcon(
                                Icons.explore_outlined,
                                hue: 178,
                              ),
                              title: Text(r['title']),
                              subtitle: Text(
                                [
                                  r['category'],
                                  r['description'],
                                ].whereType<String>().join(' · '),
                              ),
                              trailing: Icon(
                                Uri.tryParse(r['url'])?.hasScheme == true
                                    ? Icons.north_east_rounded
                                    : Icons.chevron_right_rounded,
                                size: 17,
                              ),
                              onTap: () => open(r['url'], r['title']),
                            ),
                            padding: EdgeInsets.zero,
                            hue: 178,
                          ),
                        );
                      return ArchivePart.staggered(
                        i,
                        child: BlogPanel(
                          ExpansionTile(
                            key: PageStorageKey((
                              r['college'],
                              r['program'],
                              r['level'],
                            )),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: blogTint(
                              context,
                              265,
                            ).withValues(alpha: .07),
                            textColor: blogTint(context, 265),
                            iconColor: blogTint(context, 265),
                            expansionAnimationStyle:
                                MediaQuery.disableAnimationsOf(context)
                                ? AnimationStyle.noAnimation
                                : const AnimationStyle(
                                    duration: Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    reverseCurve: Curves.easeInCubic,
                                  ),
                            leading: const BlogIcon(
                              Icons.school_outlined,
                              hue: 265,
                            ),
                            title: Text(r['program']),
                            subtitle: Text('${r['college']} · ${r['level']}'),
                            children: [
                              ListTile(
                                title: Text(r['status'] ?? ''),
                                trailing: (r['note'] ?? '').isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: '来源说明',
                                        icon: const Icon(
                                          Icons.info_outline,
                                          size: 20,
                                        ),
                                        onPressed: () => showWikiDialog<void>(
                                          context,
                                          (ctx) => AlertDialog(
                                            title: const Text('来源说明'),
                                            content: SingleChildScrollView(
                                              child: SelectableText(r['note']),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text('关闭'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),
                              for (final doc in r['documents'])
                                ListTile(
                                  leading: const Icon(
                                    Icons.description_outlined,
                                  ),
                                  title: Text(doc['title']),
                                  onTap: () => open(doc['url'], doc['title']),
                                ),
                              for (final s in r['sources'])
                                ListTile(
                                  title: const Text('学院来源'),
                                  subtitle: Text(Uri.tryParse(s)?.host ?? s),
                                  trailing: const Icon(
                                    Icons.open_in_new,
                                    size: 18,
                                  ),
                                  onTap: () => open(s, '学院来源'),
                                ),
                            ],
                          ),
                          padding: EdgeInsets.zero,
                          quiet: true,
                          hue: 265,
                        ),
                      );
                    },
                  ),
            revision: (year, level, query),
          ),
        ),
      ],
    );
  }

  Widget nearby(Json d) {
    final ps = d['places'] as List;
    LatLng loc(dynamic p) => LatLng(p['coordinates'][1], p['coordinates'][0]);
    void choose(int i) {
      setState(() => place = i);
      pan.stop();
      panTo = loc(ps[i]);
      toZoom = (ps[i]['zoom'] as num).toDouble();
      if (MediaQuery.disableAnimationsOf(context)) {
        map.move(panTo, toZoom);
        return;
      }
      panFrom = map.camera.center;
      fromZoom = map.camera.zoom;
      pan.forward(from: 0);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: select('$place', {
            for (int i = 0; i < ps.length; i++) '$i': ps[i]['name'],
          }, (v) => choose(int.parse(v))),
        ),
        Expanded(
          child: FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: loc(ps[place]),
              initialZoom: 14,
              onPositionChanged: (_, gesture) {
                if (gesture && pan.isAnimating) pan.stop();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wustacm.wiki',
              ),
              MarkerLayer(
                markers: [
                  for (final i in [
                    ...Iterable<int>.generate(
                      ps.length,
                    ).where((i) => i != place),
                    place,
                  ])
                    Marker(
                      point: loc(ps[i]),
                      width: 40,
                      height: 40,
                      child: Semantics(
                        selected: i == place,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: ps[i]['name'],
                          onPressed: () => choose(i),
                          icon: AnimatedScale(
                            scale: i == place ? 1.18 : .94,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.surface,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  i == place
                                      ? Icons.place
                                      : Icons.place_outlined,
                                  size: 18,
                                  color: blogTint(
                                    context,
                                    i == place ? 178 : 220,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
          ),
        ),
        ContentReveal.grouped(
          BlogPanel(
            ListTile(
              leading: const BlogIcon(Icons.place_outlined, hue: 178),
              title: ArchivePart(
                start: .10,
                end: .78,
                travel: const Offset(-8, 0),
                child: Text(ps[place]['name']),
              ),
              subtitle: ArchivePart(
                start: .28,
                end: 1,
                axis: ArchiveRevealAxis.vertical,
                travel: const Offset(0, 5),
                child: Text('${ps[place]['area']} · ${ps[place]['category']}'),
              ),
            ),
            padding: EdgeInsets.zero,
            hue: 178,
          ),
          revision: place,
        ),
      ],
    );
  }

  Widget body(Json d) {
    switch (widget.path) {
      case '/tools/dorm':
        return const DormPage();
      case '/tools/times':
        return ListenableBuilder(
          listenable: widget.store,
          builder: (_, _) => times(d),
        );
      case '/tools/gpa':
      case '/study/gpa':
        return gpa();
      case '/tools/contests':
      case '/study/contest':
      case '/navigation':
      case '/study/status':
        return directory(d);
      case '/life/nearby':
        return nearby(d);
    }
    final path = widget.path == '/previews/example'
        ? '/blog-components'
        : widget.path;
    if (!d['articles'].containsKey(path))
      return const Center(child: Text('此条目暂无内容'));
    return ArticleReader(
      path: path,
      open: (url) {
        final uri = Uri.parse(url);
        open(url, d['articles'][uri.path]?['title'] ?? widget.title);
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: WikiPageTitle(widget.title, mark: widget.mark),
      actions: [
        if (widget.path == '/study/status')
          TextButton(
            onPressed: () => open('/services/training-plan', '我的培养方案'),
            child: const Text('我的培养方案'),
          ),
      ],
    ),
    body: SafeArea(
      child: FutureBuilder<Json>(
        future: nativeData,
        builder: (context, s) => s.hasData
            ? body(s.data!)
            : s.hasError
            ? const Center(child: Text('随包数据读取失败'))
            : const WikiSkeleton(),
      ),
    ),
  );
}
