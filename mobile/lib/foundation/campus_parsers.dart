import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

class CampusParseException implements Exception {
  const CampusParseException(this.code, this.message);
  final String code;
  final String message;
}

Never campusFail(String code, String message) =>
    throw CampusParseException(code, message);

Map<String, dynamic> campusMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    campusFail('invalid_response', '服务返回的数据结构无法识别。');
  }
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> campusRecords(Object? value) {
  if (value is! List) campusFail('invalid_response', '服务没有返回列表。');
  return value.map(campusMap).toList();
}

int campusInt(Object? value) {
  if (value is double && value.isFinite) {
    final integer = value.toInt();
    if (integer.toDouble() == value) return integer;
  }
  final result = value is int ? value : int.tryParse('$value');
  if (result == null) campusFail('invalid_response', '服务返回的整数无效。');
  return result;
}

String campusID(Object? value) {
  if ((value is String && value.isNotEmpty) || value is int) return '$value';
  campusFail('invalid_response', '服务没有返回有效标识。');
}

String campusDisplay(Object? value) => value == null
    ? '未提供'
    : value is Map || value is List
    ? jsonEncode(value)
    : '$value';

List<Map<String, String>> campusFields(Map<String, dynamic> value) => value
    .entries
    .map((e) => {'name': e.key, 'value': campusDisplay(e.value)})
    .toList();

const noticeSources = <String, Map<String, String>>{
  'campus': {'name': '校园通知', 'url': 'https://www.wust.edu.cn/index/tzgg.htm'},
  'academicAffairs': {
    'name': '教务通知',
    'url': 'https://jwc.wust.edu.cn/tzgg.htm',
  },
  'studentAffairs': {'name': '学工通知', 'url': 'https://xgc.wust.edu.cn/tzgg.htm'},
  'research': {'name': '科研通知', 'url': 'https://kjc.wust.edu.cn/tzgg.htm'},
  'graduateSchool': {
    'name': '研究生院通知',
    'url': 'https://ysxy.wust.edu.cn/tzgg.htm',
  },
};

bool campusURLHasUserInfo(String value) => RegExp(
  r'^(?:[a-z][a-z0-9+.-]*:)?//[^/?#]*@',
  caseSensitive: false,
).hasMatch(value.trim());

Uri? resolveNoticeURL(String value, Uri base) {
  if (value.trim().isEmpty) return null;
  if (campusURLHasUserInfo(value)) return null;
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null) return null;
  final uri = base.resolveUri(parsed);
  return ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty &&
          !uri.authority.contains('@')
      ? uri
      : null;
}

bool isUniversityURL(Uri uri) =>
    ['http', 'https'].contains(uri.scheme) &&
    uri.userInfo.isEmpty &&
    !uri.authority.contains('@') &&
    [80, 443].contains(uri.port) &&
    (uri.host == 'wust.edu.cn' || uri.host.endsWith('.wust.edu.cn'));

bool isNoticeArticle(Uri uri) =>
    RegExp(r'/info/[0-9]+/[0-9]+\.htm$').hasMatch(uri.path) ||
    (uri.path.endsWith('/info.jsp') &&
        uri.queryParametersAll['urltype']?.contains('news.NewsContentUrl') ==
            true);

bool isNoticeList(Uri uri, String source) {
  final definition = noticeSources[source];
  if (definition == null) return false;
  final base = Uri.parse(definition['url']!);
  final prefix = '${base.path.substring(0, base.path.length - 4)}/';
  return isUniversityURL(uri) &&
      uri.host == base.host &&
      !uri.hasQuery &&
      (uri.path == base.path ||
          (uri.path.startsWith(prefix) &&
              RegExp(
                r'^[0-9]+\.htm$',
              ).hasMatch(uri.path.substring(prefix.length))));
}

