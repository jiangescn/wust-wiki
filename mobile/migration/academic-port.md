# Dart 教务模块接口与移植记录

本文描述 `academic_parsers.dart`、`academic_queries.dart` 的实际合同。示例均为合成数据。模块不含登录、凭据读取、Cookie 管理、缓存或平台文件写入；父级调用前须建立有效教务会话。

## 入口

```dart
class AcademicQueries {
  AcademicQueries(this.http);
  final SchoolTransport http;
  Future<Map<String, dynamic>> query(
    String resource, {
    Map<String, dynamic> options = const {},
  });
}
```

依赖 `package:html` 0.15.7、Dart 标准库及父级 `transport.dart`：

```dart
Future<SchoolResponse> send(Uri uri, {
  String method = 'GET', Map<String, String>? form,
  List<MapEntry<String,String>>? formFields,
  Object? jsonBody, Map<String, String> headers = const {},
  bool followRedirects = true,
});
// SchoolResponse: status, uri, bytes, text, json, headers（小写键）
// FoundationException(code, message, {int? status})
```

直接返回业务对象，没有旧 Swift CLI 的 `ok/state/result` 包装。transport 异常原样上传；纯解析的 `AcademicParseException` 在 query 边界转成 `FoundationException`。页面严格使用 UTF-8。

## 通用返回模型与 UI 调用

```json
{
  "rows": [{"title": "合成课程", "fields": [{"name": "课程编号", "value": "FAKE-001"}]}],
  "controls": [{
    "key": "termID", "label": "学年学期", "type": "select", "value": "2026-2027-1",
    "options": [{"value": "2026-2027-1", "label": "合成学期"}]
  }],
  "actions": [{
    "label": "合成方案", "resource": "training-plan",
    "options": {"planHref": "https://bkjx.wust.edu.cn/jsxsd/pyfa/detail?id=synthetic"}
  }],
  "files": [{"name": "entry.html", "mime": "text/html; charset=utf-8", "base64": "..."}]
}
```

`controls/actions/files` 可省略。字段值为字符串；文本控件的 options 为空列表。当前没有逐行 action，目录使用顶层 actions。父级负责再次 query 及交给平台导出 files。

改变控件时，把控件 key/value 放入 options，并保留当前动作 options（例如 planHref）。hidden 每次从新获取的学校表单读取，不交由 UI 保存或覆盖。

## resource 接口

### schedule

| options | 类型 | 默认与约束 |
| --- | --- | --- |
| `termID` | String | 表单当前值；无 selected 时遵循单选首项。必须是学校提供的非空学期 |
| `templateID` | String | 表单 kbjcmsid 当前值；显式指定时必须是模板 select 的选项 |

GET `/jsxsd/xskb/xskb_list.do`，保留成功控件；POST 学期、空 zc 和模板，获取整学期课表。返回表单必须回显三个值。

```json
{
  "provider": "wust-local", "schoolYear": "2026-2027", "semester": 1,
  "lessons": [{
    "name": "合成课程", "code": "", "teacher": "", "location": "合成教室",
    "day": 1, "weeks": "1,2,4", "sections": "1,3,4"
  }]
}
```

另有 termID/templateID 两个 select 控件，无 actions/files。day 为 1–7；范围展开并去重，保留周次/节次间隙，默认上界 30 周/12 节。code 与原 Swift CourseMeeting 一致为空，未知编号不猜测。跳过 sykb2 简化副本，仅去除完全相同的课程，保留不同地点/课堂的记录。结构正确的空网格可返回空 lessons；缺少网格或时间失败。

学期须为 `yyyy-yyyy-[12]`，供旧 Flutter 映射学年/学期。单双周等原 Swift 不支持的格式同样明确失败。

### grades

| options | 类型 | 默认与约束 |
| --- | --- | --- |
| `termID` | String | `''`，全部学期，须在 kksj 中 |
| `courseNatureID` | String | `''`，全部性质，须在 kcxz 中 |
| `courseName` | String | `''`，原文提交为 kcmc |
| `displayMode` | String | `'all'`，须在 xsfs 中，原库另有 `'max'` |
| `includesRetakes` | bool | true，与 0.5.0 移动桥接一致；false 时移除 sfxsbcxq |

