const academicTerm = '2026-2027-1';
const academicWeekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

String academicCourse({
  String name = '合成课程',
  String time = '1-2,4(周)[01,03-04节]',
  String? location = '合成教室',
}) =>
    '$name<br><font title="周次(节次)">$time</font>${location == null ? '' : '<font title="教室">$location</font>'}';

String academicScheduleFixture({
  List<String>? cells,
  List<String> weekdays = academicWeekdays,
  String term = academicTerm,
  String week = '',
  String template = 'template-1',
  String hidden = 'A+B&中',
  String action = '',
  String? course,
}) {
  final values = cells ?? [course ?? academicCourse(), '', '', '', '', '', ''];
  return '''<form id="Form1" method="post" action="$action">
  <input type="hidden" name="csrf" value="$hidden">
  <select name="xnxq01id" id="xnxq01id"><option value="2025-2026-2">上学期</option><option value="$term" selected>合成学期</option></select>
  <select name="zc"><option value="" ${week.isEmpty ? 'selected' : ''}>全部</option><option value="2" ${week == '2' ? 'selected' : ''}>第2周</option></select>
  <select name="kbjcmsid"><option value="$template" selected>合成模板</option></select>
  <table id="kbtable"><tr><th></th>${weekdays.map((v) => '<th>$v</th>').join()}</tr>
  <tr><th>第一大节</th>${values.map((v) => '<td><div class="kbcontent">$v</div><div class="kbcontent sykb2">隐藏副本</div></td>').join()}</tr>
  <tr><th>备注</th><td colspan="7">合成备注</td></tr></table></form>''';
}

String academicTableFixture(
  String id,
  List<String> columns,
  List<List<String>> records, {
  bool empty = false,
}) =>
    '<table id="$id"><tr>${columns.map((v) => '<th>$v</th>').join()}</tr>${empty ? '<tr><td colspan="${columns.length}">未查询到数据</td></tr>' : records.map((r) => '<tr>${r.map((v) => '<td>$v</td>').join()}</tr>').join()}</table>';

const academicGradeColumns = [
  '开课学期',
  '课程编号',
  '课程名称',
  '成绩',
  '学分',
  '绩点',
  '补重学期',
  '考试性质',
  '课程性质',
  '考核方式',
  '成绩标识',
];
String academicGradesFixture({
  String term = academicTerm,
  bool empty = false,
}) => academicTableFixture('dataList', academicGradeColumns, [
  [term, 'FAKE-001', '合成课程', '58', '0.5', '0', '', '初修', '必修', '考试', ''],
  [
    term,
    'FAKE-001',
    '合成课程',
    '85',
    '0.5',
    '3.5',
    '2026-2027-2',
    '重修',
    '必修',
    '考试',
    '合成标识',
  ],
], empty: empty);

String academicGradeFormFixture({String action = '/jsxsd/kscj/cjcx_list'}) =>
    '''
<form id="kscjQueryForm" method="post" action="$action">
<input type="hidden" name="csrf" value="A+B&amp;中">
<select name="kksj"><option value="">全部</option><option value="$academicTerm">合成学期</option></select>
<select name="kcxz"><option value="">全部性质</option></select>
<input name="kcmc" value=""><select name="xsfs"><option value="all">全部</option><option value="max">最高分</option></select>
<input type="checkbox" name="sfxsbcxq" value="1"></form>''';

const academicExamColumns = [
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
];
String academicExamsFixture({String term = academicTerm, bool empty = false}) =>
    academicTableFixture(
      'dataList',
      [...academicExamColumns, '考试场次'],
      [
        [
          term,
          'FAKE-001',
          '合成课程',
          '18',
          '1',
          '1-2',
          '2027-01-04 08:00～10:00',
          '1',
          '合成考场',
          '合成校区',
          '1',
        ],
      ],
      empty: empty,
    ) +
    academicTableFixture('dataList', academicExamColumns, [], empty: true);

String academicExamFormFixture() =>
    '''<form id="ksapQueryForm" method="post" action="/jsxsd/xsks/xsksap_list">
<input type="hidden" name="csrf" value="A+B&amp;中"><input type="hidden" name="xqlbmc" value="全部类别">
<select name="xnxqid"><option value="$academicTerm" selected>合成学期</option></select>
<select name="xqlb"><option value="">全部</option><option value="final">期末</option></select></form>''';

String academicCreditsFixture({
  String required = '2.5',
  String earned = '0.3',
  String count = '1',
}) =>
    academicTableFixture(
      'byxf1',
      ['课程性质', '课程属性', '要求学分', '已获得学分'],
      [
        ['合成必修', '必修', required, earned],
      ],
    ) +
    academicTableFixture(
      'byxf2',
      ['类别', '要求学分', '已获得学分'],
      [
        ['合成通选', '', '0'],
      ],
    ) +
    academicTableFixture(
      'byxf3',
      [
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
      ],
      [
        [count, '1', '0.3', '0.3', '0', '0', '0', '0', '0', '0'],
      ],
    ) +
    academicTableFixture(
      'pyfakcxdmx',
      ['学期', '课程编码', '课程名称', '课程学分', '课程性质', '课程属性', '状态'],
      [
        [academicTerm, 'FAKE-001', '合成课程', '0.3', '必修', '必修', '已修'],
      ],
    );

String academicStudentFixture() =>
    '<table id="xjkpTable">${List.generate(50, (r) => '<tr>${List.generate(5, (c) {
      final fields = <String, String>{'2,0': '院系：合成学院', '2,1': '专业：合成专业', '2,3': '班级：合成班级', '2,4': '学号：SYNTHETIC', '3,1': '合成学生', '3,3': '合成性别', '4,1': '20000101', '6,1': '合成籍贯', '7,3': '合成民族', '49,3': 'SYNTHETIC-ID'};
      return '<td>${fields['$r,$c'] ?? ''}</td>';
    }).join()}</tr>').join()}</table>';

String academicTrainingFixture({String span = '2'}) =>
    '''<table id="dataList"><caption>合成培养方案</caption><tr><td><p>合成说明</p>
<table id="mxh"><tr><th>课程编号</th><th>课程名称</th><th>学分</th><th>开设学期</th><th>类别</th></tr>
<tr><td>FAKE-001</td><td>合成课程甲</td><td>0.5</td><td>1</td><td rowspan="$span">必修</td></tr>
<tr><td>FAKE-002</td><td>合成课程乙</td><td>2</td><td>2</td></tr></table></td></tr></table>''';
