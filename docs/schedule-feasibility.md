# 课表查询接入可行性

核查日期：2026-09-23。仅做可行性调查，未实现页面、修改部署、登录账户或发送验证码。用户提供的个人分享 UUID 和课程内容不写入仓库。

后续进展：用户已授权开发本地扫码登录模板，三种方式的源码、启动与验证边界见 [登录模板说明](schedule-login-templates.md)。下文保留最初可行性调查的时点；二维码创建与未扫码轮询后来已实测，真实扫码认证仍待用户验证。

## 结论

优先采用「用户粘贴学习通课表分享链接 → Wiki 只读代理 → 课表展示」。提供的样例已经通过无 Cookie、无 Authorization 请求验证，可以免向 Wiki 提供密码。这个结论只覆盖本次样例，不保证所有课表、学校或未来版本均允许匿名分享。

学校教务数据可考虑「用户在学校网站自行登录 → 导出或本地提取 → Wiki 本地导入」。需要实际导出样例或已登录课表页面才能确定格式；尚未验证自动同步、匿名按学号查询或官方第三方授权接口。

## 学习通：实测证据

第一方源码：[PC 课表页面](https://kb.chaoxing.com/res/pc/curriculum/schedule.html)、[schedule.pc.js](https://kb.chaoxing.com/res/pc/curriculum/js/schedule.pc.js?v=15)。本次源码中 `Schedule.loadLessons` 在 1022 行附近，分支在 1034–1037 行：

- URL 含 `curriculumUuid` 时，GET `/curriculum/getOtherLessons`，沿用 UUID，并可附加 `week`。
- 无 UUID 时调用 `/pc/curriculum/getMyLessons`；不能把分享入口的匿名能力推断为账户课表入口也免登录。
- 页面二维码和转发逻辑生成带 `curriculumUuid` 的分享地址，访客分支隐藏编辑操作。

使用 Node fetch（不使用浏览器登录态，不带 Cookie / Authorization）对用户明确提供的 UUID 请求：

| 请求 | HTTP / 业务结果 | 数据摘要 |
| --- | --- | --- |
| 不指定周次 | 200 / `result: 1`、`visitor: 2` | 2026–2027 第 1 学期，当前第 4 周，`lessonArray` 12 条 |
| 指定 `week=5` | 200 / `result: 1`、`visitor: 2` | `lessonArray` 11 条 |

这是每周排课条目数，不代表不同课程门数或全学期课程总数。返回字段包含课程名、教师、地点、星期、起始节次、连续节数、适用周次，以及学期起始日期、最大周数和节次时间配置，可以据此绘制周课表。指定第 5 周时 `curriculum.currentWeek` 仍为 4，展示周次应使用请求选定的周，而不是无条件采用该字段。

浏览器直接访问分享页，已看到学期、周次、节次时间和课程。API 请求附带 `Origin: https://wiki.wustacm.com` 时仍成功返回，但未返回 `Access-Control-Allow-Origin`：当前不适合从 Wiki 浏览器直接跨域 fetch；可使用固定上游的同源只读代理。

页面响应未见 `X-Frame-Options` / CSP，但本地临时 iframe 检查在当前内置浏览器内仍为空白，未确认原因。因此「直接嵌入即可用」尚未证实，不作为已通过的方案。

## 学校与武科大助手：认证边界

用户指定参考目录是 APK 反编译恢复项目，根目录为：

`C:/Users/LEGION/OneDrive - Default Directory/文档/ChatGPT/武科大助手/recovery`

以下源码位置均相对该目录；它们是参考客户端证据，不是对第三方服务当前可用性的验证：

| 来源 | 发现 |
| --- | --- |
| `jadx/sources/com/example/wusthelper/request/WustApi.java:90`、`RequestCenter.java:110`、`NewApiHelper.java:594` | 本科课表调用助手后端 `https://lyzyy.love:8081/UnderGraduate/Support/getCoursesPage`，带 Bearer 会话；不是学校官方公开 API |
| `jadx/sources/com/example/wusthelper/request/NewApiHelper.java:216`、`:259` | 有短信验证码、微信扫码登录链；可免输入密码，但仍需第三方认证，首次绑定要求及当前服务可用性未验证 |
| `jadx/sources/com/example/wusthelper/request/NewApiHelper.java:627` | 研究生课表封装提交学号和密码，不满足本次免密码偏好 |
| `jadx/sources/com/example/wusthelper/helper/DynamicScheduleLab.java:351`、`request/NewApiHelper.java:608` | 动态共享或旧二维码也涉及认证/Token，不能当成普通匿名课表链接 |

未在相关应用源码中找到匿名班级课表或标准 ICS 导出实现；不能由此断言学校网站没有导出功能。

匿名 GET [本科教学综合管理系统](https://bkjx.wust.edu.cn/) 返回登录页面和 `X-Frame-Options: SAMEORIGIN`；学校统一认证登录入口返回应用壳和 `X-Frame-Options: DENY`。不能把官方登录页直接 iframe 嵌入 Wiki。本轮没有登录或请求校方个人课表业务接口。

[学校 2026–2027 学年第一学期课程正选通知](https://jwc.wust.edu.cn/info/1371/50802.htm)明确要求通过统一身份认证登录，并以本科教学综合管理系统为准；第三方可能同步不及时、漏掉尚未安排具体上课时间的课程。

## 建议的实现范围

1. 在现有 `/study/curriculum` 增加个人课表入口，接受用户自己的学习通分享链接，解析并校验 UUID。分享标识具有访问该课表的能力，默认不放在公开页面、仓库、统计事件或公开访问日志里；用户需要先在学习通取得链接。
2. 复用 Wiki 页面外壳和 Nuxt UI，代理仅允许固定学习通主机、只读课表路径及必要参数。不转发用户 Cookie / Authorization，不接受任意上游 URL，只返回展示必需字段，设置 `private, no-store`，避免记录完整分享标识。
3. 初版按周查询，显示来源、获取时间、上一周/下一周及官网核对入口；不要宣称学习通与教务系统实时一致。链接失效或访问受限时明确提示。
4. 分享链接及课表仅在用户浏览器保存，提供清除；是否记住链接由用户选择，不预生成个人数据。上游内部接口没有已核实的稳定性承诺，需要容错和维护。
5. 后续学校导入方案让密码始终留在学校登录页面，Wiki 只在本地解析用户选择的课表数据。导出格式、提取方式和更新流程待样例核验。

项目默认是静态部署。自定义课表展示所需代理必须由线上 Node/Serverless/边缘函数或已有服务承接，单独上传 `.output/public` 不会部署 Nitro API。现有美食代理可参考边界设计，但个人课表不宜沿用公开目录的缓存或日志方式。

本轮只新增此记录；Wiki 页面和线上服务均未变更。没有运行构建，因为未改应用源码。

## 补充：学习通扫码登录

同日根据用户追问，进一步区分两种二维码：

- **课表分享二维码**：`schedule.pc.js` 589 行附近把带 `curriculumUuid` 的分享链接编码为二维码。Wiki 扫描或本地识别这类图片后，可以沿用已验证的分享接口，无需获得账号登录态。二维码识别本身尚未实现。
- **App 扫码登录二维码**：匿名读取 [学习通官方登录页](https://passport2.chaoxing.com/login)，HTML 明确写有“使用学习通APP扫码登录”。内联代码用 `/getauthstatus/v2` 查询状态，成功后跳转 `refer` 或个人空间，另有二次认证分支；二维码生成/刷新引用 `/createqr` 和 `/refreshQRCode`。本次只读源码，没有生成二维码、轮询或执行登录。

因此「Wiki 显示登录二维码 → 用户用学习通确认 → 后端读取本人的课表」是可进一步验证的技术路线，可避免提交账号密码，但后端仍需处理账号登录 Cookie/会话，不能将其说成只获得课表权限。登录态获取、跨超星子域会话、扫码后二次认证、读取当前学期课表与失效处理尚未端到端验证。纯静态页面也不能直接读取另一域名的登录 Cookie。

官方另有 [OAuth 接入流程](https://auth.open.chaoxing.com/open/doc/list/yluywps0/zpsakobd/u58aqj3r)、[获取认证 code](https://auth.open.chaoxing.com/open/doc/list/yluywps0/zpsakobd/88c1cxll) 和 [用户信息接口](https://auth.open.chaoxing.com/open/doc/list/yluywps0/zpsakobd/ous9d2kh)。本次通过搜索索引读取了这些第一方文档，页面直连失败。文档说明应用注册、appid、回调域名和用户信息授权；没有找到该授权可读取个人课表的明确说明，不能将用户信息 access_token 当成课表接口 Cookie。正式第三方授权路线需先确认可申请的课表权限。

若后续选择扫码登录原型，建议登录会话仅短时驻留服务端内存，获取所需课表或分享标识后清除；不持久化 Cookie、不记录凭据、不自动访问其他账号数据。这是拟议实现边界，尚未实现。

## 补充：学校微信扫码登录

2026-09-23 实际浏览器访问学校统一认证入口，页面标题为「认证中心-统一身份认证平台」，显示「扫码登录 / 账号登录 / 短信登录」三个选项，扫码页明确标注「微信扫码」。这确认了学校认证页面确有微信扫码方式，不只是根据其他学校或企业微信文档推断。本轮未扫码确认、未登录、未读取个人教务课表。

[官方移动端上线通知](https://jwc.wust.edu.cn/info/1371/47472.htm)还确认：绑定武汉科技大学企业微信后，可通过「工作台 → 推荐应用 → 教务系统」访问本科课表查询。此入口与桌面统一认证页面的「微信扫码」应分别描述。

据此，「校方扫码认证 → 教务系统登录会话 → 查询个人课表 → Wiki 展示」值得进行原型验证，能避免向 Wiki 提交密码；但校方回调、票据换取教务会话、课表响应格式及短期会话失效尚未验证。不能因为登录页提供扫码就宣称 Wiki 自动导入已经可用。若用户只在自己的官方网页完成登录，静态 Wiki 不能跨域直接读取该登录状态；需要正式授权接入、受控后端会话桥接，或用户端本地提取/导入方式。

本轮重查学校入口仍返回 `X-Frame-Options` 限制（教务 `SAMEORIGIN`，认证 `DENY`），不能以直接 iframe 嵌入官方登录页作为方案。二维码回调也不能未经校方支持就改成 Wiki 域名。学校路线暂未发现类似学习通课表 UUID 的匿名分享机制，不能沿用「取得 UUID 后长期匿名读取」的假设。