GET `/jsxsd/kscj/cjcx_query` 后 POST `/jsxsd/kscj/cjcx_list`。保留 hidden、Referer 和重修选项；空 action 仅接受明确的 `document.forms[...].action` 赋值，不执行 JS。指定学期时逐行核验。

```json
{
  "provider": "wust-local",
  "courses": [{
    "name": "合成课程", "code": "FAKE-001", "term": "2026-2027-1",
    "score": "85", "credit": "0.5", "point": "3.5", "makeupTerm": "2026-2027-2",
    "attempt": "重修", "nature": "必修", "assessment": "考试", "mark": "合成标识",
    "fields": [{"name": "课程名称", "value": "合成课程"}]
  }]
}
```

实际 fields 保留整行所有列，包括分组名、总学时、通选课类别。初修和重修不合并。controls 为 termID/courseNatureID/courseName/displayMode，无 actions/files。仅列宽正确的“未查询到数据”标记可成为空 courses；分页、错位和数据行合并单元格失败。

### student

无 options。GET `/jsxsd/grxx/xsxx`，按原 Swift 的 xjkpTable 固定行列及“院系：/专业：/班级：/学号：”标签校验。

```json
{"rows":[{"title":"合成学生","fields":[
  {"name":"姓名","value":"合成学生"},
  {"name":"学号","value":"SYNTHETIC"},
  {"name":"院系","value":"合成学院"}
]}]}
```

完整字段为姓名、学号、院系、专业、班级、出生日期、性别、民族、籍贯。按旧库检查第 50 行身份证单元格存在，但按旧移动桥接不返回身份证值。无 controls/actions/files。

### exams

| options | 类型 | 默认与约束 |
| --- | --- | --- |
| `termID` | String | xnxqid 当前值，须为学校选项中的非空学期 |
| `categoryID` | String | xqlb 当前值；类别名称从学校选项读取 |

GET `/jsxsd/xsks/xsksap_query` 后 POST `/jsxsd/xsks/xsksap_list`，保留 xqlbmc 和 hidden。两张 dataList 必须分别为集中安排（含“考试场次”）与自行申请；逐行核验学期。

```json
{"rows":[{"title":"合成课程","fields":[
  {"name":"时间","value":"2027-01-04 08:00～10:00"},
  {"name":"场地","value":"合成考场"}
]}]}
```

实际保留全部字段（周次、星期、节次、时间、座位号、场地、校区、考试场次等）。时间原文展示，不把不确定日期改成猜测值。controls 为 termID/categoryID，无 actions/files。两表均有合法空标记时允许空 rows；分页、重复来源、缺表和错列失败。

### credits

无 options。GET `/jsxsd/xxwcqk/xxwcqk_idxOnzh.do`，要求 byxf1/byxf2/byxf3/pyfakcxdmx 四表。返回类别、通选类别、学期统计与课程进度：

```json
{"rows":[{"title":"合成必修","fields":[
  {"name":"类别","value":"合成必修"},
  {"name":"课程属性","value":"必修"},
  {"name":"要求学分","value":"2.5"},
  {"name":"已获学分","value":"0.3"},
  {"name":"还需学分","value":"2.2"}
]}]}
```

课程字段为课程、课程编号、学期、学分、课程性质、课程属性、状态；统计保留原十项字段。缺失数值显示“未提供”，与 0 区分。缩放 BigInt 精确相减，还需学分最低为 0；拒绝负数、科学计数、千分位和非数值。学分文本上限 38 字符，与 Swift 输入边界一致。无 controls/actions/files。

### calendar

| options | 类型 | 默认与约束 |
| --- | --- | --- |
| `date` | String | 当前 UTC+8 日期；显式值为严格 yyyyMMdd，例如 `20261105` |

POST `/jsxsd/framework/main_index_loadkb.jsp`，表单为 rq=2026-11-05。仅解析 li_showWeek 元素或明确向该标签 `.html(...)` 赋值的脚本字符串，不执行脚本。冲突标签、0 周、总周数小于当前周均失败。

```json
{"rows":[{"title":"教学信息","fields":[
  {"name":"当前教学周","value":"第 10 周"},
  {"name":"总周数","value":"22"},
  {"name":"学期起点","value":"20260831"},
  {"name":"学期终点","value":"20270131"}
]},{"title":"第 1 周","fields":[
  {"name":"教学周","value":"第 1 周"},
  {"name":"开始","value":"20260831"},
  {"name":"结束","value":"20260906"}
]}]}
```

