import 'dart:convert';

import 'package:html/parser.dart' as html;

import 'academic_parsers.dart';
import 'transport.dart';

class AcademicQueries {
  AcademicQueries(this.http);
  final SchoolTransport http;
  static final _base = Uri.parse('https://bkjx.wust.edu.cn');
  static const _schedule = '/jsxsd/xskb/xskb_list.do';
  static const _plan = '/jsxsd/pyfa/topyfamx';

  Future<Map<String, dynamic>> query(
    String resource, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      switch (resource) {
        case 'schedule':
        case 'raw-schedule':
          return await _timetable(resource, options);
        case 'grades':
          return await _grades(options);
        case 'exams':
          return await _exams(options);
        case 'student':
          return parseAcademicStudent((await _page('/jsxsd/grxx/xsxx')).text);
        case 'credits':
          return parseAcademicCredits(
            (await _page('/jsxsd/xxwcqk/xxwcqk_idxOnzh.do')).text,
          );
        case 'calendar':
          final reference = options['date'] == null
              ? DateTime.now().toUtc().add(const Duration(hours: 8))
              : parseAcademicDate(options['date'].toString());
          final day = DateTime.utc(
            reference.year,
            reference.month,
            reference.day,
          );
          final requestValue =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          final response = await _page(
            '/jsxsd/framework/main_index_loadkb.jsp',
            form: {'rq': requestValue},
          );
          return parseAcademicCalendar(response.text, referenceDate: day);
        case 'training-plan':
          return await _trainingPlan(options);
        default:
          throw FoundationException(
            'unsupported_resource',
            '不支持的教务查询：$resource',
          );
      }
    } on AcademicParseException catch (error) {
      throw FoundationException(error.code, error.message);
    }
  }

  Future<SchoolResponse> _page(
    String path, {
    Map<String, String>? form,
    AcademicForm? sourceForm,
    Uri? uri,
    Uri? referer,
  }) async {
    final request = uri ?? _base.resolve(path);
    if (request.scheme != 'https' ||
        request.origin != _base.origin ||
        request.userInfo.isNotEmpty ||
        request.hasFragment ||
        !request.path.startsWith('/jsxsd/')) {
      throw FoundationException('invalid_query', '教务地址不符合预期');
    }
    final response = await http.send(
      request,
      method: form == null ? 'GET' : 'POST',
      form: sourceForm == null ? form : null,
      formFields: sourceForm != null && form != null
          ? sourceForm.submission(form)
          : null,
      headers: {
        'Accept': 'text/html',
        if (referer != null) 'Referer': referer.toString(),
      },
    );
    final String source;
    try {
      source = utf8.decode(response.bytes);
    } on FormatException {
      throw FoundationException('invalid_encoding', '教务页面不是有效 UTF-8');
    }
    final doc = html.parse(source);
    if (response.status == 401 ||
        [
          'auth.wust.edu.cn',
          'atrust.wust.edu.cn',
        ].contains(response.uri.host) ||
        response.uri.path.contains('/login') ||
        RegExp(r'登录|统一身份认证').hasMatch(doc.querySelector('title')?.text ?? '') ||
        doc.querySelector('input[type="password"]') != null) {
      throw FoundationException(
        'authentication_required',
        '教务会话已失效，请重新登录',
        status: response.status,
      );
    }
    if (response.status != 200) {
      throw FoundationException(
        'unexpected_status',
        '教务请求失败（HTTP ${response.status}）',
        status: response.status,
      );
    }
    if (response.uri.scheme != request.scheme ||
        response.uri.origin != request.origin ||
        response.uri.path != request.path ||
        response.uri.userInfo.isNotEmpty) {
      throw FoundationException('unexpected_redirect', '教务请求转到了非预期页面');
    }
    return response;
  }

  List<AcademicJson> _controls(
    AcademicForm form,
    Map<String, String> labels,
    Map<String, String> values,
  ) => [
    for (final control in form.controls)
      if (labels.containsKey(control['key']))
        {
          ...control,
          'key':
              const {
                'xnxq01id': 'termID',
                'zc': 'week',
                'kbjcmsid': 'templateID',
                'kksj': 'termID',
                'kcxz': 'courseNatureID',
                'kcmc': 'courseName',
                'xsfs': 'displayMode',
                'xnxqid': 'termID',
                'xqlb': 'categoryID',
              }[control['key']] ??
              control['key'],
          'label': labels[control['key']],
          'value': values[control['key']] ?? control['value'],
        },
  ];

  Future<AcademicJson> _timetable(String resource, AcademicJson options) async {
    final entry = await _page(_schedule);
    final form = parseAcademicForm(entry.text, entry.uri, id: 'Form1');
    final term = form.choose('xnxq01id', options['termID'], nonempty: true);
    final template =
        options['templateID']?.toString() ?? form.fields['kbjcmsid'];
    if (template == null || template.isEmpty)
      academicFail('课表模板字段缺失', 'unsupported_form');
    if (options.containsKey('templateID'))
      form.choose('kbjcmsid', template, nonempty: true);
    if (resource == 'raw-schedule') {
      form.choose('zc', '');
      form.choose('kbjcmsid', template, nonempty: true);
      _gridText(entry.text);
    }
    final fields = {
      ...form.fields,
      'xnxq01id': term,
      'zc': '',
      'kbjcmsid': template,
    };
    final semester = await _page(
      _schedule,
      uri: form.action,
      form: fields,
      sourceForm: form,
      referer: entry.uri,
    );
    var returned = parseAcademicForm(semester.text, semester.uri, id: 'Form1');
    _reflect(returned, {'xnxq01id': term, 'zc': '', 'kbjcmsid': template});
    returned.choose('xnxq01id', term, nonempty: true);
    final controls = _controls(form, {
      'xnxq01id': '学年学期',
      'zc': '周次',
      'kbjcmsid': '课表模板',
    }, fields);
    if (resource == 'schedule') {
      return {
        ...parseAcademicSchedule(semester.text, termID: term),
        'controls': controls.where((c) => c['key'] != 'week').toList(),
      };
    }
    final files = <AcademicJson>[
      _file('entry.html', entry),
      _file('semester.html', semester),
    ];
    final week = options['week']?.toString() ?? '';
    String? changed;
    if (week.isNotEmpty) {
      form.choose('zc', week);
      final weeklyFields = {
        ...returned.fields,
        'xnxq01id': term,
        'zc': week,
        'kbjcmsid': template,
      };
      final weekly = await _page(
        _schedule,
        uri: returned.action,
        form: weeklyFields,
        sourceForm: returned,
        referer: semester.uri,
      );
      final weeklyForm = parseAcademicForm(
        weekly.text,
        weekly.uri,
        id: 'Form1',
      );
      _reflect(weeklyForm, {
        'xnxq01id': term,
        'zc': week,
        'kbjcmsid': template,
      });
      changed = _gridText(semester.text) == _gridText(weekly.text) ? '否' : '是';
      files.add(_file('week.html', weekly));
    }
    _gridText(entry.text);
    _gridText(semester.text);
    return {
      'rows': [
        academicRow('原始课表采集', {
          '学年学期': term,
          '周次': week,
          '课表模板': template,
          'HTML 文件数': '${files.length}',
          if (changed != null) '周课表内容变化': changed,
        }),
      ],
      'controls': [
        for (final control in controls)
          {...control, if (control['key'] == 'week') 'value': week},
      ],
      'files': files,
    };
  }

  String _gridText(String source) {
    final document = html.parse(source);
    final tables = document.querySelectorAll('table#kbtable');
    if (tables.length != 1) academicFail('原始课表缺少表格');
    return tables.single
        .querySelectorAll('.kbcontent:not(.sykb2)')
        .map(academicText)
        .join('\u001f');
  }

  AcademicJson _file(String name, SchoolResponse response) => {
    'name': name,
    'mime': 'text/html; charset=utf-8',
    'base64': base64Encode(response.bytes),
  };

  void _reflect(AcademicForm returned, Map<String, String> expected) {
    for (final e in expected.entries) {
      if (returned.fields[e.key] != e.value)
        academicFail('学校未回显所选字段：${e.key}', 'selection_not_reflected');
    }
  }

  Future<AcademicJson> _grades(AcademicJson options) async {
    final entry = await _page('/jsxsd/kscj/cjcx_query');
    final form = parseAcademicForm(
      entry.text,
      entry.uri,
      id: 'kscjQueryForm',
      actionPath: '/jsxsd/kscj/cjcx_list',
      allowScriptAction: true,
    );
    for (final name in ['kksj', 'kcxz', 'kcmc', 'xsfs', 'sfxsbcxq']) {
      final controls = form.element.querySelectorAll('[name="$name"]');
      if (controls.length != 1 ||
          controls.single.attributes.containsKey('disabled'))
        academicFail('成绩表单缺少查询控件：$name', 'unsupported_form');
    }
    final checkbox = form.element.querySelector('[name="sfxsbcxq"]')!;
    if (checkbox.localName != 'input' ||
        checkbox.attributes['type']?.toLowerCase() != 'checkbox' ||
        checkbox.attributes['value'] != '1') {
      academicFail('成绩重修控件不受支持', 'unsupported_form');
    }
    final term = form.choose('kksj', options['termID'] ?? '');
    final nature = form.choose('kcxz', options['courseNatureID'] ?? '');
    final display = form.choose('xsfs', options['displayMode'] ?? 'all');
    final fields = {
      ...form.fields,
      'kksj': term,
      'kcxz': nature,
      'kcmc': options['courseName']?.toString() ?? '',
      'xsfs': display,
    };
    fields.remove('sfxsbcxq');
    if (options['includesRetakes'] != false) fields['sfxsbcxq'] = '1';
    final response = await _page(
      form.action.path,
      uri: form.action,
      form: fields,
      sourceForm: form,
      referer: entry.uri,
    );
    return {
      ...parseAcademicGrades(response.text, termID: term),
      'controls': _controls(form, {
        'kksj': '开课学期',
        'kcxz': '课程性质',
        'kcmc': '课程名称',
        'xsfs': '显示方式',
      }, fields),
    };
  }

  Future<AcademicJson> _exams(AcademicJson options) async {
    final entry = await _page('/jsxsd/xsks/xsksap_query');
    final form = parseAcademicForm(
      entry.text,
      entry.uri,
      id: 'ksapQueryForm',
      actionPath: '/jsxsd/xsks/xsksap_list',
      allowScriptAction: true,
    );
    for (final input in form.element.querySelectorAll('input, textarea')) {
      if (input.attributes.containsKey('disabled')) continue;
      final type = input.attributes['type']?.toLowerCase();
      if (input.localName != 'input' ||
          !['hidden', 'submit', 'button', 'reset', 'image'].contains(type))
        academicFail('考试表单含不受支持的输入控件', 'unsupported_form');
    }
    if (!form.fields.containsKey('xqlbmc'))
      academicFail('考试表单缺少类别名称', 'unsupported_form');
    final term = form.choose('xnxqid', options['termID'], nonempty: true);
    final categories = form.options('xqlb');
    final all = categories
        .where((choice) => choice['label'].toString().startsWith('全部'))
        .firstOrNull;
    final category = form.choose(
      'xqlb',
      options['categoryID'] ?? all?['value'],
    );
    final label = category.isEmpty
        ? form.fields['xqlbmc']!
        : categories.firstWhere((o) => o['value'] == category)['label']
              as String;
    final fields = {
      ...form.fields,
      'xnxqid': term,
      'xqlb': category,
      'xqlbmc': label,
    };
    final response = await _page(
      form.action.path,
      uri: form.action,
      form: fields,
      sourceForm: form,
      referer: entry.uri,
    );
    return {
      ...parseAcademicExams(response.text, termID: term),
      'controls': _controls(form, {'xnxqid': '学年学期', 'xqlb': '考试类别'}, fields),
    };
  }

  Future<AcademicJson> _trainingPlan(AcademicJson options) async {
    var response = await _page(_plan);
    var document = html.parse(response.text);
    final directory = <AcademicJson>[];
    for (final link in document.querySelectorAll('a[href]')) {
      final target = response.uri.resolve(link.attributes['href']!);
      if (_planUri(target) && academicText(link).isNotEmpty) {
        directory.add({
          'label': academicText(link),
          'resource': 'training-plan',
          'options': {'planHref': target.toString()},
        });
      }
    }
    if (options['planHref'] != null) {
      final selected = options['planHref'].toString();
      if (!directory.any((a) => (a['options'] as Map)['planHref'] == selected))
        academicFail('培养方案链接不在学校目录中', 'invalid_query');
      response = await _page(
        '',
        uri: Uri.parse(selected),
        referer: response.uri,
      );
      document = html.parse(response.text);
    }
    final forms = document
        .querySelectorAll('form')
        .where((f) => f.querySelector('select') != null)
        .toList();
    List<AcademicJson> controls = [];
    if (forms.isNotEmpty) {
      if (forms.length != 1 || (forms.single.id).isEmpty)
        academicFail('培养方案表单结构不明确', 'unsupported_form');
      final formElement = forms.single;
      final target = response.uri.resolve(
        formElement.attributes['action'] ?? '',
      );
      if (!_planUri(target) || target.hasQuery)
        academicFail('培养方案提交地址不符合预期', 'unsupported_form');
      final form = parseAcademicForm(
        response.text,
        response.uri,
        id: formElement.id,
        actionPath: target.path,
      );
      controls = form.controls;
      final topLevel = {
        for (final control in controls)
          if (options.containsKey(control['key']))
            control['key']: options[control['key']],
      };
      final requested =
          options['fields'] ?? (topLevel.isEmpty ? null : topLevel);
      if (requested != null) {
        if (requested is! Map) academicFail('培养方案筛选参数必须为字段对象', 'invalid_query');
        final fields = {...form.fields};
        for (final e in requested.entries) {
          final key = e.key.toString();
          final visible = controls.where((c) => c['key'] == key).toList();
          if (visible.length != 1)
            academicFail('不可覆盖隐藏或未知字段：$key', 'invalid_query');
          fields[key] = visible.single['type'] == 'select'
              ? form.choose(key, e.value)
              : e.value.toString();
        }
        final original = response;
        response = await _page(
          target.path,
          uri: target,
          form: fields,
          sourceForm: form,
          referer: original.uri,
        );
        document = html.parse(response.text);
        final returned = parseAcademicForm(
          response.text,
          response.uri,
          id: formElement.id,
          actionPath: target.path,
        );
        _reflect(returned, {
          for (final e in requested.entries)
            e.key.toString(): e.value.toString(),
        });
        controls = returned.controls;
      }
    }
    if (document.querySelector('#dataList table#mxh') != null ||
        isAcademicWordTrainingPlan(document, response.text)) {
      final result = parseAcademicTrainingPlan(
        response.text,
        courseName: options['courseName']?.toString() ?? '',
        termID: options['termID']?.toString() ?? '',
      );
      return {
        ...result,
        'controls': [...controls, ...result['controls'] as List],
        if (directory.isNotEmpty) 'actions': directory,
      };
    }
    if (directory.isEmpty && controls.isEmpty)
      academicFail('未找到培养方案正文、目录或查询表单');
    return {
      'rows': <AcademicJson>[],
      'controls': controls,
      'actions': directory,
    };
  }

  bool _planUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.origin == _base.origin &&
      uri.userInfo.isEmpty &&
      !uri.hasFragment &&
      uri.path.startsWith('/jsxsd/pyfa/') &&
      !uri.path.contains('..') &&
      !uri.path.contains('%');
}
