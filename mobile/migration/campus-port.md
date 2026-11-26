## 0.6.3 授权合同更新

正式客户端已接新版 authserver SSO，旧 TGT REST 配置端点当前返回404，不再把手动提供 TGT 作为正式入口的前提。下方原始移植说明中的 TGT 请求是兼容路径；现行认证与恢复见 [接口总册](api.md)。已验证四项取票、图书馆和第二课堂真实只读查询；校车获取到业务卡片后返回 invalid_schedule，不能称该查询验收通过。

# 校园服务 Dart 移植与接口合同

本模块为 Flutter 的 Dart 主业务迁移提供校园通知、图书馆、校车、第二课堂及胖乖生活服务。公开入口统一为 `CampusServices.query(resource, options: ...)`。本次只新增校园模块、合成测试和本文档，没有修改主线依赖、Android 能力或入口，没有构建 APK、提交、推送或部署。

## 来源与实现分类

行为来源为仓库中的 `WUSTFoundation-android/Sources/WUSTFoundation/{Notices,Library,CampusShuttle,SecondClass,Laundry}/`，展示字段来自 `Sources/WUSTDemo/{NoticeDemo,LibraryDemo,CampusShuttleDemo,SecondClassDemo}.swift` 和 `Sources/WUSTLaundryDemo/WUSTLaundryDemo.swift`。洗衣凭据格式核对了 `Android/swift/LaundryDemoCredentialStore.swift`。移植遵循原 WUSTFoundation 模块的 AGPL-3.0 许可，随完整对应源码和原许可一并交付。上游来源及固定提交由仓库 `THIRD_PARTY_NOTICES.md` 维护。

| 分类 | 本次内容 |
| --- | --- |
| 按原业务移植 | 五种通知来源与路径规则、日期过滤、正文和资源抽取、20 MiB PDF 校验；图书馆 CAS 和全部原有只读端点；校车门户认证、MD5 签名与合并单元格；第二课堂初始化、学分与评价；胖乖 API、短信预检、登录、验证、设备排序、跨页运行订单、服务器时间与缓存规则 |
| 必要适配 | SwiftSoup 换为现有 `package:html`；URLSession 换为 `SchoolTransport`；系统 MD5、字符集和加密存储通过 `FoundationPlatform`；Swift Codable 日期与 Base64 JSON 保持兼容 |
| 本地实现 | 通用 `rows/controls/actions/files` 映射、目录名称筛选、请求并发合并和账号变化保护、合成探针及离线运行器 |

原 Swift 没有全馆书目关键词搜索端点。`library-search` 展示和筛选原有书单目录，随后进入书单资料和书目，界面控件明确说明这一范围。未猜测其他检索接口。

## 依赖合同与生命周期

```dart
CampusServices(
  SchoolTransport http,
  FoundationPlatform platform, {
  Future<String?> Function()? credential,
  Future<String> Function(String service)? ticketProvider,
  void Function()? onQuery,
});
Future<Map<String, dynamic>> query(
  String resource, {
  Map<String, dynamic> options = const {},
});
```

- 0.6.3 正式入口传入 `ticketProvider: auth.serviceTicket`，复用新版统一认证 SSO 给各业务取 ST；`onQuery` 更新实际查询阶段。仅未传 ticketProvider 的原库兼容调用才要求 `credential` 提供 TGT。Cookie 不是 TGT。图书馆、校车、第二课堂各有独立 transport 和加密 Cookie 快照。
- `http` 负责 Cookie、取消和重定向底层处理。`SchoolResponse` 提供 `status/uri/bytes/text/json/headers`；`headers` 键为小写，至少保留 `location/date/content-type/set-cookie`。
- 公开 `notices/notice-detail/notice-file` 由父级使用独立 transport。父级已确认增加 `allowPublicHttp`，仅允许学校域名的 HTTP GET/HEAD，拒绝 HTTP 请求体和授权头；默认仍为 HTTPS。模块保留原通知 URL 对 HTTP/HTTPS 的支持，不能把公开 transport 用于认证或胖乖。
- 个人服务 transport 使用 HTTPS。CAS 回调由模块手动跟随同源重定向，最多 10 次；不会将票据提交给外部域名。
- 胖乖请求携带空 `Cookie` 请求头，阻止复用 transport Cookie，并禁止重定向。API 原来的 `ios_app`/Safari 请求画像、版本和排序后的字段保留。
- `invoke('digest', {'algorithm':'MD5','data':Base64})` 返回 `{'data':Base64}`。门户签名为 `MD5(UTF8('timestamp=<毫秒>,key=lianyi2019'))` 的小写十六进制。
- 通知先严格 UTF-8 解码。仅当响应头声明 GBK、GB2312、GB18030 且 UTF-8 失败时调用 `invoke('decodeText', {'data':Base64,'charset':'GB18030'})`，返回 `{'text':String}`。父级 Android 使用严格 Charset 解码，非法数据报错。
- `load/save/clear('laundry')` 使用父级加密存储。值保持旧 Android 的 Base64(JSON)，包含 `userID/token/firstVerifiedAt/lastVerifiedAt`。日期写回为 Swift 2001-01-01 UTC 纪元秒数，读取也支持 ISO 日期。不会输出 token 或把它放在行、控件和动作中。模块不更换、不清除原设备 ID。
- 订单内存缓存属于一个 `CampusServices` 实例，并按胖乖 token 隔离。同一订单的并发查询共用 pending 请求；清除/切换胖乖账号后，迟到响应抛 `account_changed`。