实际输出所有教学周，周一至周日，处理跨年和闰年。无 controls/actions/files。为防止结果列表无限扩张，最多 4096 周，起止日期须为公元 1–9999 年。

### training-plan

学校当前另有 Word 文档输出形态（已在真实只读调用观察）：缺少原 dataList/mxh 课程节点，带畸形 `<pstyle=...>` 标记、完整培养方案段落及课程表。接口在同时确认 Word 标记、table 和“培养方案/课程编号/课程名称/学分/开设学期”后将导出器 `<pstyle=...>` 开标签规范为 `<p style=...>` 再解析完整正文，跳过脚本、iframe 和表单。行内标签使用迭代遍历，限制总节点262144与嵌套表格16层；不把畸形 Word 行内标签误当超深业务结构。该形态返回 `title/body/blocks`，其中 blocks 为 `{type:'paragraph',text}` 或 `{type:'table',grid,text}`；合并单元格在 grid 展开，body 以段落与制表符保留全文，rows/controls 为空。文档版不提供课程筛选；显式传 courseName/termID 会报 unsupported_form，避免伪装筛选成功。原 dataList 形态及其筛选行为保持。


| options | 类型 | 默认与约束 |
| --- | --- | --- |
| `planHref` | String | 可选；须逐字匹配本次入口返回的目录链接 |
| `fields` | Map<String,String> | 可选；只允许当前表单的可见文本/select，不可覆盖 hidden |
| 学校控件 key | String | fields 未提供时可直接把可见控件 key 放入 options，方便通用 UI |
| `courseName` | String | `''`；本地名称包含筛选，忽略大小写 |
| `termID` | String | `''`；“开设学期”按逗号/空白分隔后精确匹配，例如 `'2'` |

入口 GET `/jsxsd/pyfa/topyfamx`。原正文要求 dataList 的直属 caption 及 mxh 课程表，必需列为课程编号、课程名称、学分、开设学期。课程行 title 为名称、fields 为全部课程列；非课程正文和其他表文本作为摘要行保留。

合并单元格扩展成字段值，rowspan=0 仅延伸当前行组；校验跨行组、重叠、跨度。最多 4096 行/256 列/262144 个展开格、16 层嵌套。嵌套表行不混入外表。返回通用 rows，没有原 Swift TrainingPlanBlock/TrainingPlanCell 的专用布局模型。

目录只接受同源 `/jsxsd/pyfa/` 链接，生成 actions。首次目录/表单可返回 rows=[]，同时必须有 controls 或 actions，表示等待选择。首次表单只提供控件；传入 fields 或顶层学校控件值后才 POST，并校验回显。没有正文、目录或表单则失败。

```dart
await academic.query('training-plan');
await academic.query('training-plan', options: {
  'fields': {'major': 'b'}, // 合成字段，必须来自本次学校响应
  'courseName': '合成', 'termID': '2',
});
```

正文返回 courseName/termID 文本 controls，合并学校控件；目录返回 actions；无 files。目录/动态表单层为本次自行实现的通用适配，仅合成验证，不是已确认的真实学校结构。

### raw-schedule

| options | 类型 | 默认与约束 |
| --- | --- | --- |
| `termID` | String | 同 schedule |
| `templateID` | String | 同 schedule；原始采集要求对应 select |
| `week` | String | `''`；非空须为 zc 选项，例如 `'2'` |

顺序为入口 GET、整学期 POST、可选周次 POST；每次校验学期、周次、模板回显。files 为 entry.html/semester.html，指定周次时另有 week.html。Base64 解码后与响应 bytes 相同，不写工作区或共享缓存。

```json
{"rows":[{"title":"原始课表采集","fields":[
  {"name":"学年学期","value":"2026-2027-1"},
  {"name":"周次","value":"2"},
  {"name":"课表模板","value":"template-1"},
  {"name":"HTML 文件数","value":"3"},
  {"name":"周课表内容变化","value":"是"}
]}],"files":[{"name":"entry.html","mime":"text/html; charset=utf-8","base64":"..."}]}
```

controls 为 termID/week/templateID，无 actions。内容比较仅针对详细 kbcontent 文本，与 Swift 比较对象一致；不把原始采集标为课程结构已验证，不返回假 lessons。原始 HTML 可能含个人数据，父级仅按用户导出请求交给文件能力，不打印或放进发布附件。

