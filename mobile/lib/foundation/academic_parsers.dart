import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

typedef AcademicJson = Map<String, dynamic>;

/// Pure parsing failures are translated to FoundationException at the HTTP edge.
class AcademicParseException implements Exception {
  AcademicParseException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

Never academicFail(String message, [String code = 'parse_error']) =>
    throw AcademicParseException(code, message);

String academicText(Node node) {
  String visit(Node n) {
    if (n is Text) return n.data;
    if (n is Element) {
      if (['script', 'style', 'noscript'].contains(n.localName)) return '';
      if (n.localName == 'br') return ' ';
    }
    return n.nodes.map(visit).join('');
  }

  return visit(node).replaceAll(RegExp(r'\s+|\u00a0'), ' ').trim();
}

List<Element> _rows(Element table) => table.querySelectorAll('tr').where((row) {
  var parent = row.parent;
  while (parent != null) {
    if (parent.localName == 'table') return identical(parent, table);
    parent = parent.parent;
  }
  return false;
}).toList();
List<Element> _cells(Element row) => row.children
    .where((cell) => ['th', 'td'].contains(cell.localName))
    .toList();
Element _one(Node root, String selector) {
  final elements = switch (root) {
    Document value => value.querySelectorAll(selector),
    DocumentFragment value => value.querySelectorAll(selector),
    Element value => value.querySelectorAll(selector),
    _ => <Element>[],
  };
  if (elements.length != 1) academicFail('缺少或重复的页面结构：$selector');
  return elements.single;
}

List<AcademicJson> academicFields(Map<String, String> values) => [
  for (final entry in values.entries) {'name': entry.key, 'value': entry.value},
];
AcademicJson academicRow(String title, Map<String, String> values) => {
  'title': title,
  'fields': academicFields(values),
};

class AcademicForm {
  AcademicForm(
    this.action,
    this.fields,
    this.controls,
    this.element, {
    this.successfulFields = const [],
  });
  final Uri action;
  final Map<String, String> fields;
  final List<AcademicJson> controls;
  final Element element;
  final List<MapEntry<String, String>> successfulFields;
  List<MapEntry<String, String>> submission(Map<String, String> values) {
    if (successfulFields.isEmpty) return values.entries.toList();
    final emitted = <String>{};
    final result = <MapEntry<String, String>>[];
    for (final entry in successfulFields) {
      if (!values.containsKey(entry.key)) continue;
      final unchanged = values[entry.key] == fields[entry.key];
      if (emitted.add(entry.key) || unchanged) {
        result.add(
          MapEntry(entry.key, unchanged ? entry.value : values[entry.key]!),
        );
      }
    }
    result.addAll(
      values.entries.where((entry) => !emitted.contains(entry.key)),
    );
    return result;
  }

  List<AcademicJson> options(String name) {
    final control = _one(element, '[name="$name"]');
    if (control.localName != 'select' ||
        control.attributes.containsKey('multiple') ||
        control.attributes.containsKey('disabled')) {
      academicFail('不支持的选项控件：$name', 'unsupported_form');
    }
    return _options(control);
  }