String? noticeDate(String text, {bool exact = false}) {
  if (exact && !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(text))
    return null;
  final match = RegExp(
    r'(?<![0-9])([0-9]{4})\s*[-年/.]\s*([0-9]{1,2})\s*[-月/.]\s*([0-9]{1,2})(?:日)?(?![0-9])',
  ).firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  if (year < 1 || date.year != year || date.month != month || date.day != day)
    return null;
  return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

class CampusNoticePolicy {
  CampusNoticePolicy({
    this.excluded = const ['1980-01-01'],
    this.earliest,
    this.latest,
  }) {
    if ([
          ...excluded,
          if (earliest != null) earliest!,
          if (latest != null) latest!,
        ].any((value) => noticeDate(value, exact: true) == null) ||
        (earliest != null &&
            latest != null &&
            earliest!.compareTo(latest!) > 0)) {
      campusFail('invalid_date_policy', '通知日期过滤配置无效。');
    }
  }
  final List<String> excluded;
  final String? earliest;
  final String? latest;
  bool allows(String value) =>
      !excluded.contains(value) &&
      (earliest == null || value.compareTo(earliest!) >= 0) &&
      (latest == null || value.compareTo(latest!) <= 0);
}

String _text(Element node) => node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
String _ownText(Element node) =>
    node.nodes.whereType<Text>().map((n) => n.text).join().trim();

String? _rowDate(Element row) {
  final year = row.querySelector('.news_date_yy');
  final monthDay = row.querySelector('.news_date_md');
  if (year != null && monthDay != null)
    return noticeDate('${_text(year)}-${_text(monthDay)}');
  for (final node in row.querySelectorAll('time, .time, .date')) {
    return noticeDate(
      node.attributes['datetime']?.isNotEmpty == true
          ? node.attributes['datetime']!
          : _text(node),
    );
  }
  for (final node in row.querySelectorAll('span')) {
    final text = _text(node);
    if (RegExp(
      r'^[\[【(]?\s*[0-9]{4}\s*[-年/.]\s*[0-9]{1,2}\s*[-月/.]\s*[0-9]{1,2}日?\s*[\]】)]?$',
    ).hasMatch(text)) {
      return noticeDate(text);
    }
  }
  return noticeDate(_ownText(row));
}

Map<String, dynamic> parseNoticeList(
  String source,
  Uri uri,
  String input, {
  CampusNoticePolicy? policy,
}) {
  if (!isNoticeList(uri, source))
    campusFail('unsupported_url', '通知列表地址不在支持范围内。');
  policy ??= CampusNoticePolicy();
  final document = html.parse(input);
  var rows = document.querySelectorAll(
    '.news_list_date li, .new_list .liebiao li',
  );
  if (rows.isEmpty) rows = document.querySelectorAll('li');
  final items = <Map<String, dynamic>>[];
  final seen = <String>{};
  var recognized = 0;
  var filtered = 0;
  for (final row in rows) {
    for (final link in row.querySelectorAll('a[href]')) {
      final url = resolveNoticeURL(link.attributes['href']!, uri);
      if (url == null || !isNoticeArticle(url)) continue;
      recognized++;
      final date = _rowDate(row);
      if (date == null || !policy.allows(date)) {
        filtered++;
        break;
      }
      if (!seen.add('$url')) break;
      final nested = link.querySelector('.news_title, .title, h3');
      final title = [
        link.attributes['title']?.trim() ?? '',
        _ownText(link),
        if (nested != null) _text(nested),
        _text(link),
      ].firstWhere((s) => s.isNotEmpty, orElse: () => '');
      if (title.isEmpty) campusFail('title_not_found', '没有识别到通知标题。');
      items.add({
        'source': source,
        'title': title,
        'url': '$url',
        'publishedDate': date,
      });
      break;
    }
  }
  if (recognized == 0) campusFail('list_not_found', '没有识别到通知列表，无法确认是空列表。');
  final pages = document.querySelector('.p_pages');
  final numbers =
      pages
          ?.querySelectorAll('.p_no, .p_no_d')
          .map((n) => int.tryParse(_text(n)))
          .whereType<int>()
          .where((n) => n > 0)
          .toList() ??
      <int>[];
  final current = pages?.querySelector('.p_no_d');
  String? previous;
  String? next;
  for (final link in pages?.querySelectorAll('a[href]') ?? <Element>[]) {
    final url = resolveNoticeURL(link.attributes['href']!, uri);
    if (url == null || url == uri || !isNoticeList(url, source)) continue;
    if (['上页', '上一页'].contains(_text(link))) previous = '$url';
    if (['下页', '下一页'].contains(_text(link))) next = '$url';
  }
  return {
    'source': source,
    'url': '$uri',
    'items': items,
    'previousPageURL': previous,
    'nextPageURL': next,
    'currentPage': current != null
        ? int.tryParse(_text(current))
        : (uri.path == Uri.parse(noticeSources[source]!['url']!).path
              ? 1
              : null),
    'totalPages': numbers.isEmpty ? null : numbers.reduce(math.max),
    'filteredItemCount': filtered,
  };
}

List<String> campusParagraphs(Node root) {
  final buffer = StringBuffer();
  void visit(Node node) {
    if (node is Text) {
      buffer.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
      return;
    }
    if (node is! Element) return;
    final tag = node.localName;
    if ([
      'script',
      'style',
      'noscript',
      'iframe',
      'svg',
      'canvas',
      'form',
      'input',
      'button',
      'object',
      'embed',
    ].contains(tag))
      return;
    if (tag == 'br') {
      buffer.writeln();
      return;
    }
    if (tag == 'tr') {
      buffer.writeln();
      buffer.writeln(
        node.children
            .where((n) => ['th', 'td'].contains(n.localName))
            .map(_text)
            .join('\t'),
      );
      return;
    }
    final block = [
      'div',
      'p',
      'section',
      'article',
      'li',
      'ul',
      'ol',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'blockquote',
      'table',
    ].contains(tag);
    if (block) buffer.writeln();
    for (final child in node.nodes) {
      visit(child);
    }
    if (block) buffer.writeln();
  }

  visit(root);
  return buffer
      .toString()
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

bool _attachment(Uri url) =>
    url.path.endsWith('/download.jsp') ||
    [
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'zip',
      'rar',
      '7z',
      'txt',
      'csv',
    ].contains(url.path.split('.').last.toLowerCase());

Map<String, dynamic> parseNoticeDetail(
  String input,
  Map<String, dynamic> summary,
  Uri uri, {
  CampusNoticePolicy? policy,
}) {
  policy ??= CampusNoticePolicy();
  final document = html.parse(input);
  final body = document.querySelector(
    '#vsb_content, .v_news_content, [id^=vsb_content_]',
  );
  if (body == null) campusFail('body_not_found', '没有识别到通知正文。');
  final titles = [
    ...document
        .querySelectorAll(
          'meta[name=pageTitle], meta[name=ArticleTitle], meta[property="og:title"]',
        )
        .map((n) => n.attributes['content']?.trim() ?? ''),
    ...document
        .querySelectorAll(
          '.cotit, h1.title-center, .article-title, .news-title, h1',
        )
        .map(_text),
    '${summary['title'] ?? ''}'.trim(),
  ];
  final title = titles.firstWhere((s) => s.isNotEmpty, orElse: () => '');
  if (title.isEmpty) campusFail('title_not_found', '没有识别到通知标题。');
  String? date;
  final dates = [
    ...document
        .querySelectorAll(
          'meta[name=PubDate], meta[name=pubdate], meta[property="article:published_time"]',
        )
        .map((n) => n.attributes['content'] ?? ''),
    ...document
        .querySelectorAll(
          '.showdate, .sjkk, .article-date, .news-date, .info-date',
        )
        .map(_text),
  ];
  for (final value in dates) {
    if (value.trim().isEmpty) continue;
    date = noticeDate(value);
    if (date == null) campusFail('missing_publication_date', '通知发布日期无效。');
    break;
  }
  if (date == null) {
    final preceding =
        body.parent?.children.takeWhile((n) => n != body).toList().reversed ??
        <Element>[];
    for (final node in preceding) {
      final value = _text(node);
      if (['发布时间', '发布日期', '浏览次数', '点击'].any(value.contains)) {
        date = noticeDate(value);
        if (date == null) campusFail('missing_publication_date', '通知发布日期无效。');
        break;
      }
    }
  }
  date ??= noticeDate('${summary['publishedDate'] ?? ''}', exact: true);
  if (date == null) campusFail('missing_publication_date', '通知没有有效发布日期。');
  if (!policy.allows(date))
    campusFail('filtered_publication_date', '通知发布日期被当前规则排除。');
  final images = <Map<String, dynamic>>[];
  final attachments = <Map<String, dynamic>>[];
  final links = <Map<String, dynamic>>[];
  final documents = <Map<String, dynamic>>[];
  final seenImages = <String>{},
      seenAttachments = <String>{},
      seenLinks = <String>{},
      seenDocuments = <String>{};
  for (final node in body.querySelectorAll('img')) {
    final lazy = node.attributes['data-src'] ?? '';
    final url = resolveNoticeURL(
      lazy.isEmpty ? node.attributes['src'] ?? '' : lazy,
      uri,
    );
    if (url != null && seenImages.add('$url'))
      images.add({'url': '$url', 'alt': node.attributes['alt']?.trim()});
  }
  for (final node in (body.parent ?? body).querySelectorAll('a[href]')) {
    final url = resolveNoticeURL(node.attributes['href']!, uri);
    if (url != null && _attachment(url) && seenAttachments.add('$url'))
      attachments.add({
        'title': _text(node).isEmpty ? url.pathSegments.last : _text(node),
        'url': '$url',
      });
  }
  for (final node in body.querySelectorAll('a[href]')) {
    final url = resolveNoticeURL(node.attributes['href']!, uri);
    if (url != null && !_attachment(url) && seenLinks.add('$url'))
      links.add({
        'title': _text(node).isEmpty ? '$url' : _text(node),
        'url': '$url',
      });
  }
  final embedded = [
    ...body
        .querySelectorAll('iframe[src], embed[src], object[data]')
        .map((n) => n.attributes[n.localName == 'object' ? 'data' : 'src']!),
    for (final script in body.querySelectorAll('script'))
      ...RegExp(
        "showVsbpdfIframe\\(\\s*[\"']([^\"']+)[\"']",
      ).allMatches(script.text).map((m) => m[1]!),
  ];
  for (final value in embedded) {
    final url = resolveNoticeURL(value, uri);
    if (url == null ||
        !url.path.toLowerCase().endsWith('.pdf') ||
        !seenDocuments.add('$url'))
      continue;
    documents.add({'url': '$url', 'sourceURL': '$uri'});
    if (seenAttachments.add('$url'))
      attachments.add({'title': '正文 PDF', 'url': '$url'});
  }
  final paragraphs = campusParagraphs(body);
  return {
    'summary': {
      ...summary,
      'title': title,
      'publishedDate': date,
      'url': '$uri',
    },
    'text': paragraphs.join('\n\n'),
    'paragraphs': paragraphs,
    'images': images,
    'attachments': attachments,
    'links': links,
    'documents': documents,
  };
}

void validateNoticePDF(
  Uri uri,
  Uri source,
  List<int> bytes, {
  int maximumBytes = 20 * 1024 * 1024,
}) {
  if (!isUniversityURL(uri) ||
      !uri.path.toLowerCase().endsWith('.pdf') ||
      !isUniversityURL(source) ||
      !isNoticeArticle(source))
    campusFail('unsupported_url', 'PDF 地址不在支持范围内。');
  if (maximumBytes <= 0) campusFail('invalid_configuration', 'PDF 容量配置无效。');
  if (bytes.length > maximumBytes)
    campusFail('document_too_large', 'PDF 超过允许的容量。');
  if (bytes.length < 5 ||
      ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-')
    campusFail('invalid_document', '服务器未返回有效 PDF。');
}

Object? libraryPayload(Object? value) {
  if (value is! Map) return value;
  final root = campusMap(value);
  if (root.containsKey('code')) {
    final code = campusInt(root['code']);
    if (code != 0 && code != 200)
      campusFail('library_rejected_$code', '图书馆拒绝请求（业务码 $code）。');
    if (!root.containsKey('data')) campusFail('invalid_payload', '图书馆响应缺少数据。');
    return root['data'];
  }
  return root['data'] ?? root;
}

Map<String, dynamic> parseLibraryPage(
  Object? payload, {
  int page = 1,
  int pageSize = 100,
  bool strict = false,
}) {
  final root = payload is List ? <String, dynamic>{} : campusMap(payload);
  final items = campusRecords(payload is List ? payload : root['items']);
  if (strict &&
      [
        'currentPage',
        'pageSize',
        'totalPage',
        'total',
      ].any((k) => !root.containsKey(k)))
    campusFail('invalid_payload', '图书馆分页数据不完整。');
  final current = root.containsKey('currentPage')
      ? campusInt(root['currentPage'])
      : page;
  final size = root.containsKey('pageSize')
      ? campusInt(root['pageSize'])
      : pageSize;
  final totalPage = root.containsKey('totalPage')
      ? campusInt(root['totalPage'])
      : (items.isEmpty ? 0 : 1);
  final total = root.containsKey('total')
      ? campusInt(root['total'])
      : items.length;
  if (current < 1 || size < 1 || totalPage < 0 || total < 0)
    campusFail('invalid_payload', '图书馆分页数据无效。');
  return {
    'currentPage': current,
    'pageSize': size,
    'totalPage': totalPage,
    'total': total,
    'items': items,
  };
}

num secondClassNumber(Object? value) {
  if (value is String && !RegExp(r'^[0-9]+(?:\.[0-9]+)?$').hasMatch(value))
    campusFail('invalid_response', '第二课堂学分格式无效。');
  final number = value is num
      ? value
      : (value is String ? num.tryParse(value) : null);
  if (number == null || !number.isFinite || number < 0)
    campusFail('invalid_response', '第二课堂学分格式无效。');
  return number;
}

num _secondClassRemaining(num required, num earned) {
  (BigInt, int) parts(num number) {
    if (number == 0) return (BigInt.zero, 0);
    final match = RegExp(
      r'^([0-9]+)(?:\.([0-9]+))?(?:e([+-]?[0-9]+))?$',
    ).firstMatch('$number')!;
    final fraction = match[2] ?? '';
    return (
      BigInt.parse('${match[1]}$fraction'),
      fraction.length - int.parse(match[3] ?? '0'),
    );
  }

  final a = parts(required), b = parts(earned);
  final scale = math.max(0, math.max(a.$2, b.$2));
  final difference =
      a.$1 * BigInt.from(10).pow(scale - a.$2) -
      b.$1 * BigInt.from(10).pow(scale - b.$2);
  if (difference <= BigInt.zero) return 0;
  if (scale == 0) return num.parse('$difference');
  final digits = '$difference'.padLeft(scale + 1, '0');
  return num.parse(
    '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}',
  );
}

Map<String, dynamic> secondClassPayload(Object? value) {
  final root = campusMap(value);
  if (!(root['code'] is int || root['code'] is String))
    campusFail('invalid_response', '第二课堂业务码无效。');
  final code = '${root['code']}';
  if (code != '0')
    campusFail('second_class_rejected_$code', '第二课堂拒绝请求（业务码 $code）。');
  return campusMap(root['data']);
}

Map<String, dynamic> parseSecondClass(Object? grades, Object? summary) {
  final g = secondClassPayload(grades), s = secondClassPayload(summary);
  final categories = <Map<String, dynamic>>[];
  for (final entry in campusRecords(g['cj'])) {
    final numbers = {
      for (final key in ['XF', 'YXXF', 'BXXF', 'XXXF', 'bxyxxf', 'xxyxxfR'])
        key: secondClassNumber(entry[key]),
    };
    if (entry['MKDM'] is! String || entry['NR'] is! String)
      campusFail('invalid_response', '第二课堂类别无效。');
    final requirements = <Map<String, dynamic>>[];
    for (final pair in [
      ('required', 'BXXF', 'bxyxxf'),
      ('elective', 'XXXF', 'xxyxxfR'),
    ]) {
      final required = numbers[pair.$2]!, earned = numbers[pair.$3]!;
      if (required > 0)
        requirements.add({
          'kind': pair.$1,
          'requiredCredits': required,
          'earnedCredits': earned,
          'remainingCredits': _secondClassRemaining(required, earned),
          'isCompleted': earned >= required,
        });
    }
    if (requirements.isNotEmpty)
      categories.add({
        'id': entry['MKDM'],
        'name': entry['NR'],
        'requiredCredits': numbers['XF'],
        'earnedCredits': numbers['YXXF'],
        'requirements': requirements,
      });
  }
  if (s['PJ'] is! String) campusFail('invalid_response', '第二课堂评价无效。');
  return {
    'categories': categories,
    'earnedCredits': secondClassNumber(s['ZXF']),
    'evaluation': s['PJ'],
  };
}

Map<String, dynamic> parseShuttle(String input) {
  final document = html.parseFragment(input);
  final table = document.querySelector('table');
  if (table == null) campusFail('invalid_schedule', '没有识别到校车时刻表。');
  final grid = <List<_ShuttleCell?>>[];
  final cells = <_ShuttleCell>[];
  Element? parentTable(Element node) {
    var parent = node.parent;
    while (parent != null && parent.localName != 'table') {
      parent = parent.parent;
    }
    return parent;
  }

  final rows = table
      .querySelectorAll('tr')
      .where((r) => parentTable(r) == table)
      .toList();
  for (var r = 0; r < rows.length; r++) {
    while (grid.length <= r) {
      grid.add([]);
    }
    var column = 0;
    for (final node in rows[r].children.where(
      (n) => ['td', 'th'].contains(n.localName),
    )) {
      while (column < grid[r].length && grid[r][column] != null) {
        column++;
      }
      final rs = int.tryParse(node.attributes['rowspan'] ?? '1'),
          cs = int.tryParse(node.attributes['colspan'] ?? '1');
      if (rs == null ||
          cs == null ||
          rs < 1 ||
          cs < 1 ||
          r + rs > rows.length ||
          cs > 100 ||
          column + cs > 100)
        campusFail('invalid_schedule', '校车表格合并单元格无效。');
      final cell = _ShuttleCell(r, cs, _text(node));
      cells.add(cell);
      for (var y = r; y < r + rs; y++) {
        while (grid.length <= y) {
          grid.add([]);
        }
        while (grid[y].length < column + cs) {
          grid[y].add(null);
        }
        for (var x = column; x < column + cs; x++) {
          if (grid[y][x] != null) campusFail('invalid_schedule', '校车表格单元格重叠。');
          grid[y][x] = cell;
        }
      }
      column += cs;
    }
  }
  const labels = ['日期', '起点', '终点', '发车时间', '行车线路'];
  if (grid.any((r) => r.length != 5 || r.any((c) => c == null)))
    campusFail('invalid_schedule', '校车表格列数无效。');
  final header = grid.indexWhere(
    (r) => List.generate(
      5,
      (c) =>
          r[c]!.row == grid.indexOf(r) &&
          r[c]!.span == 1 &&
          r[c]!.text.replaceAll(RegExp(r'\s'), '') == labels[c],
    ).every((v) => v),
  );
  if (header < 0) campusFail('invalid_schedule', '校车表格标题无效。');
  final titles = cells.where(
    (c) => c.row < header && c.span == 5 && c.text.isNotEmpty,
  );
  final title = titles.isNotEmpty
      ? titles.first.text
      : table.querySelector('caption')?.text ?? '校车时刻表';
  final departures = <Map<String, dynamic>>[], notes = <String>[];
  for (var r = header + 1; r < grid.length; r++) {
    final row = grid[r];
    if (row[0]!.span == 5) {
      if (row[0]!.row == r && row[0]!.text.isNotEmpty) notes.add(row[0]!.text);
      continue;
    }
    final values = row.map((c) => c!.text).toList();
    if (values[3].isEmpty && values[4].isEmpty) continue;
    if (values.any((v) => v.isEmpty) ||
        !RegExp(r'^(?:[01]?[0-9]|2[0-3])[:：][0-5][0-9]$').hasMatch(values[3]))
      campusFail('invalid_schedule', '校车发车时间或行程无效。');
    departures.add({
      'operatingDays': values[0],
      'origin': values[1],
      'destination': values[2],
      'departureTime': values[3].replaceAll('：', ':'),
      'route': values[4],
    });
  }
  if (departures.isEmpty) campusFail('invalid_schedule', '没有有效校车班次。');
  table.remove();
  for (final node in document.nodes) {
    notes.addAll(campusParagraphs(node));
  }
  return {'title': title, 'departures': departures, 'notes': notes};
}

class _ShuttleCell {
  _ShuttleCell(this.row, this.span, this.text);
  final int row, span;
  final String text;
}

String shuttleSignatureInput(String timestamp) =>
    'timestamp=$timestamp,key=lianyi2019';

const laundryWasherType = 'c9892cb4-bd78-40f6-83c2-ba73383b090a';
bool isRunningWasher(Map<String, dynamic> order) =>
    order['orderType'] == 1 &&
    order['orderStatus'] == 2 &&
    '${order['parentTypeId']}' == laundryWasherType;

Object? laundryPayload(Object? value, {bool authenticated = false}) {
  final root = campusMap(value);
  if (root['code'] is! int) campusFail('invalid_response', '胖乖响应业务码无效。');
  final code = root['code'] as int;
  if (code == 2 && authenticated)
    campusFail('laundry_login_required', '胖乖凭据已失效（业务码 2），请重新登录。');
  if (code != 0) campusFail('laundry_rejected_$code', '胖乖拒绝请求（业务码 $code）。');
  return root['data'];
}

Map<String, dynamic> parseLaundryOrder(Object? value) {
  final order = campusMap(value);
  if (order['id'] is! String ||
      (order['id'] as String).isEmpty ||
      order['orderType'] is! int ||
      order['orderStatus'] is! int)
    campusFail('invalid_response', '胖乖订单结构无效。');
  if (order['parentTypeId'] != null &&
      order['parentTypeId'] is! String &&
      order['parentTypeId'] is! int)
    campusFail('invalid_response', '胖乖设备类型无效。');
  for (final key in ['machineName', 'shopName', 'machineFunctionName']) {
    if (order[key] != null && order[key] is! String)
      campusFail('invalid_response', '胖乖订单字段无效。');
  }
  return order;
}

DateTime? laundryCompletionDate(Object? value) {
  if (value == null || value == '') return null;
  if (value is! String ||
      !RegExp(
        r'^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$',
      ).hasMatch(value))
    campusFail('invalid_response', '胖乖预计结束时间无效。');
  final date = noticeDate(value.substring(0, 10), exact: true);
  final parts = value.substring(11).split(':').map(int.parse).toList();
  if (date == null || parts[0] > 23 || parts[1] > 59 || parts[2] > 59)
    campusFail('invalid_response', '胖乖预计结束时间无效。');
  return DateTime.parse('${value.replaceFirst(' ', 'T')}+08:00').toUtc();
}

Map<String, dynamic> laundrySnapshot(
  Object? value, {
  required DateTime observedAt,
  required DateTime serverDate,
}) {
  final order = parseLaundryOrder(value);
  final completion = laundryCompletionDate(order['completeTime']);
  final seconds = isRunningWasher(order) && completion != null
      ? math.max(
          0,
          (completion.difference(serverDate).inMicroseconds / 1000000).ceil(),
        )
      : null;
  return {
    'order': order,
    'estimatedCompletionTime': completion?.toIso8601String(),
    'observedAt': observedAt.toUtc().toIso8601String(),
    'remainingSeconds': seconds,
  };
}

int? laundryRemaining(Map<String, dynamic> snapshot, DateTime now) {
  final seconds = snapshot['remainingSeconds'] as int?;
  if (seconds == null) return null;
  final observed = DateTime.parse(snapshot['observedAt'] as String);
  final elapsed = math.max(
    0,
    (now.difference(observed).inMicroseconds / 1000000).floor(),
  );
  return math.max(0, seconds - elapsed);
}

int laundryCacheLifetime(int seconds) => seconds > 600
    ? 120
    : seconds > 300
    ? 60
    : seconds > 120
    ? 30
    : 0;

bool laundrySnapshotIsFresh(Map<String, dynamic> snapshot, DateTime now) {
  final remaining = laundryRemaining(snapshot, now);
  final age = now.difference(DateTime.parse(snapshot['observedAt'] as String));
  return remaining != null &&
      !age.isNegative &&
      age.inMicroseconds < laundryCacheLifetime(remaining) * 1000000;
}

DateTime laundryServerDate(String? header, DateTime fallback) {
  try {
    return header == null ? fallback : HttpDate.parse(header);
  } on HttpException {
    return fallback;
  }
}

class CampusLaundryCredential {
  CampusLaundryCredential(
    this.userID,
    this.token,
    this.firstVerifiedAt,
    this.lastVerifiedAt,
  );
  final String userID, token;
  final DateTime firstVerifiedAt, lastVerifiedAt;
  static final _swiftEpoch = DateTime.utc(2001);
  static DateTime _date(Object? value) {
    if (value is num && value.isFinite)
      return _swiftEpoch.add(Duration(microseconds: (value * 1000000).round()));
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date == null) campusFail('invalid_credential', '保存的胖乖凭据日期无效。');
    return date.toUtc();
  }

  static CampusLaundryCredential decode(String value) {
    try {
      final root = campusMap(jsonDecode(utf8.decode(base64Decode(value))));
      if (root['token'] is! String || (root['token'] as String).isEmpty)
        campusFail('invalid_credential', '保存的胖乖凭据无效。');
      return CampusLaundryCredential(
        campusID(root['userID']),
        root['token'] as String,
        _date(root['firstVerifiedAt']),
        _date(root['lastVerifiedAt']),
      );
    } on FormatException {
      campusFail('invalid_credential', '保存的胖乖凭据格式无效。');
    }
  }

  String encode() => base64Encode(
    utf8.encode(
      jsonEncode({
        'userID': userID,
        'token': token,
        'firstVerifiedAt':
            firstVerifiedAt.difference(_swiftEpoch).inMicroseconds / 1000000,
        'lastVerifiedAt':
            lastVerifiedAt.difference(_swiftEpoch).inMicroseconds / 1000000,
      }),
    ),
  );
  @override
  String toString() => 'CampusLaundryCredential';
}

int compareLaundryWashers(Map<String, dynamic> a, Map<String, dynamic> b) {
  (int, String) key(String value) {
    final match = RegExp(r'^([南北])楼?([0-9].*)$').firstMatch(value);
    return match == null ? (2, value) : (match[1] == '南' ? 0 : 1, match[2]!);
  }

  final left = key('${a['name']}'), right = key('${b['name']}');
  if (left.$1 != right.$1) return left.$1.compareTo(right.$1);
  final l = RegExp(
    r'[0-9]+|[^0-9]+',
  ).allMatches(left.$2).map((m) => m[0]!).toList();
  final r = RegExp(
    r'[0-9]+|[^0-9]+',
  ).allMatches(right.$2).map((m) => m[0]!).toList();
  for (var i = 0; i < math.min(l.length, r.length); i++) {
    final ln = int.tryParse(l[i]), rn = int.tryParse(r[i]);
    final diff = ln != null && rn != null
        ? ln.compareTo(rn)
        : l[i].compareTo(r[i]);
    if (diff != 0) return diff;
  }
  final length = l.length.compareTo(r.length);
  return length == 0 ? '${a['id']}'.compareTo('${b['id']}') : length;
}