## 授权与错误

八个 resource 均受教务认证保护。父级负责有效会话检查/恢复；本模块不取 TGT、不登录或切换账号。父级 transport 的 tgt_required/cancelled/network_error 等异常原样传递。

| 本模块错误码 | 含义 |
| --- | --- |
| authentication_required | HTTP 401、转到 auth/atrust/login，或页面明确含登录标题/密码输入框 |
| unsupported_resource | 未支持的 resource |
| invalid_query | 非学校选项、未知目录链接、隐藏字段覆盖或非法地址 |
| unexpected_status | 非 200 业务响应，附 status |
| unexpected_redirect | 最终源站或路径不同 |
| invalid_encoding | 非法 UTF-8；父 transport 严格解码也可能先抛其编码异常 |
| unsupported_form | 方法/action/多选/重复非隐藏字段或控件结构不支持 |
| selection_not_reflected | POST 回显或记录学期与选择不符 |
| unsupported_pagination | 成绩/考试分页，避免不完整结果 |
| invalid_term | 课表学期不能映射旧 Flutter 学年/学期 |
| invalid_number_list | 周次/节次格式、逆序或范围错误 |
| invalid_time_format | 课表时间格式不支持 |
| invalid_number | 学分或统计数值错误 |
| invalid_date | 日期格式、不存在的日期或教学周日期越界 |
| invalid_teaching_week | 周次冲突、范围错误或结果过大 |
| content_too_large | 培养方案嵌套过深 |
| parse_error | 缺表/缺列/错位/跨度异常等；message 给出原因 |

**同名隐藏字段：** 主线已扩展 `formFields` 有序多值表单，按原页面顺序保留同名 hidden 的全部值；编辑控件通过值覆盖，重复非隐藏字段仍明确报错。解析断言和本地 HTTP 序列化回归覆盖此行为。

## 来源与适配分类

- 协议和解析移植自 `WUSTFoundation-android/Sources/WUSTFoundation/{Timetable,Grades,Exams,Credits,StudentInfo,TrainingPlan}`，以及 WUSTDemo 的 TimetablePageCapture/TimetableCaptureForm。
- Flutter 字段依据 `Android/swift/MobileAcademicAPI.swift`。Swift Tests 的 TimetableParserTests/TimetableRequestTests/TeachingCalendarTests 提供合成等价行为；原 Tests 没有独立成绩/考试/学分/培养方案测试，本次新增对应合成覆盖。
- 必要适配：SwiftSoup → html；认证/Cookie → 父级；Swift 专用模型 → 通用行/控件/文件；采集磁盘写入 → 内存返回；Decimal → 缩放 BigInt。
- 自行实现：培养方案目录/动态表单、课程筛选、通用控件及离线 harness。未使用真实账号或采集结果。

## 实测及复跑

2026-11-25，Dart 3.11.3，主工作区只读 package_config（html 0.15.7）：

- 纯解析 18 组通过：Swift 等价的星期/副本/去重/空网格/周次间隙/缺字段/教学周脚本与冲突/跨年/闰年，以及成绩重修/分页、考试两来源、学分精确相减、培养方案 rowspan/筛选。
- 查询协议 12 组通过：FakeTransport 覆盖八个 resource、hidden 特殊字符、选项与回显、失效会话、同源路径、文件 bytes、培养方案目录和表单；零网络请求。
- 在系统临时目录复制本模块/测试，并只读复制父级 transport 后，Dart analyze：No issues found。

项目根目录复跑纯解析（PowerShell）：

```powershell
& 'E:\blog\WUSTWI~1\.cache\flutter-build\flutter\bin\cache\dart-sdk\bin\dart.exe' `
  --packages='E:\blog\WUSTWI~1\mobile\.dart_tool\package_config.json' `
  mobile/test/foundation/academic_parsers_checks.dart
```

父级集成 transport 后同样运行 academic_queries_checks.dart。两个 `*_test.dart` 为 Flutter 注册入口，可在父级 mobile 目录执行：

```powershell
flutter test --no-pub test/foundation/academic_parsers_test.dart test/foundation/academic_queries_test.dart
```

未执行：本工作树没有 pubspec/transport，未在此运行 Flutter runner、全 App 分析/构建、UI 重查/导出交互、APK 或真实教务账号。父级须整合后编译并验证。没有运行 pub get，没有更改主工作区共享缓存。