  String choose(String name, Object? requested, {bool nonempty = false}) {
    final value = requested?.toString() ?? fields[name] ?? '';
    if ((nonempty && value.isEmpty) ||
        !options(name).any((o) => o['value'] == value)) {
      academicFail('查询选项不在学校表单中：$name', 'invalid_query');
    }
    return value;
  }
}

List<AcademicJson> _options(Element select) {
  final result = <AcademicJson>[];
  final seen = <String>{};
  int selected = 0;
  for (final option in select.querySelectorAll('option')) {
    if (option.attributes.containsKey('disabled')) continue;
    final value = option.attributes['value'] ?? academicText(option);
    final label = academicText(option);
    if (!seen.add(value) || label.isEmpty) {
      academicFail('重复或无名称的表单选项', 'unsupported_form');
    }
    if (option.attributes.containsKey('selected')) selected++;
    result.add({'value': value, 'label': label});
  }
  if (result.isEmpty || selected > 1) {
    academicFail('空选项或多个默认选项', 'unsupported_form');
  }
  return result;
}

/// Resolves only a known same-origin endpoint. Never executes page JavaScript.
AcademicForm parseAcademicForm(
  String source,
  Uri sourceUri, {
  required String id,
  String? actionPath,
  bool allowScriptAction = false,
}) {
  final document = html.parse(source);
  final form = _one(document, 'form[id="$id"]');
  if ((form.attributes['method'] ?? '').toLowerCase() != 'post') {
    academicFail('教务表单必须使用 POST', 'unsupported_form');
  }
  final rawAction = (form.attributes['action'] ?? '').trim();
  final expected = Uri(
    scheme: sourceUri.scheme,
    host: sourceUri.host,
    port: sourceUri.hasPort ? sourceUri.port : null,
    path: actionPath ?? sourceUri.path,
  );
  Uri action;
  if (rawAction.isEmpty && actionPath != null && actionPath != sourceUri.path) {
    final scripts = document
        .querySelectorAll('script')
        .map((s) => s.text)
        .join('\n');
    final pattern = RegExp(
      'document\\.forms\\s*\\[\\s*["\']${RegExp.escape(id)}["\']\\s*\\]\\s*\\.action\\s*=\\s*["\']${RegExp.escape(actionPath)}["\']',
    );
    if (!allowScriptAction || !pattern.hasMatch(scripts)) {
      academicFail('无法确认表单提交地址', 'unsupported_form');
    }
    action = expected;
  } else {
    action = rawAction.isEmpty ? sourceUri : sourceUri.resolve(rawAction);
  }
  if (action.scheme != expected.scheme ||
      !['https', 'http'].contains(action.scheme) ||
      action.origin != expected.origin ||
      action.path != expected.path ||
      action.userInfo.isNotEmpty ||
      action.hasFragment ||
      action.hasQuery) {
    academicFail('表单提交地址不符合预期', 'unsupported_form');
  }
  final fields = <String, String>{};
  final successfulFields = <MapEntry<String, String>>[];
  final hiddenNames = <String>{};
  final controls = <AcademicJson>[];
  for (final control in form.querySelectorAll('input, select, textarea')) {
    final name = control.attributes['name'] ?? '';
    if (name.isEmpty || control.attributes.containsKey('disabled')) continue;
    final type = (control.attributes['type'] ?? 'text').toLowerCase();
    if (['submit', 'button', 'reset', 'file', 'image'].contains(type)) continue;
    if (['checkbox', 'radio'].contains(type) &&
        !control.attributes.containsKey('checked'))
      continue;
    String value;
    if (control.localName == 'select') {
      if (control.attributes.containsKey('multiple')) {
        academicFail('暂不支持多选教务表单', 'unsupported_form');
      }
      final available = _options(control);
      final selected = control.querySelectorAll(
        'option[selected]:not([disabled])',
      );
      value = selected.isEmpty
          ? available.first['value'] as String
          : selected.single.attributes['value'] ??
                academicText(selected.single);
      controls.add({
        'key': name,
        'label': name,
        'type': 'select',
        'value': value,
        'options': available,
      });
    } else {
      value = control.localName == 'textarea'
          ? control.text
          : control.attributes['value'] ??
                (['checkbox', 'radio'].contains(type) ? 'on' : '');
      if (type == 'text' || control.localName == 'textarea') {
        controls.add({
          'key': name,
          'label': name,
          'type': 'text',
          'value': value,
          'options': <AcademicJson>[],
        });
      }
    }
    if (fields.containsKey(name)) {
      if (type == 'hidden' && hiddenNames.contains(name)) {
        successfulFields.add(MapEntry(name, value));
        continue;
      }
      academicFail('重复的非隐藏表单字段：$name', 'unsupported_form');
    }
    if (type == 'hidden') hiddenNames.add(name);
    fields[name] = value;
    successfulFields.add(MapEntry(name, value));
  }
  return AcademicForm(
    action,
    fields,
    controls,
    form,
    successfulFields: successfulFields,
  );
}

List<int> parseAcademicNumberList(String source, {required int upperBound}) {
  if (upperBound < 1 ||
      !RegExp(
        r'^\s*\d+\s*(?:-\s*\d+\s*)?(?:,\s*\d+\s*(?:-\s*\d+\s*)?)*$',
      ).hasMatch(source)) {
    academicFail('周次或节次格式无效', 'invalid_number_list');
  }
  final result = <int>{};
  for (final part in source.split(',')) {
    final values = part.split('-').map((s) => int.tryParse(s.trim())).toList();
    final start = values.first, end = values.last;
    if (start == null ||
        end == null ||
        start < 1 ||
        end < start ||
        end > upperBound) {
      academicFail('周次或节次超出范围', 'invalid_number_list');
    }
    result.addAll(List.generate(end - start + 1, (i) => start + i));
  }
  return result.toList()..sort();
}

AcademicJson parseAcademicSchedule(
  String source, {
  required String termID,
  int maxWeek = 30,
  int maxSection = 12,
}) {
  final document = html.parse(source);
  final table = _one(document, 'table#kbtable');
  final rows = _rows(table);
  if (rows.isEmpty) academicFail('课表没有表头');
  final headers = _cells(rows.first).map(academicText).toList();
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  if (headers.length != 8 ||
      headers.skip(headers.length - 7).join('|') != weekdays.join('|')) {
    academicFail('课表星期列顺序不正确');
  }
  final lessons = <AcademicJson>[];
  final seen = <String>{};
  int gridRows = 0;
  for (final row in rows.skip(1)) {
    final contents = row.querySelectorAll('.kbcontent:not(.sykb2)');
    if (contents.isEmpty) continue;
    if (contents.length != 7) academicFail('课表缺少星期单元格');
    gridRows++;
    for (var day = 0; day < 7; day++) {
      for (final raw in contents[day].innerHtml.split(
        '---------------------',
      )) {
        final block = html.parseFragment(raw);
        if (academicText(block).isEmpty) continue;
        final name = block.nodes
            .whereType<Text>()
            .map((n) => n.data)
            .join(' ')
            .trim();
        if (name.isEmpty) academicFail('课程缺少名称');
        final time = block.querySelectorAll('font[title="周次(节次)"]');
        if (time.length != 1) academicFail('课程缺少或重复时间');
        final match = RegExp(
          r'^\s*([\d,\s-]+)\(周\)\[([\d,\s-]+)节\]\s*$',
        ).firstMatch(academicText(time.single));
        if (match == null) academicFail('课程时间格式不受支持', 'invalid_time_format');
        final weeks = parseAcademicNumberList(match[1]!, upperBound: maxWeek);
        final sections = parseAcademicNumberList(
          match[2]!,
          upperBound: maxSection,
        );
        String field(String title) => block
            .querySelectorAll('font[title="$title"]')
            .map(academicText)
            .join(' ');
        final lesson = <String, dynamic>{
          'name': name,
          'code': '',
          'teacher': field('老师'),
          'location': field('教室'),
          'day': day + 1,
          'weeks': weeks.join(','),
          'sections': sections.join(','),
        };
        if (seen.add(jsonEncode([lesson, field('课堂名称')]))) lessons.add(lesson);
      }
    }
  }
  if (gridRows == 0) academicFail('未找到课表数据网格');
  lessons.sort((a, b) {
    var order = (a['day'] as int).compareTo(b['day'] as int);
    if (order != 0) return order;
    order = int.parse(
      (a['sections'] as String).split(',').first,
    ).compareTo(int.parse((b['sections'] as String).split(',').first));
    return order != 0 ? order : jsonEncode(a).compareTo(jsonEncode(b));
  });
  final term = RegExp(r'^(\d{4}-\d{4})-([12])$').firstMatch(termID);
  if (term == null) academicFail('学期编号格式无效', 'invalid_term');
  return {
    'provider': 'wust-local',
    'schoolYear': term[1],
    'semester': int.parse(term[2]!),
    'lessons': lessons,
  };
}

void _rejectPagination(Document document) {
  if (document
          .querySelectorAll('a')
          .any((a) => ['下一页', '尾页', '末页'].contains(academicText(a))) ||
      RegExp(r'共\s*(\d+)\s*页')
          .allMatches(academicText(document))
          .any((m) => (int.tryParse(m[1]!) ?? 2) > 1)) {
    academicFail('不支持分页结果，未返回不完整数据', 'unsupported_pagination');
  }
}

List<Map<String, String>> _records(
  Element table,
  List<String> required, {
  bool requireRecords = true,
}) {
  final rows = _rows(table);
  if (rows.isEmpty) academicFail('表格没有表头');
  final header = _cells(rows.first);
  final names = header
      .map((c) => academicText(c).replaceAll(RegExp(r'\s'), ''))
      .toList();
  if (header.any((c) => c.localName != 'th') ||
      names.any((n) => n.isEmpty) ||
      names.toSet().length != names.length ||
      !required.every(names.contains)) {
    academicFail('表格缺少必需列或列名重复');
  }
  final result = <Map<String, String>>[];
  var emptySeen = false;
  for (final row in rows.skip(1)) {
    final cells = _cells(row);
    if (cells.isEmpty && academicText(row).isEmpty) continue;
    if (cells.length == 1 &&
        academicText(cells.single) == '未查询到数据' &&
        int.tryParse(cells.single.attributes['colspan'] ?? '') ==
            names.length) {
      if (emptySeen || result.isNotEmpty) academicFail('空记录标记与数据冲突');
      emptySeen = true;
      continue;
    }
    if (emptySeen || cells.length != names.length) academicFail('表格数据列数不一致');
    for (final cell in cells) {
      for (final span in ['rowspan', 'colspan']) {
        if (cell.attributes.containsKey(span) &&
            int.tryParse(cell.attributes[span]!) != 1) {
          academicFail('记录表不支持合并数据单元格');
        }
      }
    }
    result.add(Map.fromIterables(names, cells.map(academicText)));
    if (result.length > 4096) academicFail('表格过大');
  }
  if (requireRecords && result.isEmpty && !emptySeen)
    academicFail('缺少数据或明确的空记录标记');
  return result;
}

AcademicJson parseAcademicGrades(String source, {String termID = ''}) {
  final document = html.parse(source);
  _rejectPagination(document);
  final records = _records(_one(document, 'table#dataList'), [
    '开课学期',
    '课程编号',
    '课程名称',
    '成绩',
  ]);
  final courses = <AcademicJson>[];
  const mapping = {
    'name': '课程名称',
    'code': '课程编号',
    'term': '开课学期',
    'score': '成绩',
    'credit': '学分',
    'point': '绩点',
    'makeupTerm': '补重学期',
    'attempt': '考试性质',
    'nature': '课程性质',
    'assessment': '考核方式',
    'mark': '成绩标识',
  };
  for (final values in records) {
    if (['开课学期', '课程编号', '课程名称'].any((k) => values[k]!.isEmpty))
      academicFail('成绩记录缺少课程或学期');
    if (termID.isNotEmpty && values['开课学期'] != termID)
      academicFail('学校未回显所选学期', 'selection_not_reflected');
    courses.add({
      for (final e in mapping.entries) e.key: values[e.value] ?? '',
      'fields': academicFields(values),
    });
  }
  return {'provider': 'wust-local', 'courses': courses};
}

AcademicJson parseAcademicExams(String source, {required String termID}) {
  if (termID.isEmpty) academicFail('考试查询缺少学期', 'invalid_query');
  final document = html.parse(source);
  _rejectPagination(document);
  final tables = document.querySelectorAll('table[id="dataList"]');
  if (tables.length != 2) academicFail('考试页面必须包含集中与自行申请两张表');
  final sources = <bool>{};
  final result = <AcademicJson>[];
  for (final table in tables) {
    if (_rows(table).isEmpty) academicFail('考试表格没有表头');
    final centralized = _cells(
      _rows(table).first,
    ).any((c) => academicText(c) == '考试场次');
    if (!sources.add(centralized)) academicFail('考试安排来源重复');
    final records = _records(table, [
      '学年学期',
      '课程编号',
      '课程名称',
      '周次',
      '星期',
      '节次',
      '时间',
      '座位号',
      '场地',
      '校区',
    ]);
    for (final values in records) {
      if (['学年学期', '课程编号', '课程名称'].any((k) => values[k]!.isEmpty))
        academicFail('考试记录缺少课程或学期');
      if (values['学年学期'] != termID)
        academicFail('考试学期不符合查询', 'selection_not_reflected');
      result.add(academicRow(values['课程名称']!, values));
    }
  }
  return {'rows': result};
}

AcademicJson parseAcademicStudent(String source) {
  final table = _one(html.parse(source), 'table#xjkpTable');
  final rows = _rows(table);
  String cell(int r, int c) {
    if (rows.length < r || _cells(rows[r - 1]).length < c)
      academicFail('学籍表缺少字段');
    return academicText(_cells(rows[r - 1])[c - 1]);
  }

  String labeled(int r, int c, String label) {
    final text = cell(r, c);
    if (!text.startsWith('$label：') ||
        text.substring(label.length + 1).trim().isEmpty)
      academicFail('学籍字段不符合预期：$label');
    return text.substring(label.length + 1).trim();
  }

  final values = {
    '姓名': cell(4, 2),
    '学号': labeled(3, 5, '学号'),
    '院系': labeled(3, 1, '院系'),
    '专业': labeled(3, 2, '专业'),
    '班级': labeled(3, 4, '班级'),
    '出生日期': cell(5, 2),
    '性别': cell(4, 4),
    '民族': cell(8, 4),
    '籍贯': cell(7, 2),
  };
  // Validate the original layout without exposing the identity-card value in results.
  cell(50, 4);
  return {
    'rows': [academicRow(values['姓名']!, values)],
  };
}

DateTime parseAcademicDate(String source) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(source);
  if (match == null) academicFail('日期必须为 yyyyMMdd', 'invalid_date');
  final y = int.parse(match[1]!),
      m = int.parse(match[2]!),
      d = int.parse(match[3]!);
  final date = DateTime.utc(y, m, d);
  if (y < 1 || date.year != y || date.month != m || date.day != d)
    academicFail('无效日期', 'invalid_date');
  return date;
}

String academicDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

AcademicJson parseAcademicCalendar(
  String source, {
  required DateTime referenceDate,
}) {
  final document = html.parse(source);
  final labels = document
      .querySelectorAll('#li_showWeek')
      .map((e) => e.innerHtml)
      .toList();
  final pattern = RegExp(
    r'''(?:\$|jQuery)\(\s*["']#li_showWeek["']\s*\)\s*\.html\(\s*(?:"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)')\s*\)''',
  );
  for (final script in document.querySelectorAll('script')) {
    for (final match in pattern.allMatches(script.text)) {
      labels.add(
        (match[1] ?? match[2]!)
            .replaceAll(r'\/', '/')
            .replaceAll(r'\"', '"')
            .replaceAll(r"\'", "'"),
      );
    }
  }
  int? week, total;
  for (final label in labels) {
    for (final m in RegExp(
      r'第\s*(\d+)\s*周\s*/\s*(\d+)\s*周',
    ).allMatches(academicText(html.parseFragment(label)))) {
      final w = int.tryParse(m[1]!), t = int.tryParse(m[2]!);
      if (w == null ||
          t == null ||
          w < 1 ||
          t < w ||
          t > 4096 ||
          (week != null && (week != w || total != t)))
        academicFail('教学周无效或存在冲突', 'invalid_teaching_week');
      week = w;
      total = t;
    }
  }
  if (week == null || total == null) academicFail('未找到教学周标签');
  final day = DateTime.utc(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  );
  final monday = day.subtract(Duration(days: day.weekday - 1 + (week - 1) * 7));
  final sunday = monday.add(Duration(days: total * 7 - 1));
  if (monday.year < 1 || sunday.year > 9999) {
    academicFail('教学周日期越界', 'invalid_date');
  }
  return {
    'rows': [
      academicRow('教学信息', {
        '当前教学周': '第 $week 周',
        '总周数': '$total',
        '学期起点': academicDateString(monday),
        '学期终点': academicDateString(sunday),
      }),
      for (var i = 1; i <= total; i++)
        academicRow('第 $i 周', {
          '教学周': '第 $i 周',
          '开始': academicDateString(monday.add(Duration(days: (i - 1) * 7))),
          '结束': academicDateString(monday.add(Duration(days: i * 7 - 1))),
        }),
    ],
  };
}