## 通用结果及调用动作

所有成功结果都包含 `rows`，它可以在已确认空列表时为 `[]`。`title/message/controls/actions/files` 按资源选填。

```json
{
  "title": "页面标题",
  "message": "查询范围或状态",
  "rows": [
    {
      "title": "一条记录",
      "fields": [{"name": "字段名", "value": "显示值"}],
      "action": {"resource": "目标资源", "options": {}}
    }
  ],
  "controls": [
    {"key": "page", "label": "页码", "type": "text", "value": "1"},
    {"key": "kind", "label": "类别", "type": "select", "value": "current", "options": [{"value": "current", "label": "当前借阅"}]}
  ],
  "actions": [{"label": "查询", "resource": "目标资源", "options": {}}],
  "files": [{"name": "fixture.pdf", "mime": "application/pdf", "base64": "JVBERi0="}]
}
```

`fields[].value` 为显示字符串，缺失字段显示“未提供”，对象和数组使用 JSON 显示，保留原返回字段。顶层额外的结构化数据在下面逐项列出，日期均为字符串或 null。文件导出、PDF 打开由父级 Android UI 处理，本模块不执行文件系统操作或原生预览。

点击顶层动作时以当前控件值为输入，再应用该动作的 `options`，后者用于固定页码、动作类型等。不要把上一资源的所有 options 自动携带到新资源。点击行时直接使用该行 action 的 options。特别是通知“查询来源首页”的 `url:''` 会清除旧分页 URL，并使用当前 `source` 控件。

未列出的 options 不参与业务。页码接受整数或整数字符串，范围 1 至 214748364；超出抛 `invalid_pagination`。布尔项按各资源下的规则读取，不自动将任意文本当成 true。

## 资源与选项总表

| resource | 全部业务 options | 授权 |
| --- | --- | --- |
| `notices` | `source='campus'`；`url` 可省略/空串；`excludedDates=['1980-01-01']`；`earliestDate?`；`latestDate?` | 公开，不取 TGT |
| `notice-detail` | `url`、`publishedDate` 必填；`title`；`source='campus'`；上述三个日期策略项 | 公开，不自动登录 |
| `notice-file` | `url`、`sourceURL` 必填；`name` 默认 URL 最后路径段 | 公开，不自动登录 |
| `library` | `page=1`、`pageSize=100`，用于借阅和即将到期首屏 | 学校 TGT |
| `library-profile` | 无业务筛选项；共同分页校验仍适用 | 学校 TGT |
| `library-loans` | `kind='current'` 或 `'overdue'`；`page=1`；`pageSize=100` | 学校 TGT |
| `library-search` | `keyword=''`，仅筛选返回书单名称 | 学校 TGT |
| `library-fines` | `page=1`；`pageSize=10` | 学校 TGT |
| `library-requests` | `page=1`；`pageSize=5` | 学校 TGT |
| `library-booklist` | `id` 必填 | 学校 TGT |
| `library-booklist-books` | `id` 必填；`page=1`；`pageSize=10` | 学校 TGT |
| `shuttle` | 无 | 学校 TGT |
| `second-class` | 无 | 学校 TGT |
| `laundry` | `phone` 仅用于初始化手机号控件 | 不联网，只读取本机胖乖凭据 |
| `laundry-shops` | `latitude=30.439405`；`longitude=114.268024`；`page=1` | 公开胖乖 API |
| `laundry-devices` | `shopId` 必填；`shopName` 显示名称；`machineCount?` 用于判断是否覆盖全部设备 | 公开胖乖 API |
| `laundry-sms` | `action='send'` 才请求；`phone` | 用户点击发送动作 |
| `laundry-login` | `action` 为 `login/restore/clear/web-token`；分支参数见下文 | 胖乖验证码或本机胖乖凭据 |
| `laundry-orders` | `page=1`；`running=true` 或字符串 `'true'` 时遍历全部页查询运行中洗衣订单，默认 false | 本机胖乖凭据 |
| `laundry-order` | `orderId` 必填；`refresh=true` 仅接受布尔 true，默认使用缓存策略 | 本机胖乖凭据 |

