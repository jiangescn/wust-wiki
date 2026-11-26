import 'dart:convert';
import 'dart:typed_data';

import '../../lib/foundation/academic_queries.dart';
import '../../lib/foundation/transport.dart';
import 'academic_fixtures.dart';

typedef RequestCheck =
    void Function(
      Uri uri,
      String method,
      Map<String, String>? form,
      Map<String, String> headers,
    );

class AcademicReply {
  AcademicReply(
    this.body, {
    this.path,
    this.status = 200,
    this.check,
    this.raw,
  });
  final String body;
  final String? path;
  final int status;
  final RequestCheck? check;
  final List<int>? raw;
}

class AcademicFakeTransport extends SchoolTransport {
  AcademicFakeTransport(this.replies);
  final List<AcademicReply> replies;
  int sent = 0;

  @override
  Future<SchoolResponse> send(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? form,
    List<MapEntry<String, String>>? formFields,
    Object? jsonBody,
    Map<String, String> headers = const {},
    bool followRedirects = true,
  }) async {
    if (sent >= replies.length) throw StateError('Unexpected HTTP request');
    final reply = replies[sent++];
    reply.check?.call(
      uri,
      method,
      form ?? (formFields == null ? null : Map.fromEntries(formFields)),
      headers,
    );
    return SchoolResponse(
      status: reply.status,
      uri: reply.path == null ? uri : uri.resolve(reply.path!),
      bytes: Uint8List.fromList(reply.raw ?? utf8.encode(reply.body)),
      headers: const {'date': 'Thu, 05 Nov 2026 02:00:00 GMT'},
    );
  }
}

