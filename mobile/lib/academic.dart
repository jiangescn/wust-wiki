import 'school_operation_status.dart';
import 'wiki_page.dart';
import 'blog_surface.dart';
import 'archive_motion.dart';
import 'dart:async';
import 'grade_results.dart';
import 'grade_selection.dart';
import 'exam_schedule.dart';
import 'local_academic.dart';
import 'personal_schedule.dart';
import 'foundation/client.dart';
import 'foundation/progress.dart';
import 'foundation/flutter_platform.dart';
import 'foundation/transport.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

typedef Json = Map<String, dynamic>;
const platform = MethodChannel('wiki/native');
const _academicHost = 'schedule.wiki.jianges.com';

class AcademicApiException extends FormatException {
  const AcademicApiException(
    super.message,
    this.status, {
    this.code,
    this.retryAfter,
  });
  final int status;
  final String? code;
  final int? retryAfter;
}

Future<Json>? _loading;
Json _decodeData(String s) => jsonDecode(s) as Json;
Future<Json> get nativeData => _loading ??= rootBundle
    .loadString('assets/native.json')
    .then((s) => compute(_decodeData, s))
    .then((value) {
      _loading = SynchronousFuture(value);
      return value;
    });
DateTime chinaDay([DateTime? time]) {
  final d = (time ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  return DateTime.utc(d.year, d.month, d.day);
}

final autumnStart = DateTime.utc(2026, 8, 31);
bool knownTerm(Json r) =>
    (r['schoolYear'] == null ||
        r['schoolYear'] == '' ||
        r['schoolYear'] == '2026-2027') &&
    (r['semester'] == null || r['semester'] == 1);
int? teachingWeek(Json r, DateTime day) =>
    !knownTerm(r) ||
        day.isBefore(autumnStart) ||
        !day.isBefore(DateTime.utc(2027, 8, 31))
    ? null
    : day.difference(autumnStart).inDays ~/ 7 + 1;
List<int>? rangeList(String text, int limit) {
  if (!RegExp(r'^\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$').hasMatch(text)) return null;
  final values = <int>{};
  for (final g in text.split(',')) {
    final pair = g.split('-').map(int.tryParse).toList();
    final start = pair.first, end = pair.last;
    if (start == null || end == null || start < 1 || end < start || end > limit)
      return null;
    for (int i = start; i <= end; i++) {
      values.add(i);
    }
  }
  return values.toList()..sort();
}

String formatNumberRanges(List<int> values) {
  final ranges = <String>[];
  for (var index = 0; index < values.length;) {
    final first = values[index++];
    while (index < values.length && values[index] == values[index - 1] + 1) {
      index++;
    }
    final last = values[index - 1];
    ranges.add(first == last ? '$first' : '$first–$last');
  }
  return ranges.join('、');
}

class Lesson {
  final Json data;
  final List<int>? weeks, sections;
  Lesson(this.data)
    : weeks = parseWeeks(data['weeks']?.toString() ?? ''),
      sections = parseSections(data);
  String get name => data['name'] ?? '';
  String get place => data['location'] ?? '';
  int get day => data['day'] is int ? data['day'] : 0;
  bool get placed =>
      day >= 1 &&
      day <= 7 &&
      sections != null &&
      weeks != null &&
      weeks!.isNotEmpty;
  static List<int>? parseWeeks(String s) {
    s = s
        .replaceAll(RegExp(r'[\s()（）周]'), '')
        .replaceAll(RegExp('[，、]'), ',')
        .replaceAll(RegExp('[–—~～至]'), '-');
    List<int>? group(String part) {
      final last = part.endsWith('单')
          ? 1
          : part.endsWith('双')
          ? 0
          : null;
      final parsed = rangeList(
        last == null ? part : part.substring(0, part.length - 1),
        60,
      );
      return parsed?.where((week) => last == null || week % 2 == last).toList();
    }

    // A single trailing qualifier applies to a comma-separated set, as in
    // the Wiki parser. Interior qualifiers mark individual week ranges.
    if (!RegExp(r'[单双],').hasMatch(s)) return group(s);
    final result = <int>{};
    for (final part in s.split(',')) {
      final parsed = group(part);
      if (parsed == null) return null;
      result.addAll(parsed);
    }
    return result.toList()..sort();
  }

  static List<int>? parseSections(Json d) {
    final s = d['sections'];
    if (s is String)
      return rangeList(
        s
            .replaceAll(RegExp(r'\s'), '')
            .replaceAll(RegExp('[，、]'), ',')
            .replaceAll(RegExp('[–—~～至]'), '-')
            .replaceFirst(RegExp(r'^第'), '')
            .replaceFirst(RegExp(r'节$'), ''),
        30,
      );
    if (d['start'] is! int) return null;
    final start = d['start'] as int,
        end = d['end'] ?? (start + (d['length'] ?? 1) - 1);
    return rangeList('$start-$end', 30);
  }
}

class AcademicStore extends ChangeNotifier {
  AcademicStore({FoundationApi? foundation})
    : foundation =
          foundation ?? DartFoundationClient(AndroidFoundationPlatform());
  final FoundationApi foundation;

  void cancelLocal() => foundation.cancel();

  List<ScheduledExam>? examSchedule;
  Future<Json>? _examRequest;
  Map<String, Object?>? _examDefaults;
  DateTime? _lastExamRequest;
  int _examAccount = 0;
  bool get syncingExams => _examRequest != null;

  Future<void> ensureExamSchedule() async {
    final last = _lastExamRequest;
    if (!initialized ||
        token != 'local' ||
        syncingExams ||
        (last != null &&
            DateTime.now().difference(last) < const Duration(minutes: 15)))
      return;
    try {
      await queryService('exams');
    } on Exception {
      // The explicit exam page can show the error and retry on request.
    }
  }

  Future<Json> queryService(String resource, {Json options = const {}}) {
    final defaults = _examDefaults;
    final defaultExamQuery =
        options.isEmpty ||
        (defaults != null &&
            options.length == defaults.length &&
            defaults.entries.every((item) => options[item.key] == item.value));
    if (resource != 'exams' || !defaultExamQuery || token != 'local') {
      return _queryService(resource, options);
    }
    final pending = _examRequest;
    if (pending != null) return pending;
    final account = _examAccount;
    _lastExamRequest = DateTime.now();
    final request = _queryService(resource, options)
        .then((result) {
          if (account == _examAccount && result['rows'] is List) {
            examSchedule = readScheduledExams(result['rows']);
            final controls = result['controls'];
            if (controls is List) {
              _examDefaults = {
                for (final item in controls.whereType<Json>())
                  if (item['key'] == 'termID' || item['key'] == 'categoryID')
                    item['key'] as String: item['value'],
              };
            }
          }
          return result;
        })
        .whenComplete(() {
          if (account == _examAccount) {
            _examRequest = null;
            notifyListeners();
          }
        });
    _examRequest = request;
    return request;
  }

  Future<Json> _queryService(String resource, Json options) async {
    final response = await sendLocal({
      'action': 'query',
      'resource': resource,
      'options': options,
    });
    return response['result'] as Json;
  }

  bool localAvailable = false;
  bool localVerified = false, unifiedVerified = false;
  String token = '', campus = 'huangjiahu';
  final _pinnedHomeTools = <String>{};
  Iterable<String> get pinnedHomeTools => _pinnedHomeTools;
  ({String id, String name, String filter})? laundryShop;
  int expires = 0, savedUntil = 0;
  Json? schedule;
  List<Json>? gradeCourses;
  final _academicRequests = <String, Future<Json>>{};
  int _academicAccount = 0;
  bool initialized = false;
  List<Lesson> lessons = [];
  List<PersonalCourse> _personalCourses = [];
  Map<String, DateTime> _termMondays = {};
  String? _lastScheduleTerm;
  String _courseOwner = '';
  bool _writingPersonalCourses = false;

  String get courseOwner => _courseOwner;

  String get courseTerm {
    if (_lastScheduleTerm case final term?) return term;
    final today = chinaDay();
    final startYear = today.month >= 8 ? today.year : today.year - 1;
    final semester = today.month >= 8 || today.month == 1 ? 1 : 2;
    return '$startYear-${startYear + 1}-$semester';
  }

  DateTime? get courseTermMonday =>
      _termMondays[courseTerm] ??
      (courseTerm == '2026-2027-1' ? autumnStart : null);

  DateTime? courseWeekStart(int week) =>
      courseTermMonday?.add(Duration(days: (week - 1) * 7));

  int? courseWeekOn(DateTime date) {
    final monday = courseTermMonday;
    return monday == null ? null : weekAt(monday, date);
  }

  List<Lesson> get displayedLessons => [
    ...lessons,
    for (final course in _personalCourses)
      if (course.term == courseTerm &&
          (course.owner.isEmpty || course.owner == _courseOwner))
        ...course.lessons(courseTermMonday),
  ];

  Future<void> _restorePersonalCourses() async {
    try {
      final saved = await platform.invokeMethod<String>('loadPersonalSchedule');
      if (saved == null) return;
      final data = jsonDecode(saved);
      if (data is! Json) return;
      if (data['courses'] case final List courses) {
        _personalCourses = courses
            .whereType<Json>()
            .map(PersonalCourse.read)
            .nonNulls
            .toList();
      }
      if (data['mondays'] case final Json mondays) {
        for (final entry in mondays.entries) {
          final day = DateTime.tryParse(entry.value.toString());
          if (day != null && day.weekday == DateTime.monday) {
            _termMondays[entry.key] = calendarDate(day);
          }
        }
      }
    } on Exception {
      return;
    }
  }

  String _ownerKey(String username) =>
      sha256.convert(utf8.encode(username)).toString();

  Future<void> savePersonalCourse(
    PersonalCourse course, {
    required DateTime monday,
  }) async {
    if (_writingPersonalCourses ||
        course.term != courseTerm ||
        (course.owner.isNotEmpty && course.owner != _courseOwner)) {
      throw const FormatException('课表已切换，请重新打开课程。');
    }
    final next = [..._personalCourses];
    final existing = next.indexWhere((item) => item.id == course.id);
    if (existing >= 0) next.removeAt(existing);
    if (course.times.isNotEmpty) {
      next.insert(existing < 0 ? next.length : existing, course);
    }
    final mondays = {..._termMondays, course.term: monday};
    _writingPersonalCourses = true;
    try {
      await platform.invokeMethod<void>(
        'savePersonalSchedule',
        jsonEncode({
          'version': 1,
          'courses': next.map((item) => item.toJson()).toList(),
          'mondays': mondays.map((term, day) => MapEntry(term, dateLabel(day))),
        }),
      );
      _personalCourses = next;
      _termMondays = mondays;
      notifyListeners();
    } finally {
      _writingPersonalCourses = false;
    }
  }

  bool get loggedIn => token.isNotEmpty;
  String _restoredToken = '';
  Future<void>? _initializing;
  Future<void> init() => _initializing ??= _restore();
  Future<void> _restore() async {
    final personal = _restorePersonalCourses();
    try {
      final raw = await platform.invokeMapMethod<String, dynamic>('restore');
      if (raw != null) {
        localAvailable = raw['localAvailable'] == true;
        token = raw['token'] ?? '';
        if (token == 'local' && raw['localSaved'] != true) token = '';
        if (localAvailable && raw['localSaved'] == true) token = 'local';
        final client = foundation;
        if (token == 'local' && client is DartFoundationClient) {
          try {
            final account = await client.platform.load('active-account');
            if (account != null && account.isNotEmpty)
              _courseOwner = _ownerKey(account);
          } on Exception {
            // Personal schedules remain available without an account.
          }
        }
        _restoredToken = token;
        expires = raw['expires'] ?? 0;
        if (raw['campus'] == 'qingshan' || raw['campus'] == 'huangjiahu') {
          campus = raw['campus'];
        }
        if (raw['pinnedHomeTools'] case final String pins) {
          _pinnedHomeTools.addAll(
            pins.split('\n').where((path) => path.isNotEmpty),
          );
        }
        if (raw['laundryShopId'] case final String id when id.isNotEmpty) {
          if (raw['laundryShopName'] case final String name
              when name.isNotEmpty) {
            final filter = raw['laundryShopFilter'];
            laundryShop = (
              id: id,
              name: name,
              filter: filter is String ? filter : '',
            );
          }
        }
        final cached = jsonDecode(raw['snapshot'] ?? 'null');
        final now = DateTime.now().millisecondsSinceEpoch;
        if (cached is Json &&
            cached['result'] is Json &&
            cached['result']['lessons'] is List &&
            cached['expiresAt'] is int &&
            cached['fetchedAt'] is int &&
            cached['expiresAt'] ==
                cached['fetchedAt'] + const Duration(days: 7).inMilliseconds &&
            cached['fetchedAt'] <= now &&
            cached['expiresAt'] > now)
          acceptCache(cached['result'], cached['expiresAt']);
      }
    } on Exception {
      /* No usable previous cache. */
    }
    await personal;
    initialized = true;
    notifyListeners();
  }

  void acceptCache(Json data, int until) {
    lessons = (data['lessons'] as List)
        .whereType<Json>()
        .map(Lesson.new)
        .toList();
    schedule = data;
    final year = data['schoolYear']?.toString() ?? '';
    final semester = data['semester']?.toString();
    if (RegExp(r'^\d{4}-\d{4}$').hasMatch(year)) {
      _lastScheduleTerm = '$year-${semester == '2' ? '2' : '1'}';
    } else if (knownTerm(data)) {
      _lastScheduleTerm = '2026-2027-1';
    }
    savedUntil = until;
  }

  void expire() {
    if (schedule != null &&
        DateTime.now().millisecondsSinceEpoch >= savedUntil) {
      schedule = null;
      lessons = [];
      notifyListeners();
    }
  }

  Future<void> saveCampus(String value) async {
    campus = value;
    notifyListeners();
    await platform.invokeMethod('save', {'campus': value});
  }

  Future<void> setHomeToolPinned(String path, bool pinned) async {
    final changed = pinned
        ? _pinnedHomeTools.add(path)
        : _pinnedHomeTools.remove(path);
    if (!changed) return;
    notifyListeners();
    try {
      await platform.invokeMethod<void>('save', {
        'pinnedHomeTools': _pinnedHomeTools.join('\n'),
      });
    } on Exception {
      return;
    }
  }

  Future<void> rememberLaundryShop(
    String id,
    String name, {
    String filter = '',
  }) async {
    laundryShop = (id: id, name: name, filter: filter);
    try {
      await platform.invokeMethod<void>('save', {
        'laundryShopId': id,
        'laundryShopName': name,
        'laundryShopFilter': filter,
      });
    } on Exception {
      return;
    }
  }

  Future<void> saveSchedule(Json data) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    acceptCache(data, now + const Duration(days: 7).inMilliseconds);
    notifyListeners();
    await platform.invokeMethod('save', {
      'snapshot': jsonEncode({
        'version': 1,
        'fetchedAt': now,
        'expiresAt': savedUntil,
        'result': data,
      }),
    });
  }

  Future<void> clearSchedule() async {
    schedule = null;
    lessons = [];
    savedUntil = 0;
    notifyListeners();
    await platform.invokeMethod('save', {'snapshot': ''});
  }

  Future<void> remember(String value, int until) async {
    final switched = token != value;
    if (switched) {
      _academicAccount++;
      _academicRequests.clear();
      gradeCourses = null;
      schedule = null;
      _lastScheduleTerm = null;
      lessons = [];
      savedUntil = 0;
    }
    _restoredToken = '';
    token = value;
    if (value != 'local') _courseOwner = '';
    if (value != 'local') {
      _examAccount++;
      examSchedule = null;
      _examDefaults = null;
      _examRequest = null;
      _lastExamRequest = null;
      localVerified = false;
      unifiedVerified = false;
    }
    expires = until;
    notifyListeners();
    await platform.invokeMethod('save', {
      'token': value,
      'expires': until,
      if (switched) 'snapshot': '',
    });
  }

  Future<void> logout() async {
    final old = token;
    await remember('', 0);
    if (old.isNotEmpty) await api('logout', old);
  }

  Future<void> loginLocal(String username, String password) async {
    await remember('', 0);
    await sendLocal({
      'action': 'login',
      'username': username,
      'password': password,
    });
    _courseOwner = _ownerKey(username.trim());
    await remember('local', 0);
    unawaited(loadAcademicOverview());
  }

  Future<void> loadAcademicOverview() async {
    final account = _academicAccount;
    for (final resource in ['schedule', 'grades']) {
      if (account != _academicAccount || !loggedIn) return;
      if (resource == 'grades' && gradeCourses != null) return;
      try {
        await academicResult(resource);
      } on Exception {
        // Each resource has its own retry entry.
      }
    }
  }

  Future<Json> academicResult(String resource) {
    final pending = _academicRequests[resource];
    if (pending != null) return pending;
    final account = _academicAccount;
    final bearer = token;
    final request = _fetchAcademicResult(resource, bearer, account)
        .whenComplete(() {
          if (_academicAccount == account) _academicRequests.remove(resource);
        });
    _academicRequests[resource] = request;
    return request;
  }

  Future<Json> _fetchAcademicResult(
    String resource,
    String bearer,
    int account,
  ) async {
    final response = await api('query', bearer, resource: resource);
    if (account != _academicAccount) {
      throw const FormatException('学校账号已切换');
    }
    if (response['state'] != 'complete' || response['result'] is! Json) {
      throw FormatException(response['message'] ?? '教务查询尚未完成');
    }
    final data = response['result'] as Json;
    switch (resource) {
      case 'schedule':
        if (data['lessons'] is! List) throw const FormatException('课表读取失败');
        await saveSchedule(data);
      case 'grades':
        if (data['courses'] is! List) throw const FormatException('成绩读取失败');
        gradeCourses = (data['courses'] as List).cast<Json>();
        notifyListeners();
    }
    return data;
  }

  Future<Json> sendLocal(Json body) async {
    try {
      final data = await foundation.request(body);
      if (data['unifiedVerified'] == true) {
        unifiedVerified = true;
        notifyListeners();
      }
      if (data['academicVerified'] == true) {
        localVerified = true;
        notifyListeners();
      }
      return data;
    } on FoundationException catch (error) {
      if ({
        'credentials_rejected',
        'account_locked',
        'password_expired',
        'interactive_login_required',
        'login_required',
      }.contains(error.code)) {
        unifiedVerified = false;
        localVerified = false;
        examSchedule = null;
        notifyListeners();
      }
      final campusQuery =
          body['action'] == 'query' &&
          DartFoundationClient.campusResources.contains(body['resource']);
      if (!campusQuery) {
        localVerified = false;
        if (error.code == 'login_required' && token == 'local') {
          await remember('', 0);
        }
      }
      throw AcademicApiException(
        error.message,
        {
              'login_required',
              'credentials_rejected',
              'password_expired',
              'account_locked',
            }.contains(error.code)
            ? 401
            : 502,
        code: error.code,
      );
    }
  }

  Future<Json> api(String action, String bearer, {String? resource}) async {
    if (action == 'query' && bearer.isNotEmpty && bearer == _restoredToken) {
      final session = await sendAcademic({'action': 'inspect'}, bearer);
      if (token != bearer || session['state'] != 'authenticated') {
        if (token == bearer) await remember('', 0);
        throw const AcademicApiException('请重新登录教务。', 401);
      }
      _restoredToken = '';
    }
    return sendAcademic({
      'action': action,
      if (resource != null) 'resource': resource,
    }, bearer);
  }

  Future<Json> sendAcademic(Json body, String bearer) async {
    if (bearer == 'local') return sendLocal(body);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      return await (() async {
        final req = await client.postUrl(
          Uri.https(_academicHost, '/api/academic'),
        );
        req.followRedirects = false;
        req.headers.contentType = ContentType.json;
        req.headers.set('Origin', 'https://wiki.wustacm.com');
        if (bearer.isNotEmpty)
          req.headers.set('Authorization', 'Bearer $bearer');
        req.write(jsonEncode({...body, 'sessionPolicy': 'school'}));
        final response = await req.close();
        final raw = await utf8.decoder.bind(response).join();
        Object? data;
        try {
          data = jsonDecode(raw);
        } on FormatException {
          if (response.statusCode == 200) rethrow;
        }
        if (response.statusCode == 401 && bearer.isNotEmpty && bearer == token)
          await remember('', 0);
        if (response.statusCode != 200 || data is! Json)
          throw AcademicApiException(
            data is Json && data['message'] is String
                ? data['message'] as String
                : '教务服务暂不可用',
            response.statusCode,
            code: data is Json && data['code'] is String
                ? data['code'] as String
                : null,
            retryAfter: int.tryParse(
              response.headers.value(HttpHeaders.retryAfterHeader) ?? '',
            ),
          );
        return data;
      })().timeout(const Duration(seconds: 45));
    } finally {
      client.close(force: true);
    }
  }
}