全部 `library*` 资源共同校验 `page/pageSize`，每页须在 1 至 100 之间。目录、资料等非分页资源不使用通过校验后的页码。运行中洗衣订单也会校验传入 page，但遍历从第 1 页开始。

## 通知接口详情

### `notices`

`source` 可取 `campus/academicAffairs/studentAffairs/research/graduateSchool`，对应校园、教务、学工、科研、研究生院通知。列表固定源如下。

| source | 默认列表 URL |
| --- | --- |
| campus | `https://www.wust.edu.cn/index/tzgg.htm` |
| academicAffairs | `https://jwc.wust.edu.cn/tzgg.htm` |
| studentAffairs | `https://xgc.wust.edu.cn/tzgg.htm` |
| research | `https://kjc.wust.edu.cn/tzgg.htm` |
| graduateSchool | `https://ysxy.wust.edu.cn/tzgg.htm` |

分页 URL 只能为同来源主机上的原列表路径或去掉 `.htm` 后的 `/<数字>.htm`，不接受 query。所有学校 URL 要求无用户信息、主机为 `wust.edu.cn` 或其子域、端口为 80/443。正文路径为 `/info/<数字>/<数字>.htm`，或 `info.jsp?urltype=news.NewsContentUrl`。

日期策略使用严格真实公历 `YYYY-MM-DD`，上下界均包含。默认排除哨兵日期 `1980-01-01` 和无效/缺失日期，未来日期保留。识别到但不符合日期策略的行计入 filtered；重复 URL 去重。完全无法识别列表时抛错，不输出正常空列表。

返回 `title/message`、通知 rows（发布日期/原文、进入详情的 action）、source 下拉控件、查询首页/上一页/下一页 actions。额外 `page` 包含 `source/url/items/previousPageURL/nextPageURL/currentPage/totalPages/filteredItemCount`；每个 item 包含 `source/title/url/publishedDate`。分页数未识别时为 null。

本资源特有错误为 `unsupported_url/invalid_date_policy/list_not_found/title_not_found/invalid_encoding`；未知 source 或错误 option 类型为 `invalid_query`。HTTP 401、认证站跳转为 `authentication_required`，其他失败状态保留 status。

### `notice-detail`

必须提供列表得出的 `url/publishedDate`；`title` 可作网页标题回退。请求前校验日期和 URL，响应后的元数据、日期标签、正文前的发布日期信息优先于回退值。完整段落和表格单元格文字保留，不执行脚本。提取 lazy 图片、普通链接、附件、iframe/embed/object 和 `showVsbpdfIframe(...)` 中的 PDF，并分别去重。

返回标题、正文 row（日期/原文/全文）、图片 rows（说明/地址）、附件和链接 rows。符合学校域名的 PDF 行带 `notice-file` action，嵌入 PDF 另有下载 actions。无 controls。额外 `detail` 包含 `summary/text/paragraphs/images/attachments/links/documents`。`summary` 同通知 item；图片为 `{url,alt}`，链接/附件为 `{title,url}`，documents 为 `{url,sourceURL}`。外部资源仅显示链接，不自动下载。

特有错误为 `unsupported_url/missing_publication_date/filtered_publication_date/body_not_found/title_not_found/invalid_date_policy/invalid_encoding`，另有公共 HTTP/重定向错误。

### `notice-file`

请求地址必须是学校域名上的 `.pdf`，`sourceURL` 必须为学校正文路径，发送 `Referer: sourceURL`。下载后校验学校域名、响应状态、最大 20 MiB 及 `%PDF-` 文件头，失败不会返回截断文件。文件名中的路径分隔符和控制字符替换为 `_`，补 `.pdf` 后缀。

返回 `title='通知 PDF'`、大小和来源 row，以及一份 `{name,mime:'application/pdf',base64}` 文件。无 controls/actions。特有错误为 `unsupported_url/invalid_document/document_too_large`，另有公共状态/重定向错误。纯解析器还支持可配置容量并以 `invalid_configuration` 拒绝非正数；query 层容量固定，不开放 option。