// Decimal arithmetic is performed with scaled BigInt, preserving Swift Decimal's
// exact subtraction and the distinction between absent values and zero.
String? _decimal(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.length > 38 || !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(value))
    academicFail('学分数值无效', 'invalid_number');
  return value;
}

String _remaining(String? required, String? earned) {
  if (required == null || earned == null) return '未提供';
  final scale = [required, earned]
      .map((s) => s.contains('.') ? s.split('.').last.length : 0)
      .reduce((a, b) => a > b ? a : b);
  BigInt scaled(String value) {
    final p = value.split('.');
    return BigInt.parse(
      p.first + (p.length == 1 ? '' : p.last).padRight(scale, '0'),
    );
  }

  final diff = scaled(required) - scaled(earned);
  final raw = (diff < BigInt.zero ? BigInt.zero : diff).toString().padLeft(
    scale + 1,
    '0',
  );
  if (scale == 0) return raw;
  return '${raw.substring(0, raw.length - scale)}.${raw.substring(raw.length - scale)}'
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

AcademicJson parseAcademicCredits(String source) {
  final document = html.parse(source);
  final result = <AcademicJson>[];
  for (final id in ['byxf1', 'byxf2']) {
    final key = id == 'byxf1' ? '课程性质' : '类别';
    final records = _records(_one(document, 'table#$id'), [
      key,
      if (id == 'byxf1') '课程属性',
      '要求学分',
      '已获得学分',
    ], requireRecords: false);
    for (final record in records) {
      if (record[key]!.isEmpty) academicFail('学分类别缺少名称');
      final required = _decimal(record['要求学分']),
          earned = _decimal(record['已获得学分']);
      result.add({
        ...academicRow(record[key]!, {
          '类别': record[key]!,
          '课程属性': record['课程属性'] ?? '',
          '要求学分': required ?? '未提供',
          '已获学分': earned ?? '未提供',
          '还需学分': _remaining(required, earned),
        }),
        'creditGroup': id == 'byxf1' ? 'graduation' : 'general-elective',
      });
    }
  }
  final stats = _records(_one(document, 'table#byxf3'), [
    '学期数',
    '已修门数',
    '已修学分',
    '学期平均学分',
    '不及格门数',
    '不及格学分',
    '未选门数',
    '未选学分',
    '必修未获学分门数',
    '必修未获学分',
  ], requireRecords: false);
  if (stats.length > 1) academicFail('学期统计出现多行');
  for (final record in stats) {
    for (final e in record.entries) {
      if (['学期数', '已修门数', '不及格门数', '未选门数', '必修未获学分门数'].contains(e.key)) {
        if (e.value.isNotEmpty &&
            (!RegExp(r'^\d+$').hasMatch(e.value) ||
                int.tryParse(e.value) == null))
          academicFail('门数或学期数无效', 'invalid_number');
      } else {
        _decimal(e.value);
      }
    }
    result.add(academicRow('学期统计', record));
  }
  final courses = _records(_one(document, 'table#pyfakcxdmx'), [
    '学期',
    '课程编码',
    '课程名称',
    '课程学分',
    '课程性质',
    '课程属性',
    '状态',
  ], requireRecords: false);
  for (final c in courses) {
    if (c['课程编码']!.isEmpty || c['课程名称']!.isEmpty) academicFail('学分课程缺少编号或名称');
    result.add(
      academicRow(c['课程名称']!, {
        '课程': c['课程名称']!,
        '课程编号': c['课程编码']!,
        '学期': c['学期'] ?? '',
        '学分': _decimal(c['课程学分']) ?? '未提供',
        '课程性质': c['课程性质'] ?? '',
        '课程属性': c['课程属性'] ?? '',
        '状态': c['状态'] ?? '',
      }),
    );
  }
  return {'rows': result};
}

/// Expands merged cells only inside a single HTML row group. Nested tables are
/// excluded from row enumeration, and conflicting/oversized spans fail closed.
List<List<String>> academicTableGrid(Element table) {
  final rows = _rows(table);
  if (rows.isEmpty || rows.length > 4096) academicFail('培养方案表格大小无效');
  final grid = List.generate(rows.length, (_) => <int, String>{});
  var count = 0;
  for (var r = 0; r < rows.length; r++) {
    var column = 0;
    var remaining = 0;
    for (
      var i = r;
      i < rows.length && identical(rows[i].parent, rows[r].parent);
      i++
    ) {
      remaining++;
    }
    for (final cell in _cells(rows[r])) {
      while (grid[r].containsKey(column)) {
        column++;
      }
      int span(String attr) {
        if (!cell.attributes.containsKey(attr)) return 1;
        final raw = cell.attributes[attr]!.trim();
        final value = RegExp(r'^\d+$').hasMatch(raw) ? int.tryParse(raw) : null;
        if (value == null || (value == 0 && attr != 'rowspan'))
          academicFail('培养方案合并单元格跨度无效');
        return value == 0 ? remaining : value;
      }

      final rs = span('rowspan'), cs = span('colspan');
      if (rs > remaining || cs > 256 - column || count + rs * cs > 262144)
        academicFail('培养方案跨度越界或内容过大');
      for (var y = r; y < r + rs; y++) {
        for (var x = column; x < column + cs; x++) {
          if (grid[y].containsKey(x)) academicFail('培养方案单元格重叠');
          grid[y][x] = academicText(cell);
          count++;
        }
      }
      column += cs;
    }
  }
  final width = grid
      .expand((r) => r.keys)
      .fold<int>(0, (n, x) => x + 1 > n ? x + 1 : n);
  if (width == 0) academicFail('培养方案表格为空');
  return [
    for (final row in grid) [for (var x = 0; x < width; x++) row[x] ?? ''],
  ];
}

AcademicJson parseAcademicTrainingPlan(
  String source, {
  String courseName = '',
  String termID = '',
}) {
  // The school's Word exporter emits <pstyle=...> paired with </p>.
  // Normalize that one broken opening tag before HTML5 tree construction.
  final document = html.parse(
    source.replaceAll(
      RegExp(r'<pstyle\s*=', caseSensitive: false),
      '<p style=',
    ),
  );
  if (document.querySelector('#dataList table#mxh') == null &&
      isAcademicWordTrainingPlan(document, source)) {
    return _wordTrainingPlan(
      document,
      source,
      courseName: courseName,
      termID: termID,
    );
  }
  final root = _one(document, '#dataList');
  final courses = _one(root, 'table#mxh');
  for (final table in root.querySelectorAll('table')) {
    var depth = 0;
    var parent = table.parent;
    while (parent != null && !identical(parent, root)) {
      if (parent.localName == 'table') depth++;
      parent = parent.parent;
    }
    if (depth > 16) academicFail('培养方案嵌套过深', 'content_too_large');
    academicTableGrid(table);
  }
  final captions = root.children
      .where((e) => e.localName == 'caption')
      .toList();
  if (captions.length != 1 || academicText(captions.single).isEmpty)
    academicFail('培养方案缺少标题');
  final grid = academicTableGrid(courses);
  final hi = grid.indexWhere(
    (r) => ['课程编号', '课程名称', '学分', '开设学期'].every(r.contains),
  );
  if (hi < 0) academicFail('培养方案缺少课程列');
  final columns = grid[hi];
  if (columns.toSet().length != columns.length || columns.any((c) => c.isEmpty))
    academicFail('培养方案列名重复或空白');
  final result = <AcademicJson>[];
  for (final row in grid.skip(hi + 1)) {
    final values = Map<String, String>.fromIterables(columns, row);
    if (row.every((v) => v.isEmpty)) continue;
    if (values['课程编号']!.isEmpty || values['课程名称']!.isEmpty)
      academicFail('培养方案课程缺少编号或名称');
    _decimal(values['学分']);
    if (!values['课程名称']!.toLowerCase().contains(courseName.toLowerCase()))
      continue;
    if (termID.isNotEmpty &&
        !values['开设学期']!.split(RegExp(r'[,，、\s]+')).contains(termID))
      continue;
    result.add(academicRow(values['课程名称']!, values));
  }
  // Keep non-course prose/tables available as ordinary rows for the generic UI.
  final summary = root.clone(true);
  summary
      .querySelectorAll('table#mxh, script, style, input, select, button')
      .forEach((e) => e.remove());
  final body = academicText(summary);
  return {
    'rows': [
      if (body.isNotEmpty)
        academicRow(academicText(captions.single), {'培养方案': body}),
      ...result,
    ],
    'controls': [
      {
        'key': 'courseName',
        'label': '课程名称',
        'type': 'text',
        'value': courseName,
        'options': <AcademicJson>[],
      },
      {
        'key': 'termID',
        'label': '开设学期',
        'type': 'text',
        'value': termID,
        'options': <AcademicJson>[],
      },
    ],
  };
}

bool isAcademicWordTrainingPlan(Document document, String source) {
  final marker = source.toLowerCase();
  if (!marker.contains('<pstyle=') && !marker.contains('msonormal'))
    return false;
  final text = academicText(document).replaceAll(RegExp(r'\s'), '');
  return document.querySelector('table') != null &&
      ['培养方案', '课程编号', '课程名称', '学分', '开设学期'].every(text.contains);
}

AcademicJson _wordTrainingPlan(
  Document document,
  String source, {
  required String courseName,
  required String termID,
}) {
  if (!isAcademicWordTrainingPlan(document, source)) academicFail('未找到培养方案正文');
  if (courseName.isNotEmpty || termID.isNotEmpty) {
    academicFail('学校文档版培养方案提供完整正文，暂不支持课程筛选', 'unsupported_form');
  }
  final blocks = <AcademicJson>[];
  var pending = StringBuffer();
  void flush() {
    final text = pending.toString().replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (text.isNotEmpty) blocks.add({'type': 'paragraph', 'text': text});
    pending = StringBuffer();
  }

  for (final table in document.querySelectorAll('table')) {
    var nested = 0;
    for (var parent = table.parent; parent != null; parent = parent.parent) {
      if (parent.localName == 'table') nested++;
    }
    if (nested > 16) academicFail('培养方案嵌套过深', 'content_too_large');
  }
  var visited = 0;
  // Word's broken span tags may form deep inline trees. Walk iteratively;
  // bound total nodes and nested tables instead of rejecting harmless spans.
  final stack = <(Node, bool)>[(document.body!, false)];
  while (stack.isNotEmpty) {
    final (node, exit) = stack.removeLast();
    if (exit) {
      flush();
      continue;
    }
    if (++visited > 262144) academicFail('培养方案内容过大', 'content_too_large');
    if (node is Text) {
      pending.write(node.data.replaceAll(RegExp(r'\s+'), ' '));
      continue;
    }
    if (node is! Element) continue;
    final tag = node.localName ?? '';
    if ([
      'script',
      'style',
      'noscript',
      'iframe',
      'input',
      'button',
      'select',
      'textarea',
      'object',
      'embed',
    ].contains(tag))
      continue;
    if (tag == 'table') {
      flush();
      final grid = academicTableGrid(node);
      blocks.add({
        'type': 'table',
        'grid': grid,
        'text': grid.map((r) => r.join('\t')).join('\n'),
      });
      continue;
    }
    final boundary =
        tag.startsWith('pstyle=') ||
        [
          'p',
          'div',
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
          'br',
          'blockquote',
        ].contains(tag);
    if (boundary) {
      flush();
      stack.add((node, true));
    }
    if (tag == 'img') pending.write(node.attributes['alt'] ?? '');
    for (final child in node.nodes.reversed) {
      stack.add((child, false));
    }
  }
  flush();
  final paragraphs = blocks.where(
    (b) => b['type'] == 'paragraph' && b['text'].toString().contains('培养方案'),
  );
  final title = paragraphs.isEmpty
      ? '培养方案'
      : paragraphs.first['text'].toString();
  return {
    'title': title.length <= 160 ? title : '培养方案',
    'body': blocks.map((b) => b['text']).join('\n\n'),
    'blocks': blocks,
    'rows': <AcademicJson>[],
    'controls': <AcademicJson>[],
  };
}
