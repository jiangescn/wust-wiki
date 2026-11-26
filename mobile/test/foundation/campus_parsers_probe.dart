import 'dart:convert';

import '../../lib/foundation/campus_parsers.dart';
import 'campus_fixtures.dart';

int runCampusParserChecks() {
  var checks = 0;
  void check(bool value, String description) {
    if (!value) throw StateError(description);
    checks++;
  }

  void rejects(String code, void Function() action) {
    try {
      action();
    } on CampusParseException catch (error) {
      check(error.code == code, 'expected $code, got ${error.code}');
      return;
    }
    throw StateError('expected $code');
  }

  final listURI = Uri.parse(noticeSources['campus']!['url']!);
  final articleURI = Uri.parse('https://www.wust.edu.cn/info/1001/123.htm');
  final page = parseNoticeList('campus', listURI, campusNoticeListFixture);
  check(
    (page['items'] as List).length == 2,
    'deduplicate and retain future notices',
  );
  check(page['filteredItemCount'] == 2, 'filter sentinel and missing dates');
  check(
    page['nextPageURL'] == 'https://www.wust.edu.cn/index/tzgg/2.htm',
    'relative pagination',
  );
  check(
    page['totalPages'] == 3 && page['currentPage'] == 1,
    'pagination numbers',
  );
  check(
    noticeDate('2026-02-29') == null &&
        noticeDate('2024年2月29日') == '2024-02-29',
    'Gregorian validation',
  );
  rejects(
    'list_not_found',
    () => parseNoticeList('campus', listURI, '<p>系统错误</p>'),
  );
  rejects(
    'invalid_date_policy',
    () => CampusNoticePolicy(earliest: '2026-02-30'),
  );
  rejects(
    'invalid_date_policy',
    () => CampusNoticePolicy(earliest: '2026-02-02', latest: '2026-02-01'),
  );
  for (final value in [
    'https://wust.edu.cn.evil.test/info/1/2.htm',
    'https://u@www.wust.edu.cn/info/1/2.htm',
    'https://www.wust.edu.cn:8443/info/1/2.htm',
    'file:///info/1/2.htm',
  ]) {
    check(!isUniversityURL(Uri.parse(value)), 'reject unsafe university URL');
  }
  check(
    !isNoticeList(listURI.replace(query: 'evil=1'), 'campus'),
    'reject list query',
  );
  check(
    !isNoticeList(
      Uri.parse('https://jwc.wust.edu.cn/index/tzgg.htm'),
      'campus',
    ),
    'source host boundary',
  );
  check(
    isNoticeArticle(
      Uri.parse(
        'https://www.wust.edu.cn/system/info.jsp?urltype=news.NewsContentUrl',
      ),
    ),
    'dynamic article URL',
  );
  check(
    resolveNoticeURL('javascript:alert(1)', articleURI) == null,
    'reject script URL',
  );
  check(
    resolveNoticeURL('https://@www.wust.edu.cn/info/1/2.htm', articleURI) ==
        null,
    'reject raw empty user info before URI normalization',
  );
  final detail = parseNoticeDetail(campusNoticeDetailFixture, {
    'title': '回退标题',
    'publishedDate': '2026-11-08',
  }, articleURI);
  check(detail['summary']['title'] == '合成详情', 'metadata title');
  check(
    detail['summary']['publishedDate'] == '2026-11-09',
    'metadata publication date',
  );
  check(
    detail['images'].length == 1 &&
        detail['attachments'].length == 3 &&
        detail['documents'].length == 2,
    'deduplicate images and extract script PDF',
  );
  check(
    detail['text'].contains('列一\t列二') &&
        !detail['text'].contains('hidden-script-text'),
    'table extraction and script exclusion',
  );
  rejects(
    'body_not_found',
    () => parseNoticeDetail('<h1>x</h1>', {}, articleURI),
  );
  rejects(
    'missing_publication_date',
    () => parseNoticeDetail(
      '<meta name="PubDate" content="invalid"><div id="vsb_content">x</div>',
      {'title': 'x', 'publishedDate': '2026-11-09'},
      articleURI,
    ),
  );
  rejects(
    'filtered_publication_date',
    () => parseNoticeDetail('<div id="vsb_content">x</div>', {
      'title': 'x',
      'publishedDate': '1980-01-01',
    }, articleURI),
  );
  final pdf = Uri.parse('https://www.wust.edu.cn/files/test.pdf');
  validateNoticePDF(pdf, articleURI, utf8.encode('%PDF-fixture'));
  check(true, 'valid PDF');
  rejects(
    'invalid_document',
    () => validateNoticePDF(pdf, articleURI, utf8.encode('<html>')),
  );
  rejects(
    'document_too_large',
    () => validateNoticePDF(
      pdf,
      articleURI,
      utf8.encode('%PDF-123'),
      maximumBytes: 5,
    ),
  );
  rejects(
    'unsupported_url',
    () => validateNoticePDF(
      Uri.parse('https://example.test/test.pdf'),
      articleURI,
      [],
    ),
  );
  rejects('unsupported_url', () => validateNoticePDF(pdf, listURI, []));
  final shuttle = parseShuttle(campusShuttleFixture);
  check(
    shuttle['title'] == '测试校车' && shuttle['departures'].length == 2,
    'shuttle title and rowspan',
  );
  check(
    shuttle['departures'][1]['origin'] == '校区甲' &&
        shuttle['departures'][0]['departureTime'] == '07:30',
    'shuttle inherited cells and time',
  );
  check(
    shuttle['notes'].contains('请提前候车') && shuttle['notes'].contains('合成备注'),
    'shuttle notes',
  );
  rejects(
    'invalid_schedule',
    () => parseShuttle(campusShuttleFixture.replaceFirst('17:00', '25:00')),
  );
  final transcript = parseSecondClass(campusSecondClassFixture, {
    'code': 0,
    'data': {'ZXF': '1.5', 'PJ': '合成评价'},
  });
  check(
    transcript['categories'].length == 2 && transcript['earnedCredits'] == 1.5,
    'creditless categories filtered',
  );
  final requirement = transcript['categories'][0]['requirements'][0];
  check(
    requirement['kind'] == 'elective' &&
        requirement['earnedCredits'] == 1.5 &&
        requirement['remainingCredits'] == 0.5,
    'displayed elective score',
  );
  final decimal = parseSecondClass(
    {
      'code': 0,
      'data': {
        'cj': [
          {
            'MKDM': 'decimal',
            'NR': '合成小数学分',
            'XF': '0.3',
            'YXXF': '0.1',
            'BXXF': 0.3,
            'bxyxxf': 0.1,
            'XXXF': 0,
            'xxyxxfR': -0.0,
          },
        ],
      },
    },
    {
      'code': 0,
      'data': {'ZXF': 0.1, 'PJ': '合成评价'},
    },
  );
  check(
    decimal['categories'][0]['requirements'][0]['remainingCredits'] == 0.2,
    'decimal credits do not display floating subtraction noise',
  );
  check(campusInt(2.0) == 2, 'integral numeric library fields');
  for (final value in ['unknown', -1, true, null, 'NaN']) {
    rejects('invalid_response', () => secondClassNumber(value));
  }
  rejects(
    'second_class_rejected_403',
    () => secondClassPayload({'code': '403', 'data': null}),
  );
  rejects(
    'library_rejected_403',
    () => libraryPayload({'code': 403, 'data': null}),
  );
  check(
    parseLibraryPage(libraryPayload({'code': 0, 'data': []}))['total'] == 0,
    'confirmed empty library list',
  );
  rejects(
    'invalid_response',
    () => parseLibraryPage(libraryPayload({'code': 0, 'data': null})),
  );
  rejects(
    'invalid_payload',
    () => parseLibraryPage({'items': []}, strict: true),
  );
  final order = {
    'id': 'running-washer',
    'orderType': 1,
    'orderStatus': 2,
    'parentTypeId': laundryWasherType,
    'machineName': '合成设备',
    'completeTime': '2026-11-09 21:02:22',
  };
  final observed = DateTime.utc(2026, 11, 9, 20);
  final snapshot = laundrySnapshot(
    order,
    observedAt: observed,
    serverDate: laundryServerDate('Mon, 09 Nov 2026 13:00:00 GMT', observed),
  );
  check(snapshot['remainingSeconds'] == 142, 'server clock countdown');
  check(
    DateTime.parse(
          snapshot['estimatedCompletionTime'],
        ).millisecondsSinceEpoch ==
        1794229342000,
    'Shanghai completion time',
  );
  check(
    laundryRemaining(snapshot, observed.add(const Duration(seconds: 10))) ==
        132,
    'elapsed countdown',
  );
  check(
    laundryRemaining(snapshot, observed.add(const Duration(seconds: 200))) == 0,
    'countdown never negative',
  );
  check(
    laundryRemaining(
          snapshot,
          observed.subtract(const Duration(seconds: 10)),
        ) ==
        142,
    'clock rollback does not grow countdown',
  );
  check(
    laundrySnapshot(
          {...order, 'orderStatus': 3},
          observedAt: observed,
          serverDate: observed,
        )['remainingSeconds'] ==
        null,
    'completed has no countdown',
  );
  check(
    laundrySnapshot(
          {...order, 'completeTime': null},
          observedAt: observed,
          serverDate: observed,
        )['remainingSeconds'] ==
        null,
    'missing end time has no countdown',
  );
  rejects(
    'invalid_response',
    () => laundryCompletionDate('2026-02-30 12:00:00'),
  );
  rejects(
    'invalid_response',
    () => laundryCompletionDate('2026-11-09 24:00:00'),
  );
  rejects(
    'laundry_login_required',
    () => laundryPayload({'code': 2, 'data': null}, authenticated: true),
  );
  rejects(
    'laundry_rejected_429',
    () => laundryPayload({'code': 429, 'data': null}),
  );
  check(
    [601, 301, 121, 120].map(laundryCacheLifetime).join(',') == '120,60,30,0',
    'monitor cache boundaries',
  );
  for (final pair in [(1200, 120), (450, 60), (240, 30), (120, 0)]) {
    final sample = {...snapshot, 'remainingSeconds': pair.$1};
    check(
      laundrySnapshotIsFresh(sample, observed) == (pair.$2 > 0),
      'cache initial lifetime',
    );
    if (pair.$2 > 0) {
      check(
        laundrySnapshotIsFresh(
          sample,
          observed.add(Duration(seconds: pair.$2 - 1)),
        ),
        'cache valid before lifetime boundary',
      );
      check(
        !laundrySnapshotIsFresh(
          sample,
          observed.add(Duration(seconds: pair.$2)),
        ),
        'cache expires at lifetime boundary',
      );
    }
  }
  for (final pair in [(601, 61), (301, 31), (121, 2)]) {
    check(
      !laundrySnapshotIsFresh({
        ...snapshot,
        'remainingSeconds': pair.$1,
      }, observed.add(Duration(seconds: pair.$2))),
      'threshold crossing shortens cache lifetime',
    );
  }
  check(
    !laundrySnapshotIsFresh(
      snapshot,
      observed.subtract(const Duration(seconds: 1)),
    ),
    'clock rollback invalidates cache',
  );
  final saved = base64Encode(
    utf8.encode(
      jsonEncode({
        'userID': 'fixture-user',
        'token': 'synthetic-only-token',
        'firstVerifiedAt': 0,
        'lastVerifiedAt': 60,
      }),
    ),
  );
  final credential = CampusLaundryCredential.decode(saved);
  check(
    credential.firstVerifiedAt == DateTime.utc(2001) &&
        credential.lastVerifiedAt == DateTime.utc(2001, 1, 1, 0, 1),
    'Swift date compatibility',
  );
  check(
    CampusLaundryCredential.decode(credential.encode()).token ==
        'synthetic-only-token',
    'legacy Base64 JSON round trip',
  );
  check(
    !credential.toString().contains('synthetic-only-token'),
    'credential description redaction',
  );
  check(
    shuttleSignatureInput('1794229200000') ==
        'timestamp=1794229200000,key=lianyi2019',
    'deterministic signature input',
  );
  final washers = [
    {'id': '4', 'name': '其他'},
    {'id': '3', 'name': '北楼1'},
    {'id': '2', 'name': '南楼10'},
    {'id': '1', 'name': '南楼2'},
  ]..sort(compareLaundryWashers);
  check(
    washers.map((x) => x['id']).join() == '1234',
    'washer direction and numeric sorting',
  );
  return checks;
}

void main() {
  print('Campus parser checks passed: ${runCampusParserChecks()}');
}