## 图书馆接口详情

先尝试已有 Cookie；HTTP 302/401 或认证站跳转时，通过 TGT 申请服务票据，服务字符串严格为 `https://libsys.wust.edu.cn:443/meta-local/opac/cas/rosetta`，交换后读取一次 index，再重试原查询一次。业务码成功接受整数或整数字符串 `0/200`，其他码原样进入 `library_rejected_<code>`。JSON 中的任意借阅、属性、状态、位置、索书号、金额字段完整显示，不把业务失败转换为空记录。

| resource | 端点与返回 | controls | actions |
| --- | --- | --- | --- |
| `library` | GET `/meta-local/opac/users/stats`、`users/loans`、`users/overdue_soon`；返回统计 row、两组总数/页码和每本书的完整字段 | 无 | 资料、当前借阅、即将到期、违章、请求、书单 |
| `library-profile` | GET `users/stats`；返回统计所有字段，包括 loanCount/expireCount/requestCount/booklistCount/fineSum 及未知扩展字段 | 无 | 同上 |
| `library-loans` | GET `users/loans` 或 `users/overdue_soon`；支持原数组形态及 items 分页对象，返回每本书的所有字段 | page/pageSize 文本、kind 下拉 | 查询、上一页、下一页 |
| `library-search` | GET `booklists/tree`；按 booklistName 作不区分大小写的本地名称筛选；返回完整书单字段和顶层 total（筛选前目录数） | keyword 文本，标签“书单目录名称筛选” | 筛选目录；行进入 `library-booklist` |
| `library-fines` | GET `users/fines`；严格校验分页对象并显示所有记录字段 | page/pageSize 文本 | 查询、上一页、下一页 |
| `library-requests` | GET `users/requests/list`，固定 `requestFlagStatus=all,processStatus=0`；严格校验分页对象 | page/pageSize 文本 | 查询、上一页、下一页 |
| `library-booklist` | GET `booklists/<id>/info`；返回所有书单资料字段 | 无 | `library-booklist-books` |
| `library-booklist-books` | POST `booklists/<id>/detls`，JSON body `{page,pageSize}`；严格校验分页对象并显示完整书目字段 | page/pageSize 文本 | 查询、上一页、下一页，均保留 id |

上述分页资源额外返回 `page={currentPage,pageSize,totalPage,total,items}`，message 显示当前页和总数。loans 的数组响应按原 Swift 推导元数据；其他严格分页资源必须包含所有元数据。records/loan 的嵌套 bibAttrs、circStatus、tempLocation、callNo 等值不丢弃，嵌套数据作为 JSON 字符串显示。

书单 `id` 只允许非空 ASCII 字母数字和 `-_.~`，禁止 `.` 和 `..`。相关错误包括 `invalid_booklist_id/invalid_pagination/invalid_payload/invalid_response/library_rejected_<code>`，授权错误包括 `tgt_required/invalid_credential/authentication_required`，以及公共网络、状态、重定向错误。目录没有 `_id` 的条目保留字段但不提供进入详情 action。

## 校车与第二课堂

### `shuttle`

无 options 和 controls。按原门户流程先 POST `https://portal.wust.edu.cn/tryLoginUserInfo`，失败时 GET `/auth?service=https://portal.wust.edu.cn/#/index70`，严格校验其 CAS service 为 `/shiro-cas`，获取 ST 并处理回调 `Authorization/tokenId`。从 Cookie 响应提取 XSRF-TOKEN，门户 GET 请求带秒级 `_t`，所有门户请求带毫秒级 csrfTimestamp 及上述 MD5 csrfToken。用户、组织、部门 ID 均兼容整数或字符串。

读取卡片 `/api/upp/contentDisplay/queryAppointCard/e05973ba27214e7a97234733848f05d5`。表格要求日期/起点/终点/发车时间/行车线路五列，解析 rowspan/colspan，校验 24 小时时间，保留标题、表内和表外备注。返回每班车的五个可见字段、备注 message，额外 `schedule={title,departures,notes}`。departure 为 `{operatingDays,origin,destination,departureTime,route}`。

错误包括 `invalid_schedule/invalid_response/shuttle_rejected_<门户业务码>`，以及学校授权/状态/重定向错误。格式无法识别不会返回空时刻表。

### `second-class`

