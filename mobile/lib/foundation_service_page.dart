import 'school_operation_status.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import 'academic.dart';
import 'archive_motion.dart';
import 'blog_surface.dart';
import 'campus_service_views.dart';
import 'countdown.dart';
import 'delayed_loading.dart';
import 'exam_schedule.dart';
import 'foundation/campus_parsers.dart' show isNoticeArticle, isUniversityURL;
import 'foundation/client.dart';
import 'foundation/progress.dart';
import 'major_progress.dart';
import 'wiki_page.dart';

enum _SchoolService {
  library(
    'library',
    '打开我的图书馆',
    'https://libsys.wust.edu.cn/space/reader/readerHome',
  ),
  shuttle('shuttle', '打开学校信息门户', 'https://portal.wust.edu.cn/'),
  secondClass(
    'second-class',
    '打开学校第二课堂',
    'https://xg.wust.edu.cn/xsfw/sys/dektapp/*default/index.do',
  );

  const _SchoolService(this.key, this.button, this.url);
  final String key, button, url;
}

/// Renders the inner result returned by AcademicStore.queryService.
///
/// The store's cancellation is global. Only an in-flight query owned by this
/// page is cancelled on dispose; an idle parent never cancels its child page.
class FoundationServicePage extends StatefulWidget {
  const FoundationServicePage({
    required this.store,
    required this.resource,
    required this.title,
    this.options = const {},
    this.mark,
    super.key,
  });

  final AcademicStore store;
  final String resource, title;
  final WikiPageMark? mark;
  final Map<String, dynamic> options;

  @override
  State<FoundationServicePage> createState() => _FoundationServicePageState();
}

class _FoundationServicePageState extends State<FoundationServicePage> {
  late String _resource = widget.resource, _title = widget.title;
  late Json _options = _withoutSecrets(widget.options);
  Json? _result;
  final _inputs = <String, TextEditingController>{};
  final _secretKeys = <String>{};
  String? _error, _fileError;
  bool _requiresSchoolLogin = false;
  _SchoolService? _schoolLink;
  Uri? _noticeLogin;
  (String, Json)? _retry;
  bool _busy = false, _confirming = false, _childOpen = false;
  FoundationProgress? _waiting;
  String? _fileBusy;
  int _run = 0, _revision = 0;

