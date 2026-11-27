import 'dart:convert';

import 'campus_parsers.dart';
import 'platform.dart';
import 'transport.dart';

class CampusServices {
  CampusServices(
    this.http,
    this.platform, {
    this.credential,
    this.ticketProvider,
    this.onQuery,
  });
  final SchoolTransport http;
  final FoundationPlatform platform;
  final Future<String?> Function()? credential;
  final Future<String> Function(String service)? ticketProvider;
  final void Function()? onQuery;

  final _orderSnapshots = <String, Map<String, dynamic>>{};
  final _pendingOrders = <String, Future<Map<String, dynamic>>>{};
  String? _snapshotOwner;
  String? _portalXsrf;

  Future<Map<String, dynamic>> query(
    String resource, {
    Map<String, dynamic> options = const {},
  }) async {
    try {
      return switch (resource) {
        'notices' => await _notices(options),
        'notice-detail' => await _noticeDetail(options),
        'notice-file' => await _noticeFile(options),
        'library' ||
        'library-profile' ||
        'library-loans' ||
        'library-search' ||
        'library-fines' ||
        'library-requests' ||
        'library-booklist' ||
        'library-booklist-books' => await _library(resource, options),
        'shuttle' => await _shuttle(),
        'second-class' => await _secondClass(),
        'laundry' => await _laundryHome(options),
        'laundry-shops' => await _laundryShops(options),
        'laundry-devices' => await _laundryDevices(options),
        'laundry-sms' => await _laundrySMS(options),
        'laundry-login' => await _laundryLogin(options),
        'laundry-orders' => await _laundryOrders(options),
        'laundry-order' => await _laundryOrder(options),
        _ => throw FoundationException('unknown_resource', '未知校园服务。'),
      };
    } on CampusParseException catch (error) {
      throw FoundationException(error.code, error.message);
    } on FormatException {
      throw FoundationException('invalid_response', '服务响应格式无法识别。');
    }
  }

  static Map<String, dynamic> _row(
    String title,
    Map<String, dynamic> fields, {
    String? resource,
    Map<String, dynamic> options = const {},
  }) => {
    'title': title,
    'fields': campusFields(fields),
    if (resource != null) 'action': {'resource': resource, 'options': options},
  };

  static Map<String, dynamic> _action(
    String label,
    String resource, [
    Map<String, dynamic> options = const {},
  ]) => {'label': label, 'resource': resource, 'options': options};
  static Map<String, dynamic> _textControl(
    String key,
    String label,
    Object? value,
  ) => {
    'key': key,
    'label': label,
    'type': 'text',
    'value': value == null ? '' : '$value',
  };
  static Map<String, dynamic> _select(
    String key,
    String label,
    String value,
    Map<String, String> options,
  ) => {
    'key': key,
    'label': label,
    'type': 'select',
    'value': value,
    'options': options.entries
        .map((e) => {'value': e.key, 'label': e.value})
        .toList(),
  };

  static String _string(
    Map<String, dynamic> options,
    String key, [
    String fallback = '',
  ]) {
    final value = options[key];
    if (value == null) return fallback;
    if (value is! String) campusFail('invalid_query', '参数 $key 必须为文本。');
    return value;
  }

  static int _page(
    Map<String, dynamic> options, [
    String key = 'page',
    int fallback = 1,
  ]) {
    final value = options[key] ?? fallback;
    final page = value is int
        ? value
        : (value is String ? int.tryParse(value) : null);
    if (page == null || page < 1 || page > 214748364)
      campusFail('invalid_pagination', '分页参数无效。');
    return page;
  }