无 options/controls/actions。入口为 `https://xg.wust.edu.cn/xsfw/sys/dektapp/*default/index.do`。每次读成绩前 POST `/xsfw/sys/swpubapp/indexmenu/getAppConfig.do?appId=5446046383738452&appName=dektapp`，确认有 MODULES，再依次 POST `dektapp/modules/cjdcxManage/getCj.do` 和 `getSzfzpj.do`。会话失效时用 TGT 换票，交换成功后重新初始化和查询。

返回综合评价 row（总已获学分/评价），以及每个有学分要求的类别 row（类别编号、要求/已获学分、必修/选修要求、已获、剩余、完成情况）。使用 `xxyxxfR` 显示选修成绩，不使用 `xxyxxf` 替代。要求为零的分项过滤；一个类别所有要求均为零才隐藏。剩余值不小于零，达到要求即完成。

额外 `transcript={categories,earnedCredits,evaluation}`。category 为 `{id,name,requiredCredits,earnedCredits,requirements}`，requirement 为 `{kind:'required'|'elective',requiredCredits,earnedCredits,remainingCredits,isCompleted}`。数值接受非负有限 JSON number 或严格十进制数字字符串，拒绝负数/布尔/null/NaN。剩余学分按十进制系数计算，避免 0.3-0.1 显示二进制浮点尾数。错误包括 `second_class_rejected_<原业务码>/invalid_response`，以及学校授权/状态/重定向错误。

## 胖乖接口详情

全部端点在 `https://userapi.qiekj.com/`。HTTP 必须 200，JSON `code` 必须为整数 0 才成功。其他码为 `laundry_rejected_<code>`；认证请求的 code=2 转为 `laundry_login_required`，message 仍带业务码 2。不自动清除失效凭据，不用 null payload 冒充正常空列表。手机号必须 `^1[0-9]{10}$`，验证码必须非空数字。

### `laundry`

只读取本机 `laundry` 值，无网络请求。返回已保存账号的用户 ID、首次和最近验证时间，或空 rows；不会声称已通过服务器验证。controls 为 phone/smsCode（验证码初始为空）。actions 包含附近门店、发送登录短信、使用验证码登录；有本机凭据时再提供恢复验证、运行订单、全部订单和清除本地登录。

读取损坏值抛 `invalid_credential/invalid_response`，平台存储错误由平台层传递。直接进入本页绝不会发送短信。

### `laundry-shops`

POST `shop/nearby/list`，字段为 latitude/longitude/type=7/page/pageSize=10。坐标接受有限数值或数值字符串，纬度范围 [-90,90]，经度 [-180,180]。默认值沿用原黄家湖查询点，不自动读取用户位置。

返回每店的名称、ID、distance、machineCount、freeMachine；message 显示门店总数和本页数。controls 为 latitude/longitude/page；actions 为查询及存在时的上一/下一页。行 action 打开 `laundry-devices` 并传 shopId/shopName/machineCount。数量或数据结构无法识别抛 `invalid_response`；参数不合法为 `invalid_query/invalid_pagination`。

### `laundry-devices`

POST `machineModel/near/machines`，固定 machineTypeId=`c9892cb4-bd78-40f6-83c2-ba73383b090a`、pageSize=100，从 goodsPage=1 起按服务端 goodsPage 遍历。页无新 ID 或页码未前进时停止，ID 去重。按南楼、北楼、其他分组，再自然数排序，最后用 ID 打破同名平局。

返回空闲设备名称/ID/状态 rows、刷新 action，没有 controls。额外 `availableDevices` 保留所有设备记录；只有可用名单数量等于提供的 machineCount 时 `allDevices` 才为同名单，否则为 null，message 明确只掌握空闲明细。shopId 不能为空；结构失败为 `invalid_response`，不会伪造全部设备。

### `laundry-sms`

action 不为 `send` 时只返回 phone/smsCode 控件及发送 action，不联网。明确 `action='send'` 后先 POST `common/isNeedCaptcha` 的 phone；返回 false 才 POST `common/sms/sendCode` 的 phone/template=reg。返回 true 抛 `captcha_required` 并停止，不申请短信。成功返回已提交 message、phone/smsCode 控件和验证码登录 action，不展示验证码。

请求使用原 ios_app/Version=1.28.2 画像。错误包括 `invalid_phone_number/captcha_required/invalid_response/laundry_rejected_<code>` 和公共状态/网络错误。测试只使用 fake transport，本文档的示例不应向真实 SMS 服务执行。

### `laundry-login`