  bool get _locked =>
      _busy ||
      _confirming ||
      _childOpen ||
      _fileBusy != null ||
      (_laundryHome && !widget.store.initialized && widget.options.isEmpty);
  bool get _laundryHome => widget.resource == 'laundry-shops';
  bool get _laundryAccountRoute =>
      const {'laundry-orders', 'laundry-order'}.contains(widget.resource);
  bool get _showLaundryLogin =>
      _laundryAccountRoute &&
      const {'laundry', 'laundry-sms', 'laundry-login'}.contains(_resource);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_laundryHome && widget.options.isEmpty) {
        await widget.store.init();
        if (!mounted) return;
        final shop = widget.store.laundryShop;
        if (shop != null) {
          _showLaundry('laundry-devices', {
            'shopId': shop.id,
            'shopName': shop.name,
          });
          return;
        }
      }
      if (mounted) _query(widget.resource, Map.of(widget.options));
    });
  }

  void _showLaundry(String resource, Json options) {
    if (_locked) return;
    setState(() {
      _resource = resource;
      _options = options;
      _title = resource == 'laundry-devices' ? '空闲洗衣机' : '洗衣机';
      _result = null;
    });
    _query(resource, options);
  }

  static bool _sensitive(String key) => RegExp(
    r'password|passwd|pwd|sms.?code|verify|token|secret|验证码|密码|口令',
    caseSensitive: false,
  ).hasMatch(key);

  static Json _withoutSecrets(Json options, [Set<String> keys = const {}]) => {
    for (final entry in options.entries)
      if (!_sensitive(entry.key) && !keys.contains(entry.key))
        entry.key: entry.value is Map
            ? _withoutSecrets(_map(entry.value), keys)
            : entry.value,
  };

  Json _rememberable(String resource, Json options) {
    final safe = _withoutSecrets(options, _secretKeys);
    if (resource == 'laundry-sms' || resource == 'laundry-login') {
      safe.remove('action');
    }
    return safe;
  }

  static Json _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Json> _records(Object? value) =>
      value is List ? value.map((item) => _map(item)).toList() : <Json>[];

  static String _text(Object? value) => value == null
      ? ''
      : value is String
      ? value
      : value is Map || value is List
      ? jsonEncode(value)
      : '$value';

  static String _htmlText(String source) {
    final fragment = html.parseFragment(source);
    for (final node in fragment.querySelectorAll(
      'script,style,noscript,template',
    )) {
      node.remove();
    }
    final out = StringBuffer();
    void visit(dom.Node node) {
      if (node is dom.Text) {
        out.write(node.text);
      } else {
        final tag = node is dom.Element ? node.localName : '';
        final block = const {
          'p',
          'div',
          'section',
          'article',
          'li',
          'tr',
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
          'blockquote',
          'pre',
          'br',
        }.contains(tag);
        if (block) out.write('\n');
        for (final child in node.nodes) {
          visit(child);
        }
        if (tag == 'td' || tag == 'th') out.write('  ');
        if (node is dom.Element && tag == 'a') {
          final href = node.attributes['href'];
          if (href != null && href != node.text) out.write(' ($href)');
        }
        if (block) out.write('\n');
      }
    }

    visit(fragment);
    return out.toString().replaceAll(RegExp(r'\n[ \t]*\n+'), '\n\n').trim();
  }

  static String _body(Json result) {
    for (final key in ['body', 'text', 'html']) {
      final value = result[key];
      if (value is String && value.trim().isNotEmpty) {
        return key == 'html' || RegExp(r'<[a-zA-Z][^>]*>').hasMatch(value)
            ? _htmlText(value)
            : value;
      }
      if (value is Map) {
        final nested = _body(_map(value));
        if (nested.isNotEmpty) return nested;
      }
    }
    final detail = _map(result['detail']);
    if (detail.isNotEmpty) {
      final body = _body(detail);
      if (body.isNotEmpty) return body;
      if (detail['paragraphs'] is List) {
        return (detail['paragraphs'] as List).map(_text).join('\n\n');
      }
    }
    return '';
  }

  List<Json> _rows(Json result) {
    if (result['rows'] is List) return _records(result['rows']);
    if (result['fields'] is List) {
      return [
        {'title': result['title'] ?? _title, 'fields': result['fields']},
      ];
    }
    final items = result['courses'] ?? result['lessons'];
    if (items is! List) return [];
    return _records(items)
        .map(
          (item) => <String, dynamic>{
            'title': item['name'] ?? _title,
            'fields':
                item['fields'] ??
                [
                  for (final entry in item.entries)
                    if (entry.key != 'name')
                      {'name': entry.key, 'value': _text(entry.value)},
                ],
          },
        )
        .toList();
  }

  void _validate(Json result) {
    if (![
      'rows',
      'fields',
      'courses',
      'lessons',
      'body',
      'html',
      'text',
      'detail',
      'controls',
      'actions',
      'files',
      'message',
    ].any(result.containsKey)) {
      throw const FormatException('服务没有返回可识别的内容。');
    }
    for (final key in [
      'rows',
      'fields',
      'courses',
      'lessons',
      'controls',
      'actions',
      'files',
    ]) {
      if (result.containsKey(key) &&
          (result[key] is! List ||
              (result[key] as List).any((item) => item is! Map))) {
        throw const FormatException('服务返回的数据结构无效。');
      }
    }
    final keys = <String>{};
    for (final control in _records(result['controls'])) {
      final key = _text(control['key']);
      if (key.isEmpty ||
          !keys.add(key) ||
          !['text', 'password', 'select'].contains(control['type'] ?? 'text')) {
        throw const FormatException('服务返回了无法使用的查询控件。');
      }
      if (control['type'] == 'select') {
        final choices = _records(control['options']);
        final values = choices.map((choice) => _text(choice['value'])).toList();
        final selected = control['value'];
        if (choices.isEmpty ||
            values.toSet().length != values.length ||
            (selected != null && !values.contains(_text(selected)))) {
          throw const FormatException('服务返回的默认选项无效。');
        }
      }
    }
    for (final row in _rows(result)) {
      if (row['fields'] != null &&
          (row['fields'] is! List ||
              (row['fields'] as List).any((field) => field is! Map))) {
        throw const FormatException('服务返回的记录字段无效。');
      }
    }
  }

  static Object? _redact(
    Object? value,
    List<String> secrets, [
    Set<String> keys = const {},
  ]) {
    if (value is String) {
      for (final secret in secrets) {
        if (secret.isNotEmpty)
          value = (value as String).replaceAll(secret, '••••');
      }
      return value;
    }
    if (value is List)
      return value.map((v) => _redact(v, secrets, keys)).toList();
    if (value is Map) {
      final map = _map(value);
      final sensitiveField = _sensitive(_text(map['name']));
      final sensitiveControl =
          map['type'] == 'password' ||
          _sensitive(_text(map['key'])) ||
          (map.containsKey('key') && _sensitive(_text(map['label'])));
      return <String, dynamic>{
        for (final entry in map.entries)
          if (!_sensitive(entry.key) && !keys.contains(entry.key))
            entry.key:
                entry.key == 'value' && (sensitiveField || sensitiveControl)
                ? ''
                : const {
                    'key',
                    'type',
                    'resource',
                    'mime',
                    'base64',
                  }.contains(entry.key)
                ? entry.value
                : entry.key == 'options' && entry.value is Map
                ? _withoutSecrets(_map(entry.value), keys)
                : _redact(entry.value, secrets, keys),
      };
    }
    return value;
  }

  void _clearSecrets() {
    for (final key in _secretKeys) {
      _inputs[key]?.clear();
    }
  }

  Future<void> _query(String resource, Json options) async {
    if (!mounted || _locked) return;
    if (resource == 'laundry-sms' && options['action'] == 'send') {
      setState(() => _confirming = true);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('发送登录短信？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认发送'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _confirming = false);
      if (confirmed != true) return;
    }
    final run = ++_run;
    final remembered = _rememberable(resource, options);
    final secrets = <String>[
      for (final entry in options.entries)
        if ((_sensitive(entry.key) || _secretKeys.contains(entry.key)) &&
            entry.value is String)
          entry.value as String,
    ];
    (String, Json)? laundryNext;
    _clearSecrets();
    setState(() {
      _busy = true;
      _waiting = FoundationProgress(
        message: switch (resource) {
          'laundry-sms' => '正在发送验证码',
          'laundry-login' when options['action'] == 'login' => '正在登录胖乖',
          'laundry-orders' || 'laundry-order' => '正在查询洗衣订单',
          _ => '正在查询${schoolResourceLabel(resource)}',
        },
        resource: resource,
        startedAt: DateTime.now(),
        activeCount: 1,
      );
      _error = null;
      _requiresSchoolLogin = false;
      _schoolLink = null;
      _noticeLogin = null;
      _fileError = null;
      _retry = (resource, remembered);
    });
    try {
      final result = await widget.store.queryService(
        resource,
        options: options,
      );
      if (!mounted || run != _run) return;
      _validate(result);
      final safe = _map(_redact(result, secrets, _secretKeys));
      _validate(safe);
      for (final input in _inputs.values) {
        input.dispose();
      }
      _inputs.clear();
      _secretKeys.clear();
      for (final control in _records(safe['controls'])) {
        final key = _text(control['key']);
        final secret =
            control['type'] == 'password' ||
            _sensitive(key) ||
            _sensitive(_text(control['label']));
        if (secret) _secretKeys.add(key);
        final choices = _records(control['options']);
        _inputs[key] = TextEditingController(
          text: secret
              ? ''
              : _text(
                  control['value'] ??
                      (choices.isEmpty ? '' : choices.first['value']),
                ),
        );
      }
      setState(() {
        _resource = resource;
        _options = _withoutSecrets(remembered, _secretKeys);
        _result = safe;
        _title = switch (resource) {
          'laundry-devices' when safe['availableDevices'] is List => '空闲洗衣机',
          'laundry-shops' when safe['shops'] is List => '洗衣机',
          'laundry-orders' => '我的洗衣',
          'laundry-order' => '洗衣订单详情',
          'laundry' ||
          'laundry-sms' ||
          'laundry-login' when _laundryAccountRoute => '胖乖登录',
          _ => _text(safe['title']).isEmpty ? _title : _text(safe['title']),
        };
        _retry = null;
        _revision++;
      });
      if (_laundryAccountRoute && resource == 'laundry-login') {
        laundryNext = switch (options['action']) {
          'login' => ('laundry-orders', <String, dynamic>{}),
          'clear' => ('laundry', <String, dynamic>{}),
          _ => null,
        };
      }
    } catch (error) {
      if (!mounted || run != _run) return;
      final message = error is FormatException
          ? error.message.toString()
          : '查询未完成，请重试。';
      final link =
          error is AcademicApiException &&
              const {
                'tgt_required',
                'invalid_credential',
                'authentication_required',
              }.contains(error.code)
          ? _officialService(resource)
          : null;
      final code = error is AcademicApiException ? error.code : null;
      if (_laundryAccountRoute &&
          const {'laundry-order', 'laundry-orders'}.contains(resource) &&
          const {
            'laundry_login_required',
            'invalid_credential',
          }.contains(code)) {
        laundryNext = ('laundry', <String, dynamic>{});
        setState(() => _result = null);
      }
      final notice = code == 'authentication_required'
          ? _protectedNotice(resource, options)
          : null;
      setState(() {
        _requiresSchoolLogin =
            error is AcademicApiException &&
            const {
              'credentials_rejected',
              'login_required',
              'password_expired',
              'account_locked',
            }.contains(error.code);
        _error = switch (code) {
          _ when laundryNext != null => null,
          'invalid_phone_number' when resource.startsWith('laundry') =>
            '请输入正确的手机号',
          'invalid_sms_code' when resource.startsWith('laundry') => '请输入短信验证码',
          'captcha_required' when resource.startsWith('laundry') =>
            '请在胖乖完成验证后重试',
          'laundry_rejected_429' => '操作太频繁，请稍后重试',
          _ when resource == 'laundry-sms' => '验证码发送失败，请重试',
          _ when resource == 'laundry-login' && options['action'] == 'login' =>
            '登录失败，请核对手机号和验证码',
          _ when resource == 'laundry-orders' || resource == 'laundry-order' =>
            '订单加载失败',
          _ when resource.startsWith('laundry') => '洗衣服务暂时无法加载',
          'credentials_rejected' => '账号或密码错误，请修改后重新登录',
          'password_expired' => '统一认证密码已过期，请修改后重新登录',
          _ when notice != null => '此通知需登录后查看',
          _ => link == null ? _text(_redact(message, secrets)) : '此服务需要学校授权',
        };
        _schoolLink = link;
        _noticeLogin = notice;
      });
    } finally {
      secrets.clear();
      if (mounted && run == _run)
        setState(() {
          _busy = false;
          _waiting = null;
        });
    }
    final next = laundryNext;
    if (mounted && run == _run && next != null) {
      await _query(next.$1, next.$2);
    }
  }

  Json _withInputs(Json base) {
    final values = {
      for (final entry in _inputs.entries) entry.key: entry.value.text,
    };
    return {
      ...base,
      ...values,
      if (base['fields'] is Map)
        'fields': {
          ..._map(base['fields']),
          for (final key in _map(base['fields']).keys)
            if (values.containsKey(key)) key: values[key],
        },
    };
  }

  Future<void> _refresh() => _query(_resource, {
    ..._withInputs(_options),
    if (_resource == 'laundry-order') 'refresh': true,
  });

  void _cancel() {
    if (!_busy) return;
    _run++;
    widget.store.cancelLocal();
    _clearSecrets();
    setState(() {
      _busy = false;
      _waiting = null;
      _error = '操作已取消';
    });
  }

  Future<void> _act(Json action, {bool row = false, String? title}) async {
    if (_locked) return;
    final target = _text(action['resource']);
    if (target.isEmpty) return;
    final fixed = _map(action['options']);
    final options = row
        ? fixed
        : {..._withInputs(target == _resource ? _options : {}), ...fixed};
    final hasSecret = options.entries.any(
      (e) =>
          (_sensitive(e.key) || _secretKeys.contains(e.key)) &&
          _text(e.value).isNotEmpty,
    );
    if (target == _resource ||
        hasSecret ||
        target == 'laundry-sms' ||
        target == 'laundry-login') {
      await _query(target, options);
      return;
    }
    _clearSecrets();
    setState(() => _childOpen = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => FoundationServicePage(
            store: widget.store,
            resource: target,
            title: title ?? _text(action['label']),
            options: options,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _childOpen = false);
    }
  }

  Future<void> _file(Json file, String operation) async {
    if (_locked) return;
    final name = _text(file['name']);
    setState(() {
      _fileBusy = name;
      _fileError = null;
    });
    try {
      if (name.isEmpty ||
          file['mime'] is! String ||
          file['base64'] is! String) {
        throw const FormatException('文件数据不完整。');
      }
      final response = await platform
          .invokeMapMethod<String, dynamic>('foundationCapability', {
            'operation': operation,
            'name': name,
            'mime': file['mime'],
            'base64': file['base64'],
          });
      if (!mounted) return;
      if (response?['cancelled'] == true) {
        setState(() => _fileError = '操作已取消，未确认文件已保存或打开。');
      } else if (response?['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(operation == 'openPdf' ? '已交给 PDF 阅读器。' : '文件已导出。'),
          ),
        );
      } else {
        setState(() => _fileError = '未确认文件操作完成，请重试。');
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _fileError = error is PlatformException && error.code == 'cancelled'
            ? '操作已取消，未确认文件已保存或打开。'
            : error is FormatException
            ? error.message.toString()
            : '文件操作未完成，请重试。',
      );
    } finally {
      if (mounted) setState(() => _fileBusy = null);
    }
  }

  @override
  void dispose() {
    _run++;
    if (_busy) widget.store.cancelLocal();
    for (final input in _inputs.values) {
      input.clear();
      input.dispose();
    }
    super.dispose();
  }

  Widget _panel(List<Widget> children, {bool highlighted = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: BlogPanel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
      quiet: !highlighted,
    ),
  );

  _SchoolService? _officialService(String resource) {
    if (resource == 'library' || resource.startsWith('library-')) {
      return _SchoolService.library;
    }
    return switch (resource) {
      'shuttle' => _SchoolService.shuttle,
      'second-class' => _SchoolService.secondClass,
      _ => null,
    };
  }

  Uri? _protectedNotice(String resource, Json options) {
    final address = switch (resource) {
      'notice-detail' => _text(options['url']),
      'notice-file' => _text(options['sourceURL']),
      _ => '',
    };
    final uri = Uri.tryParse(address);
    if (uri == null ||
        uri.scheme != 'https' ||
        !isUniversityURL(uri) ||
        !isNoticeArticle(uri))
      return null;
    return uri;
  }

  void _openSchoolPortal(Object entry, String address) {
    Navigator.of(context).push(
      WikiRoute(
        Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              IconButton(
                tooltip: '用系统浏览器打开',
                onPressed: () => _openSchoolInBrowser(address),
                icon: const Icon(Icons.open_in_browser),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: AndroidView(
              viewType: 'wiki/school-service',
              creationParams: entry,
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
        ),
        MediaQuery.disableAnimationsOf(context),
      ),
    );
  }

  Future<void> _openSchoolInBrowser(String address) async {
    bool? opened;
    try {
      opened = await platform.invokeMethod<bool>('external', address);
    } on PlatformException {
      opened = false;
    }
    if (mounted && opened != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开学校服务')));
    }
  }

  Widget _control(Json control, {VoidCallback? onSelect}) {
    final key = _text(control['key']), label = _text(control['label']);
    final input = _inputs[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: control['type'] == 'select'
          ? DropdownButtonFormField<String>(
              key: ValueKey('foundation-select-$key-$_revision'),
              initialValue: input.text,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                for (final choice in _records(control['options']))
                  DropdownMenuItem(
                    value: _text(choice['value']),
                    child: Text(_text(choice['label'])),
                  ),
              ],
              onChanged: _locked
                  ? null
                  : (value) {
                      if (value == null || value == input.text) return;
                      input.text = value;
                      onSelect?.call();
                    },
            )
          : TextField(
              key: ValueKey('foundation-input-$key'),
              controller: input,
              enabled: !_locked,
              obscureText: _secretKeys.contains(key),
              autocorrect: !_secretKeys.contains(key),
              enableSuggestions: !_secretKeys.contains(key),
              enableIMEPersonalizedLearning: !_secretKeys.contains(key),
              autofillHints: _secretKeys.contains(key)
                  ? const <String>[]
                  : null,
              keyboardType: key == 'phone'
                  ? TextInputType.phone
                  : key == 'page' || key == 'pageSize' || key == 'smsCode'
                  ? TextInputType.number
                  : TextInputType.text,
              decoration: InputDecoration(labelText: label),
            ),
    );
  }

  Widget _row(Json row) => _panel([
    Text(
      _text(row['title']).isEmpty ? _title : _text(row['title']),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
    for (final field in _records(row['fields']))
      if (!_sensitive(_text(field['name'])) && _text(field['value']).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText(
            '${_text(field['name'])}：${_text(field['value'])}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ),
    if (_body(row).isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SelectableText(_body(row)),
      ),
    if (row['action'] is Map)
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _locked
              ? null
              : () => _act(
                  _map(row['action']),
                  row: true,
                  title: _text(row['title']),
                ),
          icon: const Icon(Icons.chevron_right),
          label: Text(
            _text(_map(row['action'])['label']).isEmpty
                ? '查看详情'
                : _text(_map(row['action'])['label']),
          ),
        ),
      ),
  ]);

  Widget _noticeRow(Json row) {
    final action = _map(row['action']);
    if (_text(action['resource']) != 'notice-detail') return _row(row);
    final title = _text(row['title']);
    final date = _text(_map(action['options'])['publishedDate']);
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: date.isEmpty ? null : Text(date),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: _locked ? null : () => _act(action, row: true, title: title),
    );
  }

  Widget _examRow(Json row) {
    final exam = ScheduledExam.fromRow(row);
    final fields = exam.fields;
    final schedule = [
      if (fields['周次']?.isNotEmpty == true) '第 ${fields['周次']} 周',
      if (fields['星期']?.isNotEmpty == true) '星期 ${fields['星期']}',
      if (fields['节次']?.isNotEmpty == true) '${fields['节次']} 节',
      if (fields['课程编号']?.isNotEmpty == true) fields['课程编号']!,
    ].join(' · ');
    return _panel([
      Text(exam.name, style: Theme.of(context).textTheme.titleLarge),
      if (exam.time.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SelectableText(exam.time),
        ),
      if (exam.room.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SelectableText(exam.room),
        ),
      if (schedule.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(schedule)),
    ], highlighted: true);
  }

  Widget _shuttleSchedule(List<Json> departures) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final directions = <(String, String), List<Json>>{};
    for (final departure in departures) {
      final direction = (
        _text(departure['origin']),
        _text(departure['destination']),
      );
      (directions[direction] ??= []).add(departure);
    }
    return ContentReveal.sequence(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, entry) in directions.entries.indexed)
            ArchivePart.staggered(
              index,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BlogPanel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_bus_outlined,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${entry.key.$1} → ${entry.key.$2}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final departure in entry.value) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _text(departure['departureTime']),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colors.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_text(departure['operatingDays'])),
                                    if (_text(departure['route']).isNotEmpty)
                                      Text(
                                        _text(departure['route']),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      revision: _revision,
    );
  }

  List<Widget>? _campusSections(
    Json? result,
    List<Json> rows,
    List<Json> actions,
  ) {
    if (result == null) return null;
    final page = _map(result['page']);
    final pagination = actions
        .where((action) => const {'上一页', '下一页'}.contains(action['label']))
        .toList();
    Widget paging() => Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Wrap(
        spacing: 8,
        children: [
          for (final action in pagination)
            TextButton(
              onPressed: _locked ? null : () => _act(action),
              child: Text(_text(action['label'])),
            ),
        ],
      ),
    );
    if (_resource == 'library') {
      final circulation = _map(result['circulation']);
      if (circulation.isEmpty) return null;
      return [
        LibraryCirculation(
          current: _map(circulation['current']),
          dueSoon: _map(circulation['dueSoon']),
          onMore: (dueOnly) => _act({
            'label': dueOnly ? '即将到期' : '当前借阅',
            'resource': 'library-loans',
            'options': {'kind': dueOnly ? 'overdue' : 'current'},
          }),
        ),
      ];
    }
    if (_resource == 'library-profile' && result['statistics'] is Map) {
      return [LibraryAccount(_map(result['statistics']))];
    }
    if (_resource == 'library-loans' && page['items'] is List) {
      return [
        LibraryLoanList(
          _records(page['items']),
          empty: _options['kind'] == 'overdue' ? '暂无即将到期的图书' : '暂无借阅',
        ),
        if (pagination.isNotEmpty) paging(),
      ];
    }
    if (_resource == 'laundry-shops') {
      if (result['shops'] is! List) return [const Text('洗衣点加载失败')];
      return [
        if (_text(result['shopQueryArea']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _text(result['shopQueryArea']),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        LaundryShops(
          _records(result['shops']),
          onOpen: (index) {
            if (_locked || index >= rows.length) return;
            final options = _map(_map(rows[index]['action'])['options']);
            final id = _text(options['shopId']);
            final name = _text(options['shopName']);
            if (id.isEmpty || name.isEmpty) return;
            final last = widget.store.laundryShop;
            widget.store.rememberLaundryShop(
              id,
              name,
              filter: last != null && last.id == id ? last.filter : '',
            );
            _showLaundry('laundry-devices', options);
          },
        ),
        if (pagination.isNotEmpty) paging(),
      ];
    }
    if (_resource == 'laundry-devices') {
      if (result['availableDevices'] is! List) return [const Text('设备加载失败')];
      final shop = widget.store.laundryShop;
      final saved = _laundryHome && shop?.id == _options['shopId']
          ? shop
          : null;
      return [
        LaundryMachines(
          _records(result['availableDevices']),
          shopName: _text(result['title']),
          filter: saved?.filter ?? '',
          onFilterChanged: saved != null
              ? (filter) => widget.store.rememberLaundryShop(
                  saved.id,
                  saved.name,
                  filter: filter,
                )
              : null,
        ),
      ];
    }
    if (_resource == 'laundry-orders') {
      final running =
          _options['running'] == true || _options['running'] == 'true';
      return [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('全部订单')),
            ButtonSegment(value: true, label: Text('进行中')),
          ],
          selected: {running},
          onSelectionChanged: _locked
              ? null
              : (value) => _query('laundry-orders', {
                  if (value.single) 'running': true,
                }),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty) _panel([Text(running ? '暂无进行中的订单' : '暂无洗衣订单')]),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LaundryOrderCard(
              title: _text(row['title']),
              fields: _namedFields(row),
              onOpen: _locked || row['action'] is! Map
                  ? null
                  : () => _act(_map(row['action']), row: true, title: '洗衣订单详情'),
            ),
          ),
        if (pagination.isNotEmpty) paging(),
      ];
    }
    if (_resource == 'laundry-order') {
      final row = rows.firstOrNull;
      return [
        if (row == null)
          _panel([const Text('订单详情加载失败')])
        else
          LaundryOrderCard(
            title: _text(row['title']),
            fields: _namedFields(row),
            detail: true,
          ),
      ];
    }
    if (_showLaundryLogin) {
      return [
        _panel([
          for (final control in _records(result['controls'])) _control(control),
          if (_resource == 'laundry-sms' &&
              _error == null &&
              _text(result['message']).isNotEmpty)
            const Text('验证码已发送'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _locked
                      ? null
                      : () => _query(
                          'laundry-sms',
                          _withInputs({'action': 'send'}),
                        ),
                  child: const Text('发送验证码'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: _locked
                      ? null
                      : () => _query(
                          'laundry-login',
                          _withInputs({'action': 'login'}),
                        ),
                  child: const Text('登录'),
                ),
              ),
            ],
          ),
        ]),
      ];
    }
    return null;
  }

  static Map<String, String> _namedFields(Json row) => {
    for (final field in _records(row['fields']))
      if (_text(field['value']).isNotEmpty)
        _text(field['name']): _text(field['value']),
  };

  Widget _creditProgress(
    String title, {
    String earned = '',
    String required = '',
    String remaining = '',
    String detail = '',
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final a = double.tryParse(earned), b = double.tryParse(required);
    final progress = a != null && a.isFinite && b != null && b.isFinite && b > 0
        ? (a / b).clamp(0.0, 1.0)
        : null;
    return _panel([
      Text(title, style: theme.textTheme.titleMedium),
      if (earned.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          [
            if (a != null && b != null)
              '$earned / $required 学分'
            else ...[
              if (a != null) '已获 $earned 学分',
              if (b != null) '需修 $required 学分',
              if (a == null && b == null) '暂无学分数据',
            ],
          ].join(' · '),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.primary,
          ),
        ),
      ],
      if (progress != null) ...[
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
      if (double.tryParse(remaining) case final left?)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(left == 0 ? '已达标' : '还差 $remaining 学分'),
        ),
      if (detail.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(detail, style: TextStyle(color: colors.onSurfaceVariant)),
        ),
    ]);
  }

  List<Widget>? _studentSections(Json? result, List<Json> rows) {
    if (result == null) return null;
    if (_resource == 'student') {
      final fields = rows.isEmpty
          ? const <String, String>{}
          : _namedFields(rows.first);
      return [
        if (fields.isEmpty)
          const ListTile(title: Text('暂无学籍信息'))
        else
          BlogPanel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fields['姓名'] case final name?)
                  ListTile(
                    title: Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    subtitle: fields['学号'] == null
                        ? null
                        : Text('学号 ${fields['学号']}'),
                  ),
                for (final label in const [
                  '院系',
                  '专业',
                  '班级',
                  '出生日期',
                  '性别',
                  '民族',
                  '籍贯',
                ])
                  if (fields[label] case final value?) ...[
                    const Divider(height: 1, indent: 16),
                    ListTile(title: Text(value), subtitle: Text(label)),
                  ],
              ],
            ),
            padding: EdgeInsets.zero,
            quiet: true,
          ),
      ];
    }
    if (_resource == 'credits') {
      final fields = rows.map(_namedFields).toList();
      return [
        MajorProgress(
          statistics: fields
              .where((row) => row.containsKey('学期数') || row.containsKey('已修学分'))
              .firstOrNull,
          graduation: [
            for (final (index, row) in fields.indexed)
              if (row.containsKey('类别') &&
                  rows[index]['creditGroup'] != 'general-elective')
                row,
          ],
          generalEducation: [
            for (final (index, row) in fields.indexed)
              if (row.containsKey('类别') &&
                  rows[index]['creditGroup'] == 'general-elective')
                row,
          ],
          courses: fields.where((row) => row.containsKey('课程')).toList(),
        ),
      ];
    }
    if (_resource == 'second-class') {
      final transcript = _map(result['transcript']);
      if (transcript.isEmpty) {
        return [const ListTile(title: Text('暂无第二课堂成绩'))];
      }
      return [
        _creditProgress(
          '累计学分',
          earned: _text(transcript['earnedCredits']),
          detail: _text(transcript['evaluation']),
        ),
        for (final category in _records(transcript['categories']))
          _creditProgress(
            _text(category['name']),
            earned: _text(category['earnedCredits']),
            required: _text(category['requiredCredits']),
            detail: [
              for (final rule in _records(category['requirements']))
                '${rule['kind'] == 'required' ? '必修' : '选修'}${rule['isCompleted'] == true ? '已达标' : '还差 ${rule['remainingCredits']} 学分'}',
            ].join(' · '),
          ),
      ];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final rows = result == null ? <Json>[] : _rows(result);
    final controls = _records(result?['controls']);
    final actions = _records(result?['actions']);
    final campusSections = _campusSections(result, rows, actions);
    final studentSections = _studentSections(result, rows);
    final libraryMenu = _resource == 'library' && campusSections != null
        ? actions
              .where((action) => action['resource'] != 'library-loans')
              .toList()
        : const <Json>[];
    final notices = _resource == 'notices';
    final noticePage = _map(result?['page']);
    final schoolLink = _schoolLink;
    final noticeLogin = _noticeLogin;
    final currentPage = noticePage['currentPage'];
    final totalPages = noticePage['totalPages'];
    const paging = {'上一页', '下一页'};
    final sourceAction =
        notices &&
            controls.length == 1 &&
            controls.single['key'] == 'source' &&
            controls.single['type'] == 'select'
        ? actions.where((action) => action['label'] == '查询来源首页').firstOrNull
        : null;
    final pageActions = notices
        ? actions.where((action) => paging.contains(action['label']))
        : const <Json>[];
    final formActions = notices
        ? actions.where((action) => !paging.contains(action['label']))
        : actions.where(
            (action) =>
                _resource != 'laundry' || action['resource'] != 'laundry-shops',
          );
    final departures = _resource == 'shuttle'
        ? _records(_map(result?['schedule'])['departures'])
        : const <Json>[];
    final files = _records(result?['files']);
    final body = result == null ? '' : _body(result);
    final bodyInRows =
        body.isNotEmpty &&
        rows.any(
          (row) => _records(
            row['fields'],
          ).any((field) => _text(field['value']) == body),
        );
    return Scaffold(
      appBar: AppBar(
        title: WikiPageTitle(_title, mark: widget.mark),
        actions: [
          if (_resource == 'exams')
            IconButton(
              tooltip: '考试倒计时',
              onPressed: () => Navigator.of(context).push(
                WikiRoute(
                  CountdownPage(store: widget.store),
                  MediaQuery.disableAnimationsOf(context),
                ),
              ),
              icon: const Icon(Icons.timer_outlined),
            ),
          if (const {'laundry-shops', 'laundry-devices'}.contains(_resource))
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: _locked
                  ? null
                  : () => _act({'resource': 'laundry-orders', 'label': '我的洗衣'}),
              child: const Text('我的洗衣'),
            ),
          if (_laundryHome && _resource == 'laundry-devices')
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: _locked
                  ? null
                  : () => _showLaundry('laundry-shops', Map.of(widget.options)),
              child: const Text('更换地点'),
            ),
          if (_resource == 'laundry-orders' && result != null && _error == null)
            PopupMenuButton<String>(
              tooltip: '胖乖账号',
              enabled: !_locked,
              onSelected: (_) => _query('laundry-login', {'action': 'clear'}),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'logout', child: Text('退出胖乖账号')),
              ],
            ),
          if (libraryMenu.isNotEmpty)
            PopupMenuButton<Json>(
              tooltip: '更多图书馆服务',
              enabled: !_locked,
              onSelected: _act,
              itemBuilder: (_) => [
                for (final action in libraryMenu)
                  PopupMenuItem(
                    value: action,
                    child: Text(_text(action['label'])),
                  ),
              ],
            ),
          IconButton(
            tooltip: '刷新',
            onPressed: _locked || _requiresSchoolLogin ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        notificationPredicate: (notice) =>
            !_requiresSchoolLogin && notice.depth == 0,
        child: ListView(
          key: notices
              ? ValueKey((_options['source'], _options['url']))
              : _laundryHome
              ? ValueKey(_resource)
              : null,
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SchoolOperationStatus(
              widget.store.foundation,
              fallback: _waiting,
              cancelLabel: '取消查询',
              onCancel: _busy ? _cancel : null,
            ),
            if (_error != null)
              _panel([
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (_requiresSchoolLogin ||
                    (DartFoundationClient.academicResources.contains(
                          _resource,
                        ) &&
                        widget.store.token != 'local'))
                  TextButton(
                    onPressed: _locked
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    AcademicQuery(widget.store, 'login'),
                              ),
                            );
                            if (mounted && widget.store.unifiedVerified)
                              await _refresh();
                          },
                    child: const Text('学校统一认证'),
                  ),
                if (noticeLogin != null)
                  FilledButton.icon(
                    onPressed: _locked
                        ? null
                        : () => _openSchoolPortal({
                            'notice': noticeLogin.toString(),
                          }, noticeLogin.toString()),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('登录查看原文'),
                  )
                else if (schoolLink != null)
                  FilledButton.icon(
                    onPressed: _locked
                        ? null
                        : () =>
                              _openSchoolPortal(schoolLink.key, schoolLink.url),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(schoolLink.button),
                  )
                else if (!_requiresSchoolLogin && !_showLaundryLogin)
                  TextButton(
                    onPressed: _locked
                        ? null
                        : () {
                            final retry = _retry;
                            if (retry != null) {
                              _query(retry.$1, retry.$2);
                            } else {
                              _refresh();
                            }
                          },
                    child: const Text('重试查询'),
                  ),
              ]),
            if (sourceAction != null)
              _control(controls.single, onSelect: () => _act(sourceAction))
            else if (campusSections == null &&
                studentSections == null &&
                (controls.isNotEmpty || formActions.isNotEmpty))
              _panel([
                for (final control in controls) _control(control),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (controls.isNotEmpty && actions.isEmpty)
                      FilledButton(
                        onPressed: _locked ? null : _refresh,
                        child: const Text('查询'),
                      ),
                    for (final action in formActions)
                      OutlinedButton(
                        onPressed: _locked ? null : () => _act(action),
                        child: Text(_text(action['label'])),
                      ),
                  ],
                ),
              ]),
            if (!_busy &&
                (_error == null || _showLaundryLogin) &&
                campusSections != null)
              ...campusSections
            else if (!_busy && _error == null && studentSections != null)
              ContentReveal.sequence(
                Column(
                  children: [
                    for (final (index, section) in studentSections.indexed)
                      ArchivePart.staggered(index, child: section),
                  ],
                ),
                revision: _revision,
              )
            else if (!_busy && _error == null && result != null) ...[
              if (!notices && _text(result['message']).isNotEmpty)
                _panel([SelectableText(_text(result['message']))]),
              if (body.isNotEmpty && !bodyInRows)
                _panel([SelectableText(body)]),
              if (notices) ...[
                if (rows.isEmpty) const ListTile(title: Text('暂无通知')),
                ContentReveal.sequence(
                  Column(
                    children: [
                      for (final (index, row) in rows.indexed) ...[
                        if (index > 0) const Divider(height: 1),
                        ArchivePart.staggered(index, child: _noticeRow(row)),
                      ],
                    ],
                  ),
                  revision: _revision,
                ),
                if (pageActions.isNotEmpty ||
                    (currentPage is int && totalPages is int))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      children: [
                        if (currentPage is int && totalPages is int)
                          Text('第 $currentPage / $totalPages 页'),
                        for (final action in pageActions)
                          TextButton(
                            onPressed: _locked ? null : () => _act(action),
                            child: Text(_text(action['label'])),
                          ),
                      ],
                    ),
                  ),
              ] else if (departures.isNotEmpty)
                _shuttleSchedule(departures)
              else if (_resource == 'exams') ...[
                if (rows.isEmpty) const ListTile(title: Text('暂无考试安排')),
                for (final row in rows) _examRow(row),
              ] else
                ContentReveal.sequence(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, row) in rows.indexed)
                        ArchivePart.staggered(index, child: _row(row)),
                    ],
                  ),
                  revision: _revision,
                ),
              if (rows.isEmpty &&
                  !notices &&
                  _resource != 'exams' &&
                  departures.isEmpty &&
                  body.isEmpty &&
                  controls.isEmpty &&
                  actions.isEmpty &&
                  files.isEmpty &&
                  _text(result['message']).isEmpty)
                _panel([const Text('当前没有相关记录。')]),
              for (final file in files)
                _panel([
                  Text(
                    _text(file['name']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _locked
                            ? null
                            : () => _file(file, 'exportFile'),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('导出文件'),
                      ),
                      if (_text(
                            file['mime'],
                          ).split(';').first.trim().toLowerCase() ==
                          'application/pdf')
                        FilledButton.icon(
                          onPressed: _locked
                              ? null
                              : () => _file(file, 'openPdf'),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('打开 PDF'),
                        ),
                    ],
                  ),
                ]),
            ],
            if (_fileBusy != null)
              const DelayedLoading(child: LinearProgressIndicator()),
            if (_fileError != null) _panel([Text(_fileError!)]),
          ],
        ),
      ),
    );
  }
}
