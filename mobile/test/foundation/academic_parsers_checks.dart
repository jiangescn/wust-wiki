// Standalone offline checks; the sibling _test.dart registers them with Flutter.
import '../../lib/foundation/academic_parsers.dart';
import 'academic_fixtures.dart';

var _passed = 0;
void check(String name, void Function() body) {
  body();
  _passed++;
}

void expect(bool result, String message) {
  if (!result) throw StateError(message);
}

void rejects(void Function() body, [String? code]) {
  try {
    body();
  } on AcademicParseException catch (e) {
    if (code != null) expect(e.code == code, 'Expected $code, got ${e.code}');
    return;
  }
  throw StateError('Expected a parser failure');
}

void main() {
  check('Word curriculum without dataList preserves paragraphs and table', () {
    final result = parseAcademicTrainingPlan('''<html><body>
<iframe src="/jsxsd/pyfa/topyfamx"></iframe><script>ignored()</script><div id="dataList"></div>
<pstyle="font-family:Calibri">合成专业培养方案<p>毕业要求：合成说明</p>
${List.generate(200, (_) => '<pstyle="font-family:Calibri">合成段落</p>').join()}
${List.generate(200, (_) => '<spanstyle="font-family:Calibri">合成行内</span>').join()}
<table><tr><td>课程编号</td><td>课程名称</td><td>学分</td><td>开设学期</td></tr>
<tr><td>FAKE-003</td><td>合成文档课程</td><td>2</td><td>1</td></tr></table>
</body></html>''');
    expect(result['body'].toString().contains('合成文档课程'), 'Word course text');
    expect(result['body'].toString().contains('毕业要求：合成说明'), 'Word prose');
    expect(
      !result['body'].toString().contains('ignored'),
      'No executable content',
    );
    expect(
      (result['blocks'] as List).any((b) => b['type'] == 'table'),
      'Table block',
    );
  });
  check('duplicate hidden values keep order while editable controls change', () {
    final form = parseAcademicForm(
      '<form id="q" method="post"><input type="hidden" name="token" value="a">'
      '<input type="hidden" name="token" value="b"><input name="search" value="old"></form>',
      Uri.parse('https://bkjx.wust.edu.cn/jsxsd/query'),
      id: 'q',
    );
    final body = form.submission({...form.fields, 'search': 'new'});
    expect(
      body.map((e) => '${e.key}=${e.value}').join('&') ==
          'token=a&token=b&search=new',
      'Repeated hidden fields preserved',
    );
  });
  check('schedule preserves Sunday and skips compact duplicates', () {
    final data = parseAcademicSchedule(
      academicScheduleFixture(
        cells: ['', '', '', '', '', '', academicCourse()],
      ),
      termID: academicTerm,
    );
    final lessons = data['lessons'] as List;
    expect(lessons.length == 1 && lessons.single['day'] == 7, 'Sunday mapping');
    expect(
      lessons.single['weeks'] == '1,2,4' &&
          lessons.single['sections'] == '1,3,4',
      'Gaps preserved',
    );
    expect(
      data['schoolYear'] == '2026-2027' && data['semester'] == 1,
      'Term mapping',
    );
  });
  check('schedule exact dedupe retains different locations', () {
    final first = academicCourse(location: 'A'),
        second = academicCourse(location: 'B');
    final data = parseAcademicSchedule(
      academicScheduleFixture(
        course: [first, first, second].join('<br>---------------------<br>'),
      ),
      termID: academicTerm,
    );
    expect((data['lessons'] as List).length == 2, 'Exact duplicates only');
  });
  check('schedule optional fields and empty valid grid', () {
    final data = parseAcademicSchedule(
      academicScheduleFixture(course: academicCourse(location: null)),
      termID: academicTerm,
    );
    expect(
      data['lessons'][0]['teacher'] == '' &&
          data['lessons'][0]['location'] == '',
      'Absent optional fields',
    );
    expect(
      (parseAcademicSchedule(
                academicScheduleFixture(cells: List.filled(7, '&nbsp;<br>')),
                termID: academicTerm,
              )['lessons']
              as List)
          .isEmpty,
      'Known empty grid',
    );
  });
  check('schedule malformed grid, time, name and term fail', () {
    rejects(() => parseAcademicSchedule('<html></html>', termID: academicTerm));
    rejects(
      () => parseAcademicSchedule(
        academicScheduleFixture(cells: List.filled(6, '')),
        termID: academicTerm,
      ),
    );
    rejects(
      () => parseAcademicSchedule(
        academicScheduleFixture(weekdays: academicWeekdays.reversed.toList()),
        termID: academicTerm,
      ),
    );
    rejects(
      () => parseAcademicSchedule(
        academicScheduleFixture(course: '缺少时间'),
        termID: academicTerm,
      ),
    );
    rejects(
      () => parseAcademicSchedule(
        academicScheduleFixture(course: academicCourse(name: '')),
        termID: academicTerm,
      ),
    );
    rejects(
      () => parseAcademicSchedule(
        academicScheduleFixture(),
        termID: 'sample-term',
      ),
      'invalid_term',
    );
    rejects(
      () => parseAcademicSchedule(
        academicScheduleFixture(
          course: academicCourse(time: '1-9(单周)[01-02节]'),
        ),
        termID: academicTerm,
      ),
      'invalid_time_format',
    );
    rejects(
      () => parseAcademicSchedule(
        academicScheduleFixture(
          course: academicCourse() + '<font title="周次(节次)">5(周)[03节]</font>',
        ),
        termID: academicTerm,
      ),
    );
  });
  check('number list malformed and boundary cases', () {
    expect(
      parseAcademicNumberList(' 1 - 2 , 4 ', upperBound: 30).join(',') ==
          '1,2,4',
      'Swift whitespace behavior',
    );
    for (final text in [
      '',
      '1,,2',
      '3-1',
      '1-',
      '1-3-5',
      '0',
      '-1',
      '31',
      '1-31',
      '1.5',
    ]) {
      rejects(
        () => parseAcademicNumberList(text, upperBound: 30),
        'invalid_number_list',
      );
    }
    expect(
      parseAcademicNumberList('1-2,4,4,30', upperBound: 30).join(',') ==
          '1,2,4,30',
      'Unique bounded list',
    );
  });
  check('forms preserve hidden characters and unchecked inputs', () {
    final form = parseAcademicForm(
      academicGradeFormFixture(),
      Uri.parse('https://bkjx.wust.edu.cn/jsxsd/kscj/cjcx_query'),
      id: 'kscjQueryForm',
      actionPath: '/jsxsd/kscj/cjcx_list',
    );
    expect(
      form.fields['csrf'] == 'A+B&中' && !form.fields.containsKey('sfxsbcxq'),
      'Hidden and checkbox behavior',
    );
    expect(form.choose('kksj', academicTerm) == academicTerm, 'Known term');
    rejects(() => form.choose('kksj', 'invalid'), 'invalid_query');
  });
  check('forms reject off origin, wrong path and duplicate hidden', () {
    final uri = Uri.parse('https://bkjx.wust.edu.cn/jsxsd/xskb/xskb_list.do');
    for (final action in [
      'https://evil.invalid/jsxsd/xskb/xskb_list.do',
      'javascript:alert(1)',
      '/jsxsd/grxx/xsxx',
      '//bkjx.wust.edu.cn:444/jsxsd/xskb/xskb_list.do',
    ]) {
      rejects(
        () => parseAcademicForm(
          academicScheduleFixture(action: action),
          uri,
          id: 'Form1',
        ),
        'unsupported_form',
      );
    }
    rejects(
      () => parseAcademicForm(
        academicScheduleFixture().replaceFirst(
          '</form>',
          '<input name="csrf" value="duplicate"></form>',
        ),
        uri,
        id: 'Form1',
      ),
      'unsupported_form',
    );
  });
  check('script declared form action is parsed without execution', () {
    final uri = Uri.parse('https://bkjx.wust.edu.cn/jsxsd/kscj/cjcx_query');
    final source =
        academicGradeFormFixture(action: '') +
        '<script>document.forms["kscjQueryForm"].action = "/jsxsd/kscj/cjcx_list";</script>';
    expect(
      parseAcademicForm(
        source,
        uri,
        id: 'kscjQueryForm',
        actionPath: '/jsxsd/kscj/cjcx_list',
        allowScriptAction: true,
      ).action.path.endsWith('cjcx_list'),
      'Declared action',
    );
    rejects(
      () => parseAcademicForm(
        academicGradeFormFixture(action: ''),
        uri,
        id: 'kscjQueryForm',
        actionPath: '/jsxsd/kscj/cjcx_list',
        allowScriptAction: true,
      ),
      'unsupported_form',
    );
  });
  check('grades preserve retakes, zero, and all source fields', () {
    final result = parseAcademicGrades(academicGradesFixture());
    final courses = result['courses'] as List;
    expect(courses.length == 2 && courses[0]['point'] == '0', 'Zero preserved');
    expect(
      courses[1]['makeupTerm'] == '2026-2027-2' &&
          courses[1]['attempt'] == '重修',
      'Retake fields',
    );
    expect(
      (courses[1]['fields'] as List).length == academicGradeColumns.length,
      'All raw fields',
    );
  });
  check('grades known empty, missing, pagination, wrong term and spans', () {
    expect(
      (parseAcademicGrades(academicGradesFixture(empty: true))['courses']
              as List)
          .isEmpty,
      'Known empty',
    );
    rejects(
      () => parseAcademicGrades(
        '<table id="dataList"><tr><th>课程名称</th></tr></table>',
      ),
    );
    rejects(
      () => parseAcademicGrades(academicGradesFixture() + '<p>共2页</p>'),
      'unsupported_pagination',
    );
    rejects(
      () => parseAcademicGrades(academicGradesFixture(), termID: '2025-2026-2'),
      'selection_not_reflected',
    );
    rejects(
      () => parseAcademicGrades(
        academicGradesFixture().replaceFirst(
          '<td>FAKE-001',
          '<td rowspan="2">FAKE-001',
        ),
      ),
    );
    rejects(
      () => parseAcademicGrades(
        academicTableFixture('dataList', academicGradeColumns, []),
      ),
    );
  });
  check('exams validate both sources and retain times verbatim', () {
    final rows =
        parseAcademicExams(academicExamsFixture(), termID: academicTerm)['rows']
            as List;
    expect(rows.length == 1 && rows.single['title'] == '合成课程', 'Exam mapping');
    expect(
      (rows.single['fields'] as List).any(
        (f) => f['name'] == '时间' && f['value'] == '2027-01-04 08:00～10:00',
      ),
      'Time display',
    );
    expect(
      (parseAcademicExams(
                academicExamsFixture(empty: true),
                termID: academicTerm,
              )['rows']
              as List)
          .isEmpty,
      'Both empty',
    );
    rejects(
      () => parseAcademicExams(academicExamsFixture(), termID: 'wrong'),
      'selection_not_reflected',
    );
    rejects(
      () => parseAcademicExams(
        academicExamsFixture().replaceFirst('考试场次', '重复来源'),
        termID: academicTerm,
      ),
    );
    rejects(
      () => parseAcademicExams(
        academicExamsFixture() + '<a>下一页</a>',
        termID: academicTerm,
      ),
      'unsupported_pagination',
    );
  });
  check('student original layout and missing mandatory field', () {
    final result = parseAcademicStudent(academicStudentFixture());
    expect(result['rows'][0]['title'] == '合成学生', 'Student name');
    expect(
      !result.toString().contains('SYNTHETIC-ID'),
      'Identity number not exposed',
    );
    rejects(
      () => parseAcademicStudent(
        academicStudentFixture().replaceFirst('学号：SYNTHETIC', '错误：SYNTHETIC'),
      ),
    );
  });
  check('calendar label, script, cross-year, dynamic total', () {
    final date = parseAcademicDate('20261105');
    for (final source in [
      '<li id="li_showWeek"><span>第10周</span>/22周</li>',
      r'''<script>$("#li_showWeek").html("<span>第10周</span>/22周");</script>''',
      r'''<script>jQuery('#li_showWeek').html('<span>第 10 周</span> / 22 周');</script>''',
      r'''<script>$("#li_showWeek").html("<span class=\"current\">第10周<\/span>/22周");</script>''',
    ]) {
      final rows =
          parseAcademicCalendar(source, referenceDate: date)['rows'] as List;
      expect(rows.length == 23, '22 weeks plus summary');
      expect(
        rows.first.toString().contains('20260831') &&
            rows.first.toString().contains('20270131'),
        'Term endpoints',
      );
      expect(
        rows[18].toString().contains('20261228') &&
            rows[18].toString().contains('20270103'),
        'Cross year',
      );
    }
    expect(
      (parseAcademicCalendar(
                    '<li id="li_showWeek">第2周/18周</li>',
                    referenceDate: parseAcademicDate('20260223'),
                  )['rows']
                  as List)
              .length ==
          19,
      'Response total',
    );
  });
  check('calendar unrelated, conflict and invalid week fail', () {
    rejects(
      () => parseAcademicCalendar(
        '<li id="li_showWeek">第${'9' * 100}周/22周</li>',
        referenceDate: DateTime.utc(2026),
      ),
      'invalid_teaching_week',
    );
    rejects(
      () => parseAcademicCalendar(
        '<p>第10周/22周</p>',
        referenceDate: DateTime.utc(2026),
      ),
    );
    rejects(
      () => parseAcademicCalendar(
        '<li id="li_showWeek">第0周/22周</li>',
        referenceDate: DateTime.utc(2026),
      ),
      'invalid_teaching_week',
    );
    rejects(
      () => parseAcademicCalendar(
        r'''<li id="li_showWeek">第9周/22周</li><script>$("#li_showWeek").html('第10周/22周');</script>''',
        referenceDate: DateTime.utc(2026),
      ),
      'invalid_teaching_week',
    );
  });
  check('dates reject normalization and preserve leap day', () {
    for (final s in [
      '20260230',
      '20230229',
      '20261301',
      '2026115',
      '2026-11-05',
      '00000101',
    ]) {
      rejects(() => parseAcademicDate(s), 'invalid_date');
    }
    expect(
      academicDateString(
            parseAcademicDate('20240229').add(const Duration(days: 1)),
          ) ==
          '20240301',
      'Leap day',
    );
  });
  check(
    'credits exact decimal, zero clamp, missing versus zero and statistics',
    () {
      final rows =
          parseAcademicCredits(academicCreditsFixture())['rows'] as List;
      expect(
        rows.first.toString().contains('2.2') &&
            !rows.first.toString().contains('2.200000'),
        'Exact decimal',
      );
      expect(
        rows[1].toString().contains('未提供') &&
            rows[1].toString().contains('value: 0'),
        'Missing differs from zero',
      );
      expect(
        rows[2]['title'] == '学期统计' && rows.last['title'] == '合成课程',
        'Stats and courses',
      );
      expect(
        (parseAcademicCredits(
                  academicCreditsFixture(required: '0.1', earned: '0.3'),
                )['rows']
                as List)
            .first
            .toString()
            .contains('还需学分, value: 0'),
        'No negative remaining',
      );
    },
  );
  check('credits invalid numbers and missing table fail', () {
    for (final value in ['-1', 'NaN', '1e3', '1,000', '9' * 39]) {
      rejects(
        () => parseAcademicCredits(academicCreditsFixture(required: value)),
        'invalid_number',
      );
    }
    rejects(
      () => parseAcademicCredits(academicCreditsFixture(count: '1.5')),
      'invalid_number',
    );
    rejects(
      () => parseAcademicCredits(
        academicCreditsFixture().replaceFirst('byxf2', 'missing'),
      ),
    );
  });
  check('training rowspan and local filters', () {
    final data = parseAcademicTrainingPlan(academicTrainingFixture());
    expect((data['rows'] as List).length == 3, 'Summary and two courses');
    expect(data['rows'][2].toString().contains('必修'), 'Rowspan carried');
    expect(
      (parseAcademicTrainingPlan(
                    academicTrainingFixture(),
                    courseName: '乙',
                    termID: '2',
                  )['rows']
                  as List)
              .length ==
          2,
      'Course and semester filtering',
    );
    expect(
      (parseAcademicTrainingPlan(
                    academicTrainingFixture(),
                    courseName: '无匹配',
                  )['rows']
                  as List)
              .length ==
          1,
      'Explicit filter may have zero courses',
    );
    rejects(
      () => parseAcademicTrainingPlan(academicTrainingFixture(span: '3')),
    );
    rejects(
      () => parseAcademicTrainingPlan(academicTrainingFixture(span: '-1')),
    );
    rejects(
      () => parseAcademicTrainingPlan(
        academicTrainingFixture().replaceFirst('<caption>合成培养方案</caption>', ''),
      ),
    );
  });
  print('academic parsers: $_passed groups passed (synthetic fixtures only)');
}