| action | 分支 options 与请求 | 成功结果 |
| --- | --- | --- |
| `login` | phone/smsCode 必填；POST `user/reg`，字段 channel=ios_app/phone/verify；取得非空 token 后 POST `user/info` 验证 | 保存加密凭据；返回用户 ID、首次/最近验证时间、至少验证可用分钟；运行中/全部订单 actions |
| `restore` | 无附加参数；读取本机凭据，用原 token POST `user/info`；确认返回 id 与保存 userID 一致 | 保留 firstVerifiedAt，更新 lastVerifiedAt 后保存；同上结果 |
| `clear` | 无附加参数；只 clear('laundry') 并清理本实例订单缓存 | 已清除 message 和空 rows；不修改学校账号、设备 ID |
| `web-token` | origin/token 必填，由受信任网页容器提供；origin 必须同源 `https://h5.qiekj.com`、无 userinfo；先 POST `user/info` 验证 | 同 login，但不自行创建 WebView、不自动读取网页 localStorage |
| 其他/省略 | 按 `laundry` 展示登录界面；phone 只预填手机号控件 | 无网络，无 SMS |

成功登录分支无 controls。特有错误包括 `invalid_phone_number/invalid_sms_code/laundry_login_required/account_mismatch/unexpected_web_origin/invalid_credential/invalid_response/laundry_rejected_<code>`。user/info code=2 的业务码仍显示在 message。旧凭据日期兼容和账号一致性会在恢复时验证；任何失败均不写入新凭据。

### `laundry-orders`

从本机凭据取 token，GET `order/list?page=<page>&pageSize=10&token=<token>`，保留 `+` 的百分号编码。列表项必需 id/orderType/orderStatus，parentTypeId 兼容整数或字符串。各订单 row 显示完整返回字段，行 action 为 `laundry-order(orderId)`。

普通模式返回页码/总数 message、page 控件、查询/运行中/上一页/下一页 actions。根据非空 items 且 page*10<total 推导下一页。

`running=true` 时遍历全部页，按 ID 去重且无新记录时停止；只选 orderType=1、orderStatus=2、parentTypeId 等于洗衣机类型的订单，再逐一获取最新详情并重新检查运行状态。返回带倒计时的 rows、重新查询 action，额外 `snapshots` 数组，无 controls。只有已确认遍历完成且无运行中洗衣订单时显示“当前没有使用中的洗衣机订单”。

特有错误包括 `laundry_login_required/invalid_credential/invalid_pagination/invalid_response/account_changed/laundry_rejected_<code>`。详情或后续页失败会使整次查询失败，不能显示部分结果为完整空列表。

### `laundry-order`

POST `order/detail` 的 orderId/token，返回 ID 必须等于请求 ID。预计结束时间 completeTime 按严格 `YYYY-MM-DD HH:mm:ss`、Asia/Shanghai 解析。仅运行中洗衣机且有合法结束时间才计算倒计时。使用 HTTP Date 作为服务器时间，缺失/无法解析时回退为接收时刻。剩余秒数为非负 ceil(结束-服务器时间)；本地读取时按自 observedAt 起的整秒递减到零，时钟回退不增加秒数。已完成订单、缺少结束时间的订单使用 null，显示“未提供”。

返回订单所有字段、北京时间预计结束、剩余分秒、remainingSeconds/observedAt；无 controls。actions 为更新剩余时间（使用缓存）及立即从服务端刷新（refresh=true）。额外 `snapshot={order,estimatedCompletionTime,observedAt,remainingSeconds}`，两个时间使用 UTC ISO 字符串，结束时间可为 null。snapshot 中 remainingSeconds 是 observedAt 时刻值，row 中值是此次显示时刻值。

缓存窗口依当前剩余值动态缩短，大于 600 秒为 120 秒，大于 300 为 60 秒，大于 120 为 30 秒，其他为 0。窗口边界即失效，零秒后重新询问服务器以允许订单延长。失败不缓存，并清理 pending 以允许下一次重试。`refresh=true` 绕过已完成缓存，但仍共用同一订单的在途请求。

错误包括 `invalid_query/laundry_login_required/invalid_credential/invalid_response/account_changed/laundry_rejected_<code>`。非法日期或订单 ID 不一致不会得到伪造倒计时。

## 错误对象

所有资源以 `FoundationException(code,message,{status})` 抛出边界错误。不会将失败包装为 `rows:[]`。