class AcademicQuery extends StatefulWidget {
  final AcademicStore store;
  final String resource;
  final VoidCallback? onClose;
  final WidgetBuilder? manualGpa;
  final WikiPageMark? mark;
  const AcademicQuery(
    this.store,
    this.resource, {
    this.onClose,
    this.manualGpa,
    this.mark,
    super.key,
  });
  @override
  State<AcademicQuery> createState() => _QueryState();
}

class _QueryState extends State<AcademicQuery> with WidgetsBindingObserver {
  bool localForm = false, remoteMode = false;
  String pending = '', qr = '', message = '正在连接学校教务服务…';
  Uri? schoolLogin;
  bool schoolPortalOpen = false;
  DateTime? lastPoll;
  int until = 0, run = 0;
  bool busy = false, foreground = true, failed = false;
  bool loginRequired = false;
  FoundationProgress? waiting;
  List<Json>? grades;
  Timer? timer;
  AcademicStore get store => widget.store;

  void openManualGpa() => Navigator.of(context).push(
    WikiRoute(
      widget.manualGpa!(context),
      MediaQuery.disableAnimationsOf(context),
    ),
  );

  FoundationProgress phase(String label, {String? resource}) =>
      FoundationProgress(
        message: label,
        startedAt: waiting?.startedAt ?? DateTime.now(),
        activeCount: 1,
        resource: resource,
      );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    begin();
  }

  void discard(String t) {
    if (t.isNotEmpty)
      unawaited(store.api('logout', t).then<void>((_) {}).catchError((_) {}));
  }

  Future<void> begin() async {
    final n = ++run;
    timer?.cancel();
    discard(pending);
    pending = '';
    lastPoll = null;
    setState(() {
      qr = '';
      schoolLogin = null;
      schoolPortalOpen = false;
      message = '正在连接学校教务服务…';
      failed = false;
      loginRequired = false;
      waiting = null;
      waiting = phase('正在恢复会话');
    });
    try {
      await store.init();
      if (!mounted || run != n) return;
      if (widget.resource == 'login' && store.localAvailable && !remoteMode) {
        setState(() => localForm = true);
        return;
      }
      if (store.loggedIn && !(remoteMode && widget.resource == 'login')) {
        await query(n);
        return;
      }
      if (widget.resource != 'login') {
        setState(() {
          waiting = null;
          loginRequired = true;
          message = widget.resource == 'gpa' ? '登录后可使用已有成绩' : '请先在「个人」登录教务。';
        });
        return;
      }
      setState(() => waiting = phase('正在登录统一认证', resource: 'login'));
      final d = await store.api('start', '');
      final t = d['sessionToken'] as String;
      if (!mounted || n != run) {
        discard(t);
        return;
      }
      pending = t;
      until = d['expiresAt'];
      if (d['state'] != 'waiting' && d['state'] != 'scanned') {
        throw FormatException(d['message'] ?? '请重新开始登录。');
      }
      final link = d['schoolLoginUrl'];
      final uri = link is String ? Uri.tryParse(link) : null;
      setState(() {
        waiting = null;
        qr = d['qr'] as String? ?? '';
        if (uri != null &&
            uri.scheme == 'https' &&
            uri.host == 'auth.wust.edu.cn' &&
            uri.path == '/authserver/qrCode/qrCodeLogin.do' &&
            uri.userInfo.isEmpty &&
            uri.port == 443) {
          schoolLogin = uri;
        }
        message = schoolLogin != null
            ? '请在学校认证页面完成登录。'
            : d['message'] ?? '使用另一台设备扫码，在学校页面确认登录。';
      });
      schedulePoll();
    } catch (e) {
      error(n, e);
    }
  }

  bool hasCurrentLogin() {
    if (pending.isEmpty) return false;
    if (DateTime.now().millisecondsSinceEpoch >= until) {
      error(run, const FormatException('登录链接已过期，请重新生成。'));
      return false;
    }
    return true;
  }

  void openSchoolLogin() {
    if (schoolLogin == null || !hasCurrentLogin()) return;
    setState(() => schoolPortalOpen = true);
  }

  Future<void> openSchoolInBrowser() async {
    final uri = schoolLogin;
    if (uri == null || !hasCurrentLogin()) return;
    final n = run;
    var opened = false;
    try {
      opened =
          await platform.invokeMethod<bool>('external', uri.toString()) == true;
    } on PlatformException {
      opened = false;
    }
    if (!mounted || run != n || pending.isEmpty) return;
    setState(() {
      schoolPortalOpen = false;
      message = opened ? '在学校页面完成验证后切回应用。' : '无法打开浏览器，可使用二维码登录。';
    });
  }

  Future<void> openWechat() async {
    if (qr.isEmpty || !hasCurrentLogin()) return;
    await platform.invokeMethod<void>('wechat', {'qr': qr, 'mode': 'confirm'});
  }

  void error(int n, Object e) {
    if (!mounted || n != run) return;
    timer?.cancel();
    discard(pending);
    pending = '';
    setState(() {
      failed = true;
      waiting = null;
      final code = e is AcademicApiException ? e.code : null;
      loginRequired = const {
        'credentials_rejected',
        'password_expired',
        'login_required',
        'account_locked',
      }.contains(code);
      qr = '';
      schoolLogin = null;
      schoolPortalOpen = false;
      message = switch (code) {
        'credentials_rejected' => '账号或密码错误，请修改后重新登录',
        'password_expired' => '统一认证密码已过期，请修改后重新登录',
        _ => e is FormatException ? e.message : '无法连接教务服务，请重试。',
      };
    });
  }

  void schedulePoll([Duration delay = const Duration(milliseconds: 3100)]) {
    timer?.cancel();
    if (foreground && pending.isNotEmpty) timer = Timer(delay, poll);
  }

  Future<void> poll() async {
    if (busy || pending.isEmpty || !foreground) return;
    final now = DateTime.now();
    final previous = lastPoll;
    if (previous != null) {
      final wait =
          const Duration(milliseconds: 3100) - now.difference(previous);
      if (wait > Duration.zero) {
        schedulePoll(wait);
        return;
      }
    }
    final n = run;
    busy = true;
    try {
      if (DateTime.now().millisecondsSinceEpoch >= until)
        throw const FormatException('登录已过期，请重新生成。');
      lastPoll = now;
      final d = await store.api('poll', pending);
      if (!mounted || run != n) return;
      if (d['state'] == 'authenticated') {
        final t = pending;
        pending = '';
        setState(() {
          qr = '';
          schoolLogin = null;
          schoolPortalOpen = false;
          message = '已确认登录';
          waiting = null;
        });
        await store.remember(t, d['expiresAt']);
        unawaited(store.loadAcademicOverview());
        if (mounted && run == n) await query(n);
      } else if (d['state'] == 'waiting' || d['state'] == 'scanned') {
        final status = d['message'];
        if (d['state'] == 'scanned') {
          setState(() {
            if (status is String && status.isNotEmpty) message = status;
            waiting = phase('正在验证登录', resource: 'login');
          });
        }
        schedulePoll();
      } else {
        throw FormatException(d['message'] ?? '请重新登录。');
      }
    } catch (e) {
      error(n, e);
    } finally {
      busy = false;
    }
  }

  Future<void> query(int n, {bool refresh = false}) async {
    if (widget.resource == 'login') {
      if (mounted && run == n) {
        if (widget.onClose != null) {
          widget.onClose!();
        } else {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('教务登录成功')));
      }
      return;
    }
    final resource = widget.resource == 'gpa' ? 'grades' : widget.resource;
    final cached = store.gradeCourses;
    if (resource == 'grades' && cached != null && !refresh) {
      setState(() {
        grades = cached;
        message = '';
        waiting = null;
      });
      return;
    }
    setState(
      () => waiting = phase(
        '正在查询${schoolResourceLabel(resource)}',
        resource: resource,
      ),
    );
    final data = await store.academicResult(resource);
    if (!mounted || n != run) return;
    if (widget.resource == 'schedule') {
      Navigator.pop(context);
    } else {
      setState(() {
        grades = (data['courses'] as List).cast<Json>();
        message = '';
        waiting = null;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) {
      timer?.cancel();
      poll();
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    run++;
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    discard(pending);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (localForm)
      return LocalAcademicLogin(
        store,
        mark: widget.mark,
        onClose: widget.onClose,
        onLegacy: () {
          setState(() {
            localForm = false;
            remoteMode = true;
          });
          begin();
        },
      );
    final portal = schoolPortalOpen ? schoolLogin : null;
    final entries = grades;
    if (entries != null && widget.resource == 'gpa') {
      return GradeSelection(
        entries,
        mark: widget.mark,
        onManual: widget.manualGpa == null ? null : openManualGpa,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: WikiPageTitle(
          portal != null
              ? '学校统一认证'
              : widget.resource == 'login'
              ? '教务登录'
              : widget.resource == 'schedule'
              ? '同步课表'
              : widget.resource == 'gpa'
              ? '绩点计算'
              : '成绩查询',
          mark: widget.mark,
        ),
        leading: widget.onClose != null
            ? BackButton(onPressed: widget.onClose)
            : null,
        actions: [
          if (entries != null && widget.resource == 'grades')
            IconButton(
              tooltip: '刷新成绩',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: waiting == null
                  ? () async {
                      final n = run;
                      try {
                        await query(n, refresh: true);
                      } on Exception {
                        if (!mounted || n != run) return;
                        setState(() => waiting = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('成绩刷新失败，请重试')),
                        );
                      }
                    }
                  : null,
            ),
          if (portal != null)
            IconButton(
              tooltip: '用系统浏览器打开',
              onPressed: openSchoolInBrowser,
              icon: const Icon(Icons.open_in_browser),
            ),
          if (portal != null && qr.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => schoolPortalOpen = false),
              child: const Text('使用二维码'),
            ),
        ],
      ),
      bottomNavigationBar: widget.manualGpa == null
          ? null
          : ManualGpaFooter(onPressed: openManualGpa),
      body: SafeArea(
        child: portal != null
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SchoolOperationStatus(
                      store.foundation,
                      fallback: waiting,
                    ),
                  ),
                  Expanded(
                    child: AndroidView(
                      viewType: 'wiki/school-portal',
                      creationParams: portal.toString(),
                      creationParamsCodec: const StandardMessageCodec(),
                    ),
                  ),
                ],
              )
            : entries == null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  SchoolOperationStatus(store.foundation, fallback: waiting),
                  if (widget.resource == 'login' &&
                      store.localAvailable &&
                      remoteMode)
                    TextButton(
                      onPressed: () {
                        remoteMode = false;
                        begin();
                      },
                      child: const Text('账号密码自动登录'),
                    ),
                  if (schoolLogin != null) ...[
                    ContentReveal.grouped(
                      FilledButton.icon(
                        onPressed: openSchoolLogin,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('打开学校认证'),
                      ),
                    ),
                    TextButton(
                      onPressed: openSchoolInBrowser,
                      child: const Text('用系统浏览器打开'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (qr.isNotEmpty) ...[
                    ContentReveal.grouped(
                      Center(
                        child: Image.memory(
                          base64Decode(qr.split(',').last),
                          width: 235,
                          height: 235,
                          semanticLabel: '学校统一认证登录二维码',
                        ),
                      ),
                      revision: qr,
                    ),
                    const SizedBox(height: 16),
                    const Center(child: Text('也可用另一台设备扫码')),
                    Center(
                      child: TextButton(
                        onPressed: openWechat,
                        child: const Text('用微信扫码'),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (waiting == null && message.isNotEmpty)
                    ContentReveal.grouped(
                      BlogPanel(
                        Row(
                          children: [
                            BlogIcon(
                              widget.resource == 'login'
                                  ? Icons.lock_outline
                                  : Icons.school_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ArchivePart(
                                axis: ArchiveRevealAxis.vertical,
                                travel: const Offset(0, 5),
                                child: Text(message),
                              ),
                            ),
                          ],
                        ),
                      ),
                      revision: message,
                    ),
                  if (loginRequired && widget.resource != 'login')
                    FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AcademicQuery(store, 'login'),
                          ),
                        );
                        if (mounted &&
                            store.loggedIn &&
                            (store.token != 'local' || store.unifiedVerified))
                          begin();
                      },
                      child: Text(failed ? '更新学校账号' : '学校统一认证'),
                    )
                  else if (failed)
                    TextButton(
                      onPressed: begin,
                      child: Text(
                        widget.resource == 'login' ? '重新开始登录' : '重新查询',
                      ),
                    ),
                ],
              )
            : Column(
                children: [
                  if (waiting != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SchoolOperationStatus(
                        store.foundation,
                        fallback: waiting,
                      ),
                    ),
                  Expanded(child: GradeResults(entries)),
                ],
              ),
      ),
    );
  }
}