  static Uri _url(String value) {
    if (campusURLHasUserInfo(value)) campusFail('invalid_url', '服务地址不能包含用户信息。');
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.authority.contains('@'))
      campusFail('invalid_url', '服务地址无效。');
    return uri;
  }

  static bool _sameOrigin(Uri uri, Uri base) =>
      uri.scheme == base.scheme &&
      uri.host == base.host &&
      uri.port == base.port &&
      uri.userInfo.isEmpty &&
      !uri.authority.contains('@');

  void _status(SchoolResponse response) {
    if (response.status == 401 ||
        ['auth.wust.edu.cn', 'atrust.wust.edu.cn'].contains(response.uri.host))
      throw FoundationException(
        'authentication_required',
        '学校服务会话失效，请重新认证。',
        status: response.status,
      );
    if (response.status != 200)
      throw FoundationException(
        'unexpected_status_code',
        '服务请求失败（HTTP ${response.status}）。',
        status: response.status,
      );
  }

  Future<String> _tgt() async {
    final value = await credential?.call();
    if (value == null || value.trim().isEmpty)
      throw FoundationException('tgt_required', '此服务需要当前学校账号的有效 TGT，请先完成学校认证。');
    if (!RegExp(r'^TGT-[A-Za-z0-9._~-]+$').hasMatch(value))
      throw FoundationException('invalid_credential', '学校 TGT 格式无效。');
    return value;
  }

  Future<String> _ticket(String? tgt, String service) async {
    if (ticketProvider != null) return ticketProvider!(service);
    if (tgt == null)
      throw const FoundationException('tgt_required', '缺少学校认证凭据。');
    final uri = Uri.https('auth.wust.edu.cn', '/lyuapServer/v1/tickets/$tgt');
    final response = await http.send(
      uri,
      method: 'POST',
      form: {'service': service, 'loginToken': 'loginToken'},
      followRedirects: false,
    );
    if (response.uri != uri)
      campusFail('unexpected_redirect', '学校票据接口跳转到非预期地址。');
    if (response.status == 500 && response.text.trim().startsWith('TGT :'))
      throw FoundationException('authentication_required', '学校 TGT 已失效，请重新认证。');
    if (response.status != 200)
      throw FoundationException(
        'unexpected_status_code',
        '学校票据请求失败（HTTP ${response.status}）。',
        status: response.status,
      );
    final ticket = response.text.trim();
    if (!RegExp(r'^ST-[A-Za-z0-9._~-]+$').hasMatch(ticket))
      campusFail('invalid_response', '学校票据响应无效。');
    return ticket;
  }

  Future<SchoolResponse> _followWithin(
    Uri uri,
    Uri origin, {
    bool stopAtAuthorization = false,
  }) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!_sameOrigin(uri, origin))
        campusFail('unexpected_redirect', '学校服务跳转到非预期地址。');
      final response = await http.send(uri, followRedirects: false);
      _captureXsrf(response);
      if (!_sameOrigin(response.uri, origin))
        campusFail('unexpected_redirect', '学校服务跳转到非预期地址。');
      if (response.status < 300 || response.status >= 400) return response;
      final location = response.headers['location'];
      if (location == null) campusFail('invalid_response', '学校服务重定向缺少目标地址。');
      if (campusURLHasUserInfo(location))
        campusFail('unexpected_redirect', '学校服务跳转地址含用户信息。');
      uri = response.uri.resolve(location);
      if (!_sameOrigin(uri, origin))
        campusFail('unexpected_redirect', '学校服务跳转到非预期地址。');
      if (stopAtAuthorization && _portalAuthorization(uri) != null)
        return response;
    }
    campusFail('unexpected_redirect', '学校服务重定向次数过多。');
  }

  static CampusNoticePolicy _noticePolicy(Map<String, dynamic> options) {
    final excluded = options['excludedDates'];
    if (excluded != null &&
        (excluded is! List || excluded.any((v) => v is! String)))
      campusFail('invalid_date_policy', '通知日期过滤配置无效。');
    return CampusNoticePolicy(
      excluded: excluded == null
          ? const ['1980-01-01']
          : List<String>.from(excluded as List),
      earliest: options['earliestDate'] == null
          ? null
          : _string(options, 'earliestDate'),
      latest: options['latestDate'] == null
          ? null
          : _string(options, 'latestDate'),
    );
  }

  static Map<String, dynamic> _policyOptions(Map<String, dynamic> options) => {
    for (final key in ['excludedDates', 'earliestDate', 'latestDate'])
      if (options.containsKey(key)) key: options[key],
  };

  Future<SchoolResponse> _noticeHTML(Uri uri) async {
    if (!isUniversityURL(uri)) campusFail('unsupported_url', '通知地址不在学校网站范围内。');
    final response = await http.send(uri);
    _status(response);
    if (!isUniversityURL(response.uri))
      campusFail('unexpected_redirect', '通知跳转到非学校网站。');
    return response;
  }

  Future<String> _noticeText(SchoolResponse response) async {
    try {
      return utf8.decode(response.bytes);
    } on FormatException {
      final match = RegExp(
        r'''charset\s*=\s*["']?([a-z0-9_-]+)''',
        caseSensitive: false,
      ).firstMatch(response.headers['content-type'] ?? '');
      if (match == null ||
          !['gbk', 'gb2312', 'gb18030'].contains(match[1]!.toLowerCase())) {
        campusFail('invalid_encoding', '通知页面编码无法识别。');
      }
      Map<String, dynamic> decoded;
      try {
        decoded = await platform.invoke('decodeText', {
          'data': base64Encode(response.bytes),
          'charset': 'GB18030',
        });
      } on FoundationException catch (error) {
        if (error.code == 'cancelled') rethrow;
        campusFail('invalid_encoding', '通知页面编码转换失败。');
      }
      if (decoded['text'] is! String)
        campusFail('invalid_encoding', '通知页面编码转换失败。');
      return decoded['text'] as String;
    }
  }

  Future<Map<String, dynamic>> _notices(Map<String, dynamic> options) async {
    final source = _string(options, 'source', 'campus');
    if (!noticeSources.containsKey(source))
      campusFail('invalid_query', '通知来源无效。');
    final requestedURL = _string(options, 'url');
    final uri = _url(
      requestedURL.isEmpty ? noticeSources[source]!['url']! : requestedURL,
    );
    if (!isNoticeList(uri, source))
      campusFail('unsupported_url', '通知列表地址不在支持范围内。');
    final policy = _noticePolicy(options);
    final response = await _noticeHTML(uri);
    if (!isNoticeList(response.uri, source))
      campusFail('unexpected_redirect', '通知列表跳转到非预期页面。');
    final page = parseNoticeList(
      source,
      response.uri,
      await _noticeText(response),
      policy: policy,
    );
    final policyOptions = _policyOptions(options);
    return {
      'title': noticeSources[source]!['name'],
      'message':
          '第 ${page['currentPage'] ?? '未知'} / ${page['totalPages'] ?? '未知'} 页。日期规则排除 ${page['filteredItemCount']} 条。',
      'rows': [
        for (final item in campusRecords(page['items']))
          _row(
            item['title'] as String,
            {'发布日期': item['publishedDate'], '原文': item['url']},
            resource: 'notice-detail',
            options: {...item, ...policyOptions},
          ),
      ],
      'controls': [
        _select('source', '通知来源', source, {
          for (final entry in noticeSources.entries)
            entry.key: entry.value['name']!,
        }),
      ],
      'actions': [
        _action('查询来源首页', 'notices', {'url': '', ...policyOptions}),
        if (page['previousPageURL'] != null)
          _action('上一页', 'notices', {
            'source': source,
            'url': page['previousPageURL'],
            ...policyOptions,
          }),
        if (page['nextPageURL'] != null)
          _action('下一页', 'notices', {
            'source': source,
            'url': page['nextPageURL'],
            ...policyOptions,
          }),
      ],
      'page': page,
    };
  }

  Future<Map<String, dynamic>> _noticeDetail(
    Map<String, dynamic> options,
  ) async {
    final uri = _url(_string(options, 'url'));
    if (!isUniversityURL(uri) || !isNoticeArticle(uri))
      campusFail('unsupported_url', '通知正文地址不在支持范围内。');
    final date = noticeDate(_string(options, 'publishedDate'), exact: true);
    if (date == null) campusFail('missing_publication_date', '通知没有有效发布日期。');
    final policy = _noticePolicy(options);
    if (!policy.allows(date))
      campusFail('filtered_publication_date', '通知日期被当前规则排除。');
    final response = await _noticeHTML(uri);
    if (!isNoticeArticle(response.uri))
      campusFail('unexpected_redirect', '通知正文跳转到非预期页面。');
    final detail = parseNoticeDetail(
      await _noticeText(response),
      {
        'title': _string(options, 'title'),
        'source': _string(options, 'source', 'campus'),
        'publishedDate': date,
      },
      response.uri,
      policy: policy,
    );
    final summary = campusMap(detail['summary']);
    return {
      'title': summary['title'],
      'message': detail['text'].toString().isEmpty
          ? '网页没有纯文本正文，请查看 PDF、图片或附件。'
          : null,
      'rows': [
        _row('通知正文', {
          '发布日期': summary['publishedDate'],
          '原文': summary['url'],
          '正文': detail['text'],
        }),
        for (final image in campusRecords(detail['images']))
          _row('图片', {'说明': image['alt'], '地址': image['url']}),
        for (final link in [
          ...campusRecords(detail['attachments']),
          ...campusRecords(detail['links']),
        ])
          _row(
            link['title'] as String,
            {'地址': link['url']},
            resource:
                isUniversityURL(Uri.parse(link['url'] as String)) &&
                    (link['url'] as String)
                        .split('?')
                        .first
                        .toLowerCase()
                        .endsWith('.pdf')
                ? 'notice-file'
                : null,
            options: {
              'url': link['url'],
              'sourceURL': '${response.uri}',
              'name': link['title'],
            },
          ),
      ],
      'actions': [
        for (final doc in campusRecords(detail['documents']))
          _action('下载原始 PDF', 'notice-file', doc),
      ],
      'detail': detail,
    };
  }

  Future<Map<String, dynamic>> _noticeFile(Map<String, dynamic> options) async {
    final uri = _url(_string(options, 'url')),
        source = _url(_string(options, 'sourceURL'));
    if (!isUniversityURL(uri) ||
        !uri.path.toLowerCase().endsWith('.pdf') ||
        !isUniversityURL(source) ||
        !isNoticeArticle(source))
      campusFail('unsupported_url', 'PDF 地址不在支持范围内。');
    final response = await http.send(uri, headers: {'Referer': '$source'});
    _status(response);
    if (!isUniversityURL(response.uri))
      campusFail('unexpected_redirect', 'PDF 跳转到非学校网站。');
    validateNoticePDF(uri, source, response.bytes);
    final name = _string(
      options,
      'name',
      uri.pathSegments.last,
    ).replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_');
    return {
      'title': '通知 PDF',
      'rows': [
        _row(name, {'大小': '${response.bytes.length} 字节', '来源': '$source'}),
      ],
      'files': [
        {
          'name': name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf',
          'mime': 'application/pdf',
          'base64': base64Encode(response.bytes),
        },
      ],
    };
  }

  static final _libraryOrigin = Uri.parse('https://libsys.wust.edu.cn');
  static const _libraryService =
      'https://libsys.wust.edu.cn:443/meta-local/opac/cas/rosetta';

  Future<Object?> _libraryRequest(
    String path, {
    String method = 'GET',
    Map<String, String> parameters = const {},
    Object? body,
  }) async {
    final uri = _libraryOrigin.replace(
      path: path,
      queryParameters: parameters.isEmpty ? null : parameters,
    );
    final response = await http.send(
      uri,
      method: method,
      jsonBody: body,
      followRedirects: false,
    );
    if (response.status == 302 ||
        response.status == 401 ||
        response.uri.host == 'auth.wust.edu.cn')
      throw FoundationException('authentication_required', '图书馆会话未建立或已失效。');
    _status(response);
    if (!_sameOrigin(response.uri, uri))
      campusFail('unexpected_redirect', '图书馆跳转到非预期地址。');
    return libraryPayload(response.json);
  }

  Future<Map<String, dynamic>> _library(
    String resource,
    Map<String, dynamic> options,
  ) async {
    final tgt = ticketProvider == null ? await _tgt() : null;
    Future<Map<String, dynamic>> perform() => _libraryQuery(resource, options);
    try {
      return await perform();
    } on FoundationException catch (error) {
      if (error.code != 'authentication_required') rethrow;
      final ticket = await _ticket(tgt, _libraryService);
      final exchange = await _followWithin(
        Uri.parse(_libraryService).replace(queryParameters: {'ticket': ticket}),
        _libraryOrigin,
      );
      _status(exchange);
      final index = await _followWithin(
        _libraryOrigin.replace(path: '/meta-local/opac/cas/rosetta'),
        _libraryOrigin,
      );
      _status(index);
      return await perform();
    }
  }

  Future<Map<String, dynamic>> _libraryQuery(
    String resource,
    Map<String, dynamic> options,
  ) async {
    onQuery?.call();
    const base = '/meta-local/opac';
    final page = _page(options),
        pageSize = _page(
          options,
          'pageSize',
          resource == 'library-requests'
              ? 5
              : resource == 'library-fines' ||
                    resource == 'library-booklist-books'
              ? 10
              : 100,
        );
    if (pageSize > 100)
      campusFail('invalid_pagination', '图书馆每页条数必须在 1 至 100 之间。');
    final parameters = {'page': '$page', 'pageSize': '$pageSize'};
    final links = [
      _action('账户资料', 'library-profile'),
      _action('当前借阅', 'library-loans'),
      _action('即将到期', 'library-loans', {'kind': 'overdue'}),
      _action('滞纳金与违章', 'library-fines'),
      _action('我的请求', 'library-requests'),
      _action('我的书单目录', 'library-search'),
    ];
    if (resource == 'library' || resource == 'library-profile') {
      final stats = campusMap(await _libraryRequest('$base/users/stats'));
      final rows = <Map<String, dynamic>>[_row('账户统计', stats)];
      final circulation = <String, Map<String, dynamic>>{};
      if (resource == 'library') {
        for (final item in [
          ('loans', '当前借阅', 'current'),
          ('overdue_soon', '即将到期', 'dueSoon'),
        ]) {
          final result = parseLibraryPage(
            await _libraryRequest(
              '$base/users/${item.$1}',
              parameters: parameters,
            ),
            page: page,
            pageSize: pageSize,
          );
          circulation[item.$3] = result;
          rows.add(
            _row(item.$2, {'总数': result['total'], '页码': result['currentPage']}),
          );
          rows.addAll(
            campusRecords(
              result['items'],
            ).map((record) => _row('${record['title'] ?? '书名缺失'}', record)),
          );
        }
      }
      return {
        'title': resource == 'library-profile' ? '账户概览' : '图书馆',
        'rows': rows,
        'actions': links,
        'statistics': stats,
        if (circulation.isNotEmpty) 'circulation': circulation,
      };
    }
    if (resource == 'library-search') {
      final items = campusRecords(
        await _libraryRequest('$base/booklists/tree'),
      );
      final keyword = _string(options, 'keyword').trim();
      final filtered = items
          .where(
            (e) =>
                keyword.isEmpty ||
                campusDisplay(
                  e['booklistName'],
                ).toLowerCase().contains(keyword.toLowerCase()),
          )
          .toList();
      return {
        'title': '我的书单目录',
        'rows': [
          for (final item in filtered)
            _row(
              '${item['booklistName'] ?? '未命名书单'}',
              item,
              resource: item['_id'] == null ? null : 'library-booklist',
              options: {'id': item['_id']?.toString()},
            ),
        ],
        'controls': [_textControl('keyword', '书单目录名称筛选', keyword)],
        'actions': [_action('筛选目录', 'library-search')],
        'total': items.length,
      };
    }
    String? id;
    if (resource.startsWith('library-booklist')) {
      id = _string(options, 'id');
      if (!RegExp(r'^[A-Za-z0-9_~.-]+$').hasMatch(id) ||
          id == '.' ||
          id == '..')
        campusFail('invalid_booklist_id', '图书馆书单 ID 无效。');
      if (resource == 'library-booklist') {
        final info = campusMap(
          await _libraryRequest('$base/booklists/$id/info'),
        );
        return {
          'title': '${info['booklistName'] ?? '书单资料'}',
          'rows': [_row('书单资料', info)],
          'actions': [
            _action('书单内书目', 'library-booklist-books', {'id': id}),
          ],
        };
      }
    }
    final kind = _string(options, 'kind', 'current');
    if (resource == 'library-loans' && !['current', 'overdue'].contains(kind))
      campusFail('invalid_query', '图书馆借阅类别无效。');
    final path = switch (resource) {
      'library-loans' =>
        '$base/users/${kind == 'overdue' ? 'overdue_soon' : 'loans'}',
      'library-fines' => '$base/users/fines',
      'library-requests' => '$base/users/requests/list',
      'library-booklist-books' => '$base/booklists/$id/detls',
      _ => throw FoundationException('unknown_resource', '未知图书馆服务。'),
    };
    final raw = await _libraryRequest(
      path,
      method: resource == 'library-booklist-books' ? 'POST' : 'GET',
      parameters: resource == 'library-booklist-books'
          ? {}
          : {
              ...parameters,
              if (resource == 'library-requests') ...{
                'requestFlagStatus': 'all',
                'processStatus': '0',
              },
            },
      body: resource == 'library-booklist-books'
          ? {'page': page, 'pageSize': pageSize}
          : null,
    );
    final result = parseLibraryPage(
      raw,
      page: page,
      pageSize: pageSize,
      strict: resource != 'library-loans',
    );
    final current = result['currentPage'] as int;
    final totalPages = result['totalPage'] as int;
    return {
      'title': switch (resource) {
        'library-loans' => kind == 'overdue' ? '即将到期' : '当前借阅',
        'library-fines' => '滞纳金与违章',
        'library-requests' => '我的请求',
        _ => '书单书目',
      },
      'message': '第 $current / $totalPages 页，共 ${result['total']} 条。',
      'rows': [
        for (final item in campusRecords(result['items']))
          _row('${item['title'] ?? item['bookName'] ?? '记录'}', item),
      ],
      'controls': [
        _textControl('page', '页码', current),
        _textControl('pageSize', '每页条数（1 至 100）', pageSize),
        if (resource == 'library-loans')
          _select('kind', '借阅类别', kind, {'current': '当前借阅', 'overdue': '即将到期'}),
      ],
      'actions': [
        _action('查询', resource, {if (id != null) 'id': id}),
        if (current > 1)
          _action('上一页', resource, {...options, 'page': current - 1}),
        if (current < totalPages)
          _action('下一页', resource, {...options, 'page': current + 1}),
      ],
      'page': result,
    };
  }

  Future<Map<String, dynamic>> _secondClass() async {
    final tgt = ticketProvider == null ? await _tgt() : null;
    final origin = Uri.parse('https://xg.wust.edu.cn');
    const entry = 'https://xg.wust.edu.cn/xsfw/sys/dektapp/*default/index.do';
    Future<Object?> request(
      String path, [
      Map<String, String> parameters = const {},
    ]) async {
      final uri = origin.replace(
        path: path,
        queryParameters: parameters.isEmpty ? null : parameters,
      );
      final response = await http.send(
        uri,
        method: 'POST',
        form: {},
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': entry,
          'Origin': 'https://xg.wust.edu.cn',
        },
        followRedirects: false,
      );
      if (response.status == 401 ||
          (response.status >= 300 && response.status < 400) ||
          response.headers['content-type']?.toLowerCase().contains(
                'text/html',
              ) ==
              true)
        throw FoundationException('authentication_required', '第二课堂会话未建立或已失效。');
      _status(response);
      if (!_sameOrigin(response.uri, origin) || response.uri.path != uri.path)
        campusFail('unexpected_redirect', '第二课堂跳转到非预期地址。');
      return response.json;
    }

    Future<Map<String, dynamic>> perform() async {
      onQuery?.call();
      final config = campusMap(
        await request('/xsfw/sys/swpubapp/indexmenu/getAppConfig.do', {
          'appId': '5446046383738452',
          'appName': 'dektapp',
        }),
      );
      if (!config.containsKey('MODULES'))
        campusFail('invalid_response', '第二课堂应用初始化失败。');
      final grades = await request(
        '/xsfw/sys/dektapp/modules/cjdcxManage/getCj.do',
      );
      final summary = await request(
        '/xsfw/sys/dektapp/modules/cjdcxManage/getSzfzpj.do',
      );
      return parseSecondClass(grades, summary);
    }

    Map<String, dynamic> transcript;
    try {
      transcript = await perform();
    } on FoundationException catch (error) {
      if (error.code != 'authentication_required') rethrow;
      final ticket = await _ticket(tgt, entry);
      final response = await _followWithin(
        Uri.parse(entry).replace(queryParameters: {'ticket': ticket}),
        origin,
      );
      _status(response);
      transcript = await perform();
    }
    return {
      'title': '第二课堂成绩',
      'rows': [
        _row('综合评价', {
          '已获学分': transcript['earnedCredits'],
          '评价': transcript['evaluation'],
        }),
        for (final category in campusRecords(transcript['categories']))
          _row(category['name'] as String, {
            '类别编号': category['id'],
            '要求学分': category['requiredCredits'],
            '已获学分': category['earnedCredits'],
            for (final requirement in campusRecords(
              category['requirements'],
            )) ...{
              '${requirement['kind'] == 'required' ? '必修' : '选修'}要求':
                  requirement['requiredCredits'],
              '${requirement['kind'] == 'required' ? '必修' : '选修'}已获':
                  requirement['earnedCredits'],
              '${requirement['kind'] == 'required' ? '必修' : '选修'}剩余':
                  requirement['remainingCredits'],
              '${requirement['kind'] == 'required' ? '必修' : '选修'}完成':
                  requirement['isCompleted'] == true ? '是' : '否',
            },
          }),
      ],
      'transcript': transcript,
    };
  }

  void _captureXsrf(SchoolResponse response) {
    final cookie = response.headers['set-cookie'];
    if (cookie == null) return;
    final match = RegExp(
      r'(?:^|[,;]\s*)XSRF-TOKEN=([^;,]+)',
    ).firstMatch(cookie);
    if (match != null) _portalXsrf = Uri.decodeComponent(match[1]!);
  }

  static String? _portalAuthorization(Uri uri) {
    final encoded = uri.toString();
    final marker = encoded.indexOf('#');
    final fragment = marker < 0 ? '' : encoded.substring(marker + 1);
    final address = marker < 0 ? encoded : encoded.substring(0, marker);
    final queries = [
      if (fragment.contains('?')) fragment.substring(fragment.indexOf('?') + 1),
      if (address.contains('?')) address.substring(address.indexOf('?') + 1),
    ];
    for (final query in queries) {
      for (final item in query.split('&')) {
        final equals = item.indexOf('=');
        if (equals < 0) continue;
        final key = Uri.decodeComponent(item.substring(0, equals));
        final value = Uri.decodeComponent(item.substring(equals + 1));
        if (['Authorization', 'tokenId'].contains(key) && value.isNotEmpty)
          return value;
      }
    }
    return null;
  }

  Future<Map<String, String>> _portalHeaders() async {
    final timestamp = '${DateTime.now().millisecondsSinceEpoch}';
    final digest = await platform.invoke('digest', {
      'algorithm': 'MD5',
      'data': base64Encode(utf8.encode(shuttleSignatureInput(timestamp))),
    });
    final value = digest['data'];
    if (value is! String) campusFail('invalid_response', '原生签名能力返回格式无效。');
    final bytes = base64Decode(value);
    if (bytes.length != 16) campusFail('invalid_response', '原生 MD5 签名长度无效。');
    return {
      'Accept': 'application/json, text/plain, */*',
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': 'https://portal.wust.edu.cn/',
      'csrfTimestamp': timestamp,
      'csrfToken': bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join(),
      if (_portalXsrf != null) 'X-XSRF-TOKEN': _portalXsrf!,
    };
  }

  Future<Map<String, dynamic>> _portalRequest(
    String path, {
    String method = 'GET',
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.https(
      'portal.wust.edu.cn',
      '/$path',
      method == 'GET'
          ? {'_t': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}'}
          : null,
    );
    final response = await http.send(
      uri,
      method: method,
      form: method == 'POST' ? {} : null,
      headers: {...await _portalHeaders(), ...headers},
      followRedirects: false,
    );
    _captureXsrf(response);
    if (!_sameOrigin(response.uri, Uri.parse('https://portal.wust.edu.cn')))
      campusFail('unexpected_redirect', '信息门户跳转到非预期地址。');
    if (response.status == 401 ||
        (response.status >= 300 && response.status < 400))
      throw FoundationException('authentication_required', '信息门户会话未建立或已失效。');
    _status(response);
    final root = campusMap(response.json), meta = campusMap(root['meta']);
    final code = campusInt(meta['statusCode']);
    if ([302, 401].contains(code))
      throw FoundationException(
        'authentication_required',
        '信息门户会话未建立或已失效（业务码 $code）。',
      );
    if (meta['success'] is! bool) campusFail('invalid_response', '信息门户状态字段无效。');
    if (meta['success'] != true)
      campusFail('shuttle_rejected_$code', '信息门户拒绝请求（业务码 $code）。');
    return campusMap(root['data']);
  }

  Future<Map<String, dynamic>> _shuttle() async {
    final tgt = ticketProvider == null ? await _tgt() : null;
    const callback = 'https://portal.wust.edu.cn/shiro-cas';
    Future<Map<String, dynamic>> fetch([String? authorization]) async {
      onQuery?.call();
      final profile = await _portalRequest(
        'tryLoginUserInfo',
        method: 'POST',
        headers: {
          'gatewayAppId': 'ly-upp',
          'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
          'Origin': 'https://portal.wust.edu.cn',
          'Authorization': authorization ?? 'undefined',
        },
      );
      if (profile['userId'] == '')
        throw FoundationException('authentication_required', '信息门户没有有效登录用户。');
      final userID = campusID(profile['userId']);
      final card = await _portalRequest(
        'api/upp/contentDisplay/queryAppointCard/e05973ba27214e7a97234733848f05d5',
        headers: {
          'Authorization': profile['accessToken'] is String
              ? profile['accessToken'] as String
              : 'null',
          'loginUserId': userID,
          'loginUserName': userID,
          if (profile['orgId'] != null)
            'loginUserOrgId': campusID(profile['orgId']),
          if (profile['departmentId'] != null)
            'loginUserDeptId': campusID(profile['departmentId']),
        },
      );
      final content = campusMap(card['contentDisplay'])['html'];
      if (content is! String) campusFail('invalid_response', '校车信息卡片缺少正文。');
      return parseShuttle(content);
    }

    Map<String, dynamic> schedule;
    try {
      schedule = await fetch();
    } on FoundationException catch (error) {
      if (error.code != 'authentication_required') rethrow;
      final prepare = await http.send(
        Uri.https('portal.wust.edu.cn', '/auth', {
          'service': 'https://portal.wust.edu.cn/#/index70',
        }),
        followRedirects: false,
      );
      if (!_sameOrigin(prepare.uri, Uri.parse('https://portal.wust.edu.cn')) ||
          prepare.status < 300 ||
          prepare.status >= 400)
        campusFail('invalid_response', '信息门户认证预热失败。');
      final location = prepare.headers['location'];
      final redirect = location == null || campusURLHasUserInfo(location)
          ? null
          : Uri.tryParse(location);
      if (redirect == null ||
          !_sameOrigin(redirect, Uri.parse('https://auth.wust.edu.cn')) ||
          !{
            '/lyuapServer/login',
            '/authserver/login',
          }.contains(redirect.path) ||
          redirect.queryParameters['service'] != callback)
        campusFail('invalid_response', '信息门户认证目标无效。');
      final ticket = await _ticket(tgt, callback);
      final exchanged = await _followWithin(
        Uri.parse(callback).replace(queryParameters: {'ticket': ticket}),
        Uri.parse('https://portal.wust.edu.cn'),
        stopAtAuthorization: true,
      );
      String? authorization;
      if (exchanged.status >= 300 && exchanged.status < 400) {
        final target = exchanged.headers['location'];
        if (target == null) campusFail('invalid_response', '信息门户认证回调缺少地址。');
        authorization = _portalAuthorization(exchanged.uri.resolve(target));
        if (authorization == null)
          throw FoundationException('authentication_required', '信息门户认证未返回授权。');
      } else {
        _status(exchanged);
        authorization = _portalAuthorization(exchanged.uri);
      }
      schedule = await fetch(authorization);
    }
    return {
      'title': schedule['title'],
      'message': (schedule['notes'] as List).join('\n'),
      'rows': [
        for (final departure in campusRecords(schedule['departures']))
          _row(
            '${departure['origin']} → ${departure['destination']} ${departure['departureTime']}',
            {
              '日期': departure['operatingDays'],
              '起点': departure['origin'],
              '终点': departure['destination'],
              '发车时间': departure['departureTime'],
              '行车线路': departure['route'],
            },
          ),
      ],
      'schedule': schedule,
    };
  }

  static const _laundryOrigin = 'https://userapi.qiekj.com';
  static const _laundrySafari =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.2 Safari/605.1.15';
  static const _laundryIOS =
      'QEUser/1.28.2 (com.qiekj.QEUser; build:2; iOS 16.5.0) Alamofire/5.6.4';

  Future<(Object?, DateTime, DateTime)> _laundryRequest(
    String path,
    Map<String, String> fields, {
    String method = 'POST',
    bool ios = false,
    bool authenticated = false,
  }) async {
    final ordered = {
      for (final key in (fields.keys.toList()..sort())) key: fields[key]!,
    };
    final uri = Uri.parse(
      '$_laundryOrigin/$path',
    ).replace(queryParameters: method == 'GET' ? ordered : null);
    final response = await http.send(
      uri,
      method: method,
      form: method == 'GET' ? null : ordered,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': '',
        'User-Agent': ios ? _laundryIOS : _laundrySafari,
        if (ios) ...{'channel': 'ios_app', 'Version': '1.28.2'},
      },
      followRedirects: false,
    );
    final observed = DateTime.now().toUtc();
    if (response.uri != uri) campusFail('unexpected_redirect', '胖乖响应地址与请求不一致。');
    if (response.status != 200)
      throw FoundationException(
        'unexpected_status_code',
        '胖乖请求失败（HTTP ${response.status}）。',
        status: response.status,
      );
    return (
      laundryPayload(response.json, authenticated: authenticated),
      observed,
      laundryServerDate(response.headers['date'], observed),
    );
  }

  static void _phone(String phone) {
    if (!RegExp(r'^1[0-9]{10}$').hasMatch(phone))
      campusFail('invalid_phone_number', '手机号须为 1 开头的 11 位数字。');
  }

  static List<Map<String, dynamic>> _loginControls(
    Map<String, dynamic> options,
  ) => [
    _textControl('phone', '胖乖手机号', options['phone']),
    _textControl('smsCode', '短信验证码', ''),
  ];

  Future<Map<String, dynamic>> _laundryHome(
    Map<String, dynamic> options,
  ) async {
    final hasSavedLogin = await platform.load('laundry') != null;
    return {
      'title': '胖乖登录',
      'rows': <Map<String, dynamic>>[],
      'controls': _loginControls(options),
      'actions': [
        _action('附近门店', 'laundry-shops'),
        _action('发送登录短信', 'laundry-sms', {'action': 'send'}),
        _action('使用验证码登录', 'laundry-login', {'action': 'login'}),
        if (hasSavedLogin) ...[
          _action('验证已保存登录', 'laundry-login', {'action': 'restore'}),
          _action('运行中洗衣订单', 'laundry-orders', {'running': true}),
          _action('全部订单', 'laundry-orders'),
          _action('清除胖乖本地登录', 'laundry-login', {'action': 'clear'}),
        ],
      ],
    };
  }

  Future<Map<String, dynamic>> _laundrySMS(Map<String, dynamic> options) async {
    if (_string(options, 'action') != 'send')
      return {
        'title': '胖乖短信登录',
        'rows': <Map<String, dynamic>>[],
        'controls': _loginControls(options),
        'actions': [
          _action('发送登录短信', 'laundry-sms', {'action': 'send'}),
        ],
      };
    final phone = _string(options, 'phone');
    _phone(phone);
    final preflight = (await _laundryRequest('common/isNeedCaptcha', {
      'phone': phone,
    }, ios: true)).$1;
    if (preflight is! bool) campusFail('invalid_response', '胖乖人机验证预检响应无效。');
    if (preflight) campusFail('captcha_required', '胖乖要求在官方登录页完成人机验证，短信申请已停止。');
    await _laundryRequest('common/sms/sendCode', {
      'phone': phone,
      'template': 'reg',
    }, ios: true);
    return {
      'title': '胖乖短信登录',
      'message': '验证码已发送',
      'rows': <Map<String, dynamic>>[],
      'controls': _loginControls(options),
      'actions': [
        _action('使用验证码登录', 'laundry-login', {'action': 'login'}),
      ],
    };
  }

  Future<CampusLaundryCredential> _savedLaundry() async {
    final value = await platform.load('laundry');
    if (value == null)
      throw FoundationException(
        'laundry_login_required',
        '没有已保存的胖乖登录，请先使用短信验证码登录。',
      );
    final result = CampusLaundryCredential.decode(value);
    if (_snapshotOwner != result.token) {
      _orderSnapshots.clear();
      _pendingOrders.clear();
      _snapshotOwner = result.token;
    }
    return result;
  }

  Future<CampusLaundryCredential> _validateLaundry(
    String token, {
    CampusLaundryCredential? saved,
  }) async {
    if (token.isEmpty) campusFail('laundry_login_required', '胖乖凭据为空，请重新登录。');
    final payload = campusMap(
      (await _laundryRequest(
        'user/info',
        {'token': token},
        ios: true,
        authenticated: true,
      )).$1,
    );
    final id = campusID(payload['id']);
    if (saved != null && saved.userID != id)
      campusFail('account_mismatch', '胖乖返回的账号与保存的凭据不一致。');
    final now = DateTime.now().toUtc();
    return CampusLaundryCredential(
      id,
      token,
      saved?.firstVerifiedAt ?? now,
      now,
    );
  }

  Future<Map<String, dynamic>> _laundryLogin(
    Map<String, dynamic> options,
  ) async {
    final action = _string(options, 'action');
    if (action == 'clear') {
      await platform.clear('laundry');
      _orderSnapshots.clear();
      _pendingOrders.clear();
      _snapshotOwner = null;
      return {
        'title': '胖乖生活',
        'message': '已退出胖乖账号',
        'rows': <Map<String, dynamic>>[],
      };
    }
    CampusLaundryCredential result;
    if (action == 'restore') {
      final saved = await _savedLaundry();
      result = await _validateLaundry(saved.token, saved: saved);
    } else if (action == 'login') {
      final phone = _string(options, 'phone'),
          code = _string(options, 'smsCode');
      _phone(phone);
      if (!RegExp(r'^[0-9]+$').hasMatch(code))
        campusFail('invalid_sms_code', '短信验证码须为非空数字。');
      final payload = campusMap(
        (await _laundryRequest('user/reg', {
          'channel': 'ios_app',
          'phone': phone,
          'verify': code,
        }, ios: true)).$1,
      );
      if (payload['token'] is! String || (payload['token'] as String).isEmpty)
        campusFail('invalid_response', '胖乖登录未返回凭据。');
      result = await _validateLaundry(payload['token'] as String);
    } else if (action == 'web-token') {
      final origin = _url(_string(options, 'origin'));
      if (!_sameOrigin(origin, Uri.parse('https://h5.qiekj.com')))
        campusFail('unexpected_web_origin', '请在胖乖官方网页登录。');
      result = await _validateLaundry(_string(options, 'token'));
    } else {
      return _laundryHome(options);
    }
    await platform.save('laundry', result.encode());
    _orderSnapshots.clear();
    _pendingOrders.clear();
    _snapshotOwner = result.token;
    return {
      'title': '胖乖登录',
      'rows': <Map<String, dynamic>>[],
      'actions': [
        _action('运行中洗衣订单', 'laundry-orders', {'running': true}),
        _action('全部订单', 'laundry-orders'),
      ],
    };
  }

  Future<Map<String, dynamic>> _laundryShops(
    Map<String, dynamic> options,
  ) async {
    final page = _page(options);
    final latitude = double.tryParse('${options['latitude'] ?? 30.439405}'),
        longitude = double.tryParse('${options['longitude'] ?? 114.268024}');
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180)
      campusFail('invalid_query', '附近门店坐标无效。');
    final payload = campusMap(
      (await _laundryRequest('shop/nearby/list', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'type': '7',
        'page': '$page',
        'pageSize': '10',
      })).$1,
    );
    final total = campusInt(payload['total']),
        shops = campusRecords(payload['items']);
    if (total < 0) campusFail('invalid_response', '胖乖门店总数无效。');
    for (final shop in shops) {
      if (shop['id'] is! String || shop['name'] is! String)
        campusFail('invalid_response', '胖乖门店结构无效。');
      for (final key in ['distance', 'machineCount', 'freeMachine']) {
        if (shop[key] != null && shop[key] is! int)
          campusFail('invalid_response', '胖乖门店数量无效。');
      }
    }
    return {
      'title': '附近洗衣门店',
      'shops': shops,
      if (latitude == 30.439405 && longitude == 114.268024)
        'shopQueryArea': '黄家湖校区附近',
      'message': '共 $total 家门店，本页 ${shops.length} 家。',
      'rows': [
        for (final shop in shops)
          _row(
            shop['name'] as String,
            {
              '门店 ID': shop['id'],
              '距离': shop['distance'],
              '设备总数': shop['machineCount'],
              '空闲设备': shop['freeMachine'],
            },
            resource: 'laundry-devices',
            options: {
              'shopId': shop['id'],
              'shopName': shop['name'],
              'machineCount': shop['machineCount'],
            },
          ),
      ],
      'controls': [
        _textControl('latitude', '纬度（默认黄家湖校区）', latitude),
        _textControl('longitude', '经度', longitude),
        _textControl('page', '页码', page),
      ],
      'actions': [
        _action('查询', 'laundry-shops'),
        if (page > 1)
          _action('上一页', 'laundry-shops', {...options, 'page': page - 1}),
        if (shops.isNotEmpty && page * 10 < total)
          _action('下一页', 'laundry-shops', {...options, 'page': page + 1}),
      ],
    };
  }

  Future<Map<String, dynamic>> _laundryDevices(
    Map<String, dynamic> options,
  ) async {
    final id = _string(options, 'shopId');
    if (id.isEmpty) campusFail('invalid_query', '门店 ID 不能为空。');
    final devices = <Map<String, dynamic>>[], seen = <String>{};
    var page = 1;
    while (true) {
      final data = campusMap(
        (await _laundryRequest('machineModel/near/machines', {
          'shopId': id,
          'machineTypeId': laundryWasherType,
          'goodsPage': '$page',
          'pageSize': '100',
        })).$1,
      );
      final items = campusRecords(data['items']),
          next = campusInt(data['goodsPage']);
      var added = 0;
      for (final item in items) {
        if (item['id'] is! String || item['name'] is! String)
          campusFail('invalid_response', '胖乖设备结构无效。');
        if (seen.add(item['id'] as String)) {
          devices.add(item);
          added++;
        }
      }
      if (added == 0 || next <= page) break;
      page = next;
    }
    devices.sort(compareLaundryWashers);
    final all =
        options['machineCount'] != null &&
        campusInt(options['machineCount']) == devices.length;
    return {
      'title': _string(options, 'shopName', '门店空闲洗衣机'),
      'message': all ? '全部设备均为空闲，以下名单覆盖全部设备。' : '本次仅返回空闲设备明细，不能据此认定全部设备名单。',
      'rows': [
        for (final device in devices)
          _row(device['name'] as String, {'设备 ID': device['id'], '状态': '空闲'}),
      ],
      'availableDevices': devices,
      'allDevices': all ? devices : null,
      'actions': [_action('刷新设备', 'laundry-devices', options)],
    };
  }

  Future<Map<String, dynamic>> _orderPage(
    CampusLaundryCredential account,
    int page,
  ) async {
    final payload = campusMap(
      (await _laundryRequest(
        'order/list',
        {'page': '$page', 'pageSize': '10', 'token': account.token},
        method: 'GET',
        authenticated: true,
      )).$1,
    );
    if (_snapshotOwner != account.token)
      throw FoundationException('account_changed', '胖乖账号已变化，请重新查询。');
    final total = campusInt(payload['total']);
    if (total < 0) campusFail('invalid_response', '胖乖订单总数无效。');
    final items = campusRecords(
      payload['items'],
    ).map(parseLaundryOrder).toList();
    return {
      'items': items,
      'total': total,
      'nextPage': items.isNotEmpty && page * 10 < total ? page + 1 : null,
    };
  }

  Future<Map<String, dynamic>> _snapshot(
    String id,
    CampusLaundryCredential account, {
    bool refresh = false,
  }) async {
    final now = DateTime.now().toUtc(), cached = _orderSnapshots[id];
    if (!refresh && cached != null && laundrySnapshotIsFresh(cached, now))
      return cached;
    final pending = _pendingOrders[id];
    if (pending != null) return pending;
    Future<Map<String, dynamic>> fetch() async {
      final response = await _laundryRequest('order/detail', {
        'orderId': id,
        'token': account.token,
      }, authenticated: true);
      final result = laundrySnapshot(
        response.$1,
        observedAt: response.$2,
        serverDate: response.$3,
      );
      if (campusMap(result['order'])['id'] != id)
        campusFail('invalid_response', '胖乖返回的订单与请求不一致。');
      if (_snapshotOwner != account.token)
        throw FoundationException('account_changed', '胖乖账号已变化，请重新查询。');
      _orderSnapshots[id] = result;
      return result;
    }

    final operation = fetch();
    _pendingOrders[id] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_pendingOrders[id], operation)) _pendingOrders.remove(id);
    }
  }

  Map<String, dynamic> _orderRow(
    Map<String, dynamic> order, {
    Map<String, dynamic>? snapshot,
  }) {
    final seconds = snapshot == null
        ? null
        : laundryRemaining(snapshot, DateTime.now().toUtc());
    final name = _string(order, 'machineName').trim();
    final shop = _string(order, 'shopName').trim();
    final program = _string(order, 'machineFunctionName').trim();
    final created = _orderTime(order['createTime']);
    final completed = _orderTime(order['completeTime']);
    final status = order['orderStatus'];
    return _row(
      name.isEmpty ? '洗衣订单' : name,
      {
        '状态': switch (status) {
          2 => '进行中',
          3 => '已完成',
          _ => '状态待确认',
        },
        if (shop.isNotEmpty) '门店': shop,
        if (program.isNotEmpty) '程序': program,
        if (created != null) '下单时间': created,
        if (completed != null && status == 3) '完成时间': completed,
        if (completed != null && status == 2) '预计完成': completed,
        if (seconds != null && seconds > 0)
          '剩余时间': '${(seconds + 59) ~/ 60} 分钟',
      },
      resource: 'laundry-order',
      options: {'orderId': order['id']},
    );
  }

  String? _orderTime(Object? value) {
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}').hasMatch(value))
      return null;
    return value.substring(0, 16).replaceFirst('T', ' ');
  }

  Future<Map<String, dynamic>> _laundryOrders(
    Map<String, dynamic> options,
  ) async {
    final account = await _savedLaundry();
    final running = options['running'] == true || options['running'] == 'true';
    final page = _page(options);
    if (running) {
      final seen = <String>{}, orders = <Map<String, dynamic>>[];
      int? current = 1;
      while (current != null) {
        final result = await _orderPage(account, current);
        var added = 0;
        for (final order in campusRecords(result['items'])) {
          if (seen.add(order['id'] as String)) {
            added++;
            if (isRunningWasher(order)) orders.add(order);
          }
        }
        current = added == 0 ? null : result['nextPage'] as int?;
      }
      final snapshots = <Map<String, dynamic>>[];
      for (final order in orders) {
        final snapshot = await _snapshot(
          order['id'] as String,
          account,
          refresh: true,
        );
        if (isRunningWasher(campusMap(snapshot['order'])))
          snapshots.add(snapshot);
      }
      return {
        'title': '运行中洗衣订单',
        'rows': [
          for (final snapshot in snapshots)
            _orderRow(campusMap(snapshot['order']), snapshot: snapshot),
        ],
        'snapshots': snapshots,
      };
    }
    final result = await _orderPage(account, page);
    return {
      'title': '胖乖订单',
      'rows': [
        for (final order in campusRecords(result['items'])) _orderRow(order),
      ],
      'actions': [
        if (page > 1) _action('上一页', 'laundry-orders', {'page': page - 1}),
        if (result['nextPage'] != null)
          _action('下一页', 'laundry-orders', {'page': result['nextPage']}),
      ],
    };
  }

  Future<Map<String, dynamic>> _laundryOrder(
    Map<String, dynamic> options,
  ) async {
    final id = _string(options, 'orderId');
    if (id.trim().isEmpty) campusFail('invalid_query', '订单 ID 不能为空。');
    final account = await _savedLaundry();
    final snapshot = await _snapshot(
      id,
      account,
      refresh: options['refresh'] == true,
    );
    return {
      'title': '洗衣订单详情',
      'rows': [_orderRow(campusMap(snapshot['order']), snapshot: snapshot)],
      'snapshot': snapshot,
    };
  }
}