| 公共 code | 含义 |
| --- | --- |
| `unknown_resource` | 未注册资源 |
| `invalid_query` / `invalid_url` / `invalid_pagination` | 入参类型、地址、页码不合法 |
| `tgt_required` | 没有当前学校 TGT，尚未请求个人学校服务 |
| `invalid_credential` | TGT 或保存的胖乖凭据格式无效 |
| `authentication_required` | 学校会话或 TGT 失效；须交由父级恢复认证后重试 |
| `unexpected_status_code` | 响应状态不符合原库要求，status 保存 HTTP 状态码 |
| `unexpected_redirect` | 最终站点、路径或手动重定向边界不符合预期 |
| `invalid_response` | 响应 JSON/字段/类型不符合合同，不能确认空结果 |
| `account_changed` | 胖乖请求期间已清除或切换账号，拒绝返回旧结果 |

业务失败分别使用 `library_rejected_<code>`、`shuttle_rejected_<code>`、`second_class_rejected_<code>`、`laundry_rejected_<code>`，message 显示原业务码。原库的 `ticketExchangeRejected`/`unexpectedStatusCode` 等在 Dart 统一为授权、重定向或状态错误并保留 HTTP 状态；不是业务码丢弃。

`SchoolTransport` 自身的 `cancelled/network_error/network_timeout/response_too_large/unsafe_url/unsafe_redirect/redirect_limit` 等错误直接传递。MD5、加密存储等原生错误由平台层传递；通知字符集解码失败映射为 `invalid_encoding`，取消仍保留 cancelled。

## 合成调用示例

以下均为 fake transport 使用的参数示例。真实端点集成由父级审核；不会在文档生成或测试时调用学校个人服务或胖乖短信。

```dart
await fixtureServices.query('notices', options: {'source': 'academicAffairs'});
await fixtureServices.query('notice-detail', options: {
  'url': 'https://www.wust.edu.cn/info/1001/123.htm',
  'publishedDate': '2026-11-09', 'title': '合成通知', 'source': 'campus',
});
await fixtureServices.query('notice-file', options: {
  'url': 'https://www.wust.edu.cn/files/test.pdf',
  'sourceURL': 'https://www.wust.edu.cn/info/1001/123.htm', 'name': '合成文件',
});
await fixtureServices.query('library');
await fixtureServices.query('library-profile');
await fixtureServices.query('library-loans', options: {'kind': 'overdue', 'page': 1, 'pageSize': 20});
await fixtureServices.query('library-search', options: {'keyword': '合成'});
await fixtureServices.query('library-fines', options: {'page': 1});
await fixtureServices.query('library-requests', options: {'page': 1});
await fixtureServices.query('library-booklist', options: {'id': 'fixture-list'});
await fixtureServices.query('library-booklist-books', options: {'id': 'fixture-list', 'page': 1});
await fixtureServices.query('shuttle');
await fixtureServices.query('second-class');
await fixtureServices.query('laundry');
await fixtureServices.query('laundry-shops', options: {'latitude': 30.439405, 'longitude': 114.268024});
await fixtureServices.query('laundry-devices', options: {'shopId': 'fixture-shop', 'machineCount': 3});
await fixtureServices.query('laundry-sms'); // 只返回表单，不请求短信。
await fixtureServices.query('laundry-sms', options: {'action': 'send', 'phone': '10000000000'});
await fixtureServices.query('laundry-login', options: {'action': 'login', 'phone': '10000000000', 'smsCode': '123456'});
await fixtureServices.query('laundry-login', options: {'action': 'restore'});
await fixtureServices.query('laundry-orders', options: {'running': true});
await fixtureServices.query('laundry-order', options: {'orderId': 'running-washer', 'refresh': true});
await fixtureServices.query('laundry-login', options: {'action': 'clear'});
```

## 验证与复跑

可独立运行的纯解析探针为 `test/foundation/campus_parsers_probe.dart`，请求探针为 `campus_services_probe.dart`，Flutter 包装测试为 `campus_parsers_test.dart` 和 `campus_services_test.dart`。全部数据为 `campus_fixtures.dart` 或测试内合成值。假 transport 覆盖 send，绝不访问网络；假平台只保存测试内存值。

本工作树没有主线 transport/platform 文件。`campus_offline.dart` 从指定的主线 foundation 目录只读复制两个合同文件，与本工作树校园源码和探针一起放入系统临时目录运行；结束删除本次临时目录。不 pub get、不构建 Flutter、不写主工作区。运行器输出仅为检查计数和静态分析结果。

本次实际执行命令如下。

```powershell
& 'E:/blog/WUSTWI~1/.cache/flutter-build/flutter/bin/cache/dart-sdk/bin/dart.exe' `
  mobile/test/foundation/campus_offline.dart `
  'E:/blog/WUST wiki/mobile/lib/foundation' `
  'E:/blog/WUST wiki/mobile/.dart_tool/package_config.json'