void expect(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> rejects(Future<Object?> Function() body, String code) async {
  try {
    await body();
  } on FoundationException catch (e) {
    expect(e.code == code, 'Expected $code, got ${e.code}');
    return;
  }
  throw StateError('Expected FoundationException($code)');
}

Future<void> main() async {
  var passed = 0;
  Future<void> test(String name, Future<void> Function() run) async {
    await run();
    passed++;
  }

  await test('schedule posts all semester and checks reflection', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(
        academicScheduleFixture(),
        check: (uri, method, fields, headers) {
          expect(
            uri.path == '/jsxsd/xskb/xskb_list.do' && method == 'GET',
            'Schedule entry',
          );
        },
      ),
      AcademicReply(
        academicScheduleFixture(),
        check: (uri, method, fields, headers) {
          expect(
            method == 'POST' &&
                fields!['xnxq01id'] == academicTerm &&
                fields['zc'] == '',
            'Semester POST',
          );
          expect(
            fields!['csrf'] == 'A+B&中' && fields['kbjcmsid'] == 'template-1',
            'Hidden preservation',
          );
          expect(headers['Referer'] == uri.toString(), 'Referer');
        },
      ),
    ]);
    final result = await AcademicQueries(fake).query('schedule');
    expect(result['lessons'].length == 1 && fake.sent == 2, 'Schedule mapped');
    expect(result['controls'][0]['key'] == 'termID', 'Public option keys');
    fake.close();
  });
  await test('schedule rejects stale term reflection', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(academicScheduleFixture()),
      AcademicReply(academicScheduleFixture(term: '2026-2027-2')),
    ]);
    await rejects(
      () => AcademicQueries(fake).query('schedule'),
      'selection_not_reflected',
    );
    fake.close();
  });
  await test('grades posts retake, course and literal hidden values', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(academicGradeFormFixture()),
      AcademicReply(
        academicGradesFixture(),
        check: (uri, method, fields, headers) {
          expect(
            uri.path == '/jsxsd/kscj/cjcx_list' && method == 'POST',
            'Grades endpoint',
          );
          expect(
            fields!['csrf'] == 'A+B&中' && fields['sfxsbcxq'] == '1',
            'Retakes and hidden fields',
          );
          expect(
            fields['kcmc'] == '合成+课程' &&
                fields['xsfs'] == 'all' &&
                fields['kksj'] == '',
            'All semester with exact filter',
          );
        },
      ),
    ]);
    final result = await AcademicQueries(
      fake,
    ).query('grades', options: {'courseName': '合成+课程'});
    expect(result['courses'].length == 2, 'Retakes retained');
    fake.close();
  });
  await test('grade invalid option never reaches POST', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(academicGradeFormFixture()),
    ]);
    await rejects(
      () => AcademicQueries(
        fake,
      ).query('grades', options: {'termID': 'not-offered'}),
      'invalid_query',
    );
    expect(fake.sent == 1, 'No invalid POST');
    fake.close();
  });
  await test('exam category label comes from school form', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(academicExamFormFixture()),
      AcademicReply(
        academicExamsFixture(),
        check: (uri, method, fields, headers) {
          expect(
            method == 'POST' &&
                fields!['xnxqid'] == academicTerm &&
                fields['xqlb'] == 'final' &&
                fields['xqlbmc'] == '期末',
            'Exam category selected',
          );
          expect(fields!['csrf'] == 'A+B&中', 'Exam hidden retained');
        },
      ),
    ]);
    expect(
      (await AcademicQueries(
            fake,
          ).query('exams', options: {'categoryID': 'final'}))['rows'].length ==
          1,
      'Exam rows',
    );
    fake.close();
  });
  await test('calendar posts ISO Shanghai day', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(
        '<li id="li_showWeek">第10周/22周</li>',
        check: (uri, method, fields, headers) {
          expect(
            uri.path == '/jsxsd/framework/main_index_loadkb.jsp' &&
                method == 'POST' &&
                fields!['rq'] == '2026-11-05',
            'ISO request date',
          );
        },
      ),
    ]);
    expect(
      (await AcademicQueries(
            fake,
          ).query('calendar', options: {'date': '20261105'}))['rows'].length ==
          23,
      'Calendar range',
    );
    fake.close();
  });
  await test('student and credits actual endpoints', () async {
    for (final resource in ['student', 'credits']) {
      final fake = AcademicFakeTransport([
        AcademicReply(
          resource == 'student'
              ? academicStudentFixture()
              : academicCreditsFixture(),
          check: (uri, method, fields, headers) {
            expect(
              uri.path ==
                      (resource == 'student'
                          ? '/jsxsd/grxx/xsxx'
                          : '/jsxsd/xxwcqk/xxwcqk_idxOnzh.do') &&
                  method == 'GET',
              'Official endpoint',
            );
          },
        ),
      ]);
      expect(
        (await AcademicQueries(fake).query(resource))['rows'].isNotEmpty,
        'Rows present',
      );
      fake.close();
    }
  });
  await test(
    'authentication redirects, login HTML and status fail explicitly',
    () async {
      for (final reply in [
        AcademicReply('', status: 401),
        AcademicReply('', path: 'https://auth.wust.edu.cn/login'),
        AcademicReply('<title>登录</title><input type="password">'),
      ]) {
        final fake = AcademicFakeTransport([reply]);
        await rejects(
          () => AcademicQueries(fake).query('student'),
          'authentication_required',
        );
        fake.close();
      }
      final foreign = AcademicFakeTransport([
        AcademicReply('', path: 'https://evil.invalid/jsxsd/grxx/xsxx'),
      ]);
      await rejects(
        () => AcademicQueries(foreign).query('student'),
        'unexpected_redirect',
      );
      foreign.close();
      final status = AcademicFakeTransport([AcademicReply('', status: 503)]);
      await rejects(
        () => AcademicQueries(status).query('student'),
        'unexpected_status',
      );
      status.close();
    },
  );
  await test('foreign action never sent', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(
        academicScheduleFixture(action: 'https://evil.invalid/collect'),
      ),
    ]);
    await rejects(
      () => AcademicQueries(fake).query('schedule'),
      'unsupported_form',
    );
    expect(fake.sent == 1, 'No foreign request');
    fake.close();
    final badEncoding = AcademicFakeTransport([
      AcademicReply('', raw: [0xff, 0xfe]),
    ]);
    await rejects(
      () => AcademicQueries(badEncoding).query('student'),
      'invalid_encoding',
    );
    badEncoding.close();
  });
  await test(
    'raw collection returns byte-identical files after selection validation',
    () async {
      final entry = academicScheduleFixture(),
          semester = academicScheduleFixture(),
          weekly = academicScheduleFixture(
            week: '2',
            course: academicCourse(time: '2(周)[01节]'),
          );
      final fake = AcademicFakeTransport([
        AcademicReply(entry),
        AcademicReply(semester),
        AcademicReply(
          weekly,
          check: (uri, method, fields, headers) {
            expect(
              fields!['zc'] == '2' && fields['xnxq01id'] == academicTerm,
              'Weekly selection',
            );
          },
        ),
      ]);
      final result = await AcademicQueries(
        fake,
      ).query('raw-schedule', options: {'week': '2'});
      expect(result['files'].length == 3, 'Three captures');
      expect(
        utf8.decode(base64Decode(result['files'][0]['base64'])) == entry,
        'Raw bytes preserved',
      );
      expect(
        result['rows'].toString().contains('周课表内容变化, value: 是'),
        'Grid compared',
      );
      fake.close();
    },
  );
  await test('training plan local filter and directory validation', () async {
    final fake = AcademicFakeTransport([
      AcademicReply(academicTrainingFixture()),
    ]);
    expect(
      (await AcademicQueries(fake).query(
            'training-plan',
            options: {'courseName': '乙'},
          ))['rows'].length ==
          2,
      'Training filter',
    );
    fake.close();
    const directory =
        '<a href="/jsxsd/pyfa/detail?id=synthetic">合成目录</a><a href="https://evil.invalid/">外站</a><a href="javascript:showPlan()">脚本链接</a>';
    final listing = AcademicFakeTransport([AcademicReply(directory)]);
    final result = await AcademicQueries(listing).query('training-plan');
    expect(result['actions'].length == 1, 'Only school plan actions');
    listing.close();
    final selected = AcademicFakeTransport([
      AcademicReply(directory),
      AcademicReply(academicTrainingFixture()),
    ]);
    expect(
      (await AcademicQueries(selected).query(
            'training-plan',
            options: {
              'planHref':
                  'https://bkjx.wust.edu.cn/jsxsd/pyfa/detail?id=synthetic',
            },
          ))['rows'].length ==
          3,
      'Directory navigation',
    );
    selected.close();
    final bad = AcademicFakeTransport([AcademicReply(directory)]);
    await rejects(
      () => AcademicQueries(
        bad,
      ).query('training-plan', options: {'planHref': 'https://evil.invalid/'}),
      'invalid_query',
    );
    bad.close();
  });
  await test(
    'training form keeps hidden fields and validates reflected filters',
    () async {
      String form(String value) =>
          '<form id="planQuery" method="post" action="/jsxsd/pyfa/topyfamx"><input type="hidden" name="csrf" value="A+B&amp;中"><select name="major"><option value="a" ${value == 'a' ? 'selected' : ''}>合成专业甲</option><option value="b" ${value == 'b' ? 'selected' : ''}>合成专业乙</option></select></form>';
      final initial = AcademicFakeTransport([AcademicReply(form('a'))]);
      final initialResult = await AcademicQueries(
        initial,
      ).query('training-plan');
      expect(
        initial.sent == 1 &&
            initialResult['controls'].length == 1 &&
            initialResult['rows'].isEmpty,
        'Initial form does not submit',
      );
      initial.close();
      final hidden = AcademicFakeTransport([AcademicReply(form('a'))]);
      await rejects(
        () => AcademicQueries(hidden).query(
          'training-plan',
          options: {
            'fields': {'csrf': 'override'},
          },
        ),
        'invalid_query',
      );
      hidden.close();
      final topLevel = AcademicFakeTransport([
        AcademicReply(form('a')),
        AcademicReply(form('b') + academicTrainingFixture()),
      ]);
      expect(
        (await AcademicQueries(
              topLevel,
            ).query('training-plan', options: {'major': 'b'}))['rows'].length ==
            3,
        'Top-level UI control option',
      );
      topLevel.close();
      final fake = AcademicFakeTransport([
        AcademicReply(form('a')),
        AcademicReply(
          form('b') + academicTrainingFixture(),
          check: (uri, method, fields, headers) {
            expect(
              fields!['csrf'] == 'A+B&中' && fields['major'] == 'b',
              'Training POST',
            );
          },
        ),
      ]);
      expect(
        (await AcademicQueries(fake).query(
              'training-plan',
              options: {
                'fields': {'major': 'b'},
              },
            ))['rows'].length ==
            3,
        'Training query',
      );
      fake.close();
      final stale = AcademicFakeTransport([
        AcademicReply(form('a')),
        AcademicReply(form('a') + academicTrainingFixture()),
      ]);
      await rejects(
        () => AcademicQueries(stale).query(
          'training-plan',
          options: {
            'fields': {'major': 'b'},
          },
        ),
        'selection_not_reflected',
      );
      stale.close();
    },
  );
  print(
    'academic queries: $passed groups passed (fake transport; zero network calls)',
  );
}