```

```text
Campus parser checks passed: 78
Campus service checks passed: 84
Analyzing foundation, campus_services_probe.dart...
No issues found!
```

源 Swift 测试移植重点为 `SecondClassTests.swift`、`LaundryOrderTests.swift`、`LaundryOrderMonitorTests.swift`。额外覆盖通知/PDF URL 和正文边界、日期策略、GBK 桥接参数、TGT 缺失、严格 CAS 边界、所有图书馆原接口、门户签名字节与 Base64/hex 转换、短信显式动作及验证码预检、旧加密值格式/Swift 日期、服务器时钟、设备排序与去重、订单跨页/并发/缓存/失败重试及账号清除后的迟到结果。

原生 MD5 的真实运算、GB18030 的 Android 实际字符转换、Keystore 解密旧安装数据、真实 Cookie/服务端响应、WebView 胖乖登录、SMS 发送、个人查询、PDF 在 Android 打开及 APK 交互均未由本子任务验证。合成探针对上述平台能力只验证调用合同。最终真实账号只读验证、安装包依赖检查及父级 Flutter 组合测试由主线执行；未授权短信和个人服务仍不调用。

## Figure-it-out 工作流与决策记录

验收谓词为所有约定 resource 有请求/解析/结果合同，保留服务失败业务码及鉴权要求；纯解析及 fake transport 断言通过且静态分析无问题。工作按源码盘点、纯解析及夹具、请求编排、跨服务边界、接口文档五个单元推进。风险较高的鉴权、短信和订单时间使用严格离线 gate；真实账号与 Android 能力标为 NOT VERIFIED，不用合成结果推断上线可用。

Foundational Thinking 使解析器先独立于 transport 落地；Sequence Work into Verifiable Units 使纯解析通过后才接入请求；Prove It Works 使结论绑定实际探针输出。按任务禁止启动子代理，未执行技能中的子代理审查；没有创建 PR。

受本任务只允许指定文件的范围约束，审计表内嵌在本文件，父级可合并进总 TSV 决策记录。时间为补记时间，行为证据均为本次已读取的原源码或已执行探针。

```tsv
ts	phase	decision	why	evidence	result
2026-11-25T00:12:25+08:00	frame	限定为校园模块和离线测试	遵守父级隔离实现及不调用真实个人服务的授权边界	mobile/migration/dart-plan.md	VERIFIED
2026-11-25T00:12:25+08:00	parser	先落地独立纯解析器再实现请求	让原 Swift 行为断言能在缺主线文件的工作树中运行	mobile/test/foundation/campus_parsers_probe.dart	75 checks passed at this checkpoint
2026-11-25T00:12:25+08:00	contract	要求响应 headers 并保留字符集解码能力	Location 与 Date 是原认证和订单时间行为必需值	mobile/lib/foundation/campus_services.dart	父级已确认并提供合同
2026-11-25T00:12:25+08:00	library	将搜索明确为原有书单目录筛选	原 Swift 无全馆关键词检索端点证据	WUSTFoundation-android/Sources/WUSTFoundation/Library/Networking/LibraryRequestFactory.swift	VERIFIED
2026-11-25T00:12:25+08:00	orders	用服务器时钟并复用原缓存窗口	保持原订单测试的 142 秒与阈值校正行为	mobile/test/foundation/campus_services_probe.dart	84 checks passed
2026-11-25T00:12:25+08:00	verify	只读复制主线合同到临时目录核验	不写主工作区且实际编译执行校园源码	mobile/test/foundation/campus_offline.dart	No issues found
2026-11-25T00:12:25+08:00	handoff	平台和真实服务验证留给主线	本任务没有真实账号短信或构建授权	mobile/migration/campus-port.md	NOT VERIFIED
2026-11-25T00:19:22+08:00	boundary	在 URI 归一化前检查原字符串用户信息并保留门户回调编码	探针发现空用户信息会被 Dart URI 归一化消除且授权参数必须保留加号和编码分隔符	mobile/test/foundation/campus_services_probe.dart	VERIFIED
2026-11-25T00:19:22+08:00	credits	使用十进制系数计算剩余学分	保留原 Decimal 的常用学分显示并避免浮点减法尾数	mobile/test/foundation/campus_parsers_probe.dart	78 parser checks passed
```

Attention：未做独立模型审查，原因是本子任务明确禁止启动子代理。主线导入后须核验 action/controls 合并规则、公开 transport 选择、decodeText/digest/存储适配，以及 Flutter/Android 实际行为；这里的离线通过不等于 APK 已验证。
