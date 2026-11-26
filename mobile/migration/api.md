# 移动端接口总册（0.6.3）

业务源码为 `lib/foundation/`。账号密码入口直接连接学校，通知与胖乖直接连接各自服务器，客户端无需另部署后端。Android Java 提供加密存储、图像、OCR、文件及系统视图。保留的学校网页／微信入口仍使用 Wiki 后端，另见 [academic-query.md](../../docs/academic-query.md)。

本总册与 [教务完整合同](academic-port.md)、[校园及洗衣完整合同](campus-port.md) 共同构成完整接口文档。两个分册逐项列明 options、返回、学校端点、controls/actions、错误码、来源与合成示例。示例不含真实账号，不能作为真实服务已经授权的证明。

## 应用入口

`FoundationApi.request(Map<String,dynamic>) -> Future<Map<String,dynamic>>`；默认实现 `DartFoundationClient(AndroidFoundationPlatform())`。失败抛 `FoundationException(code,message,{status})`，不把失败包装成空结果。`cancel()` 同步中断本实例全部认证、网络和等待；可重新发起查询。界面应忽略取消页面的迟到结果。

| action | 输入 | 成功返回 |
| --- | --- | --- |
| `login` | `username,password` 非空字符串 | `ok:true,state:'authenticated',sessionToken:'local',expiresAt:0,unifiedVerified:true,academicVerified:bool,restoredWithPassword:false` |
| `inspect` | 无 | 同上，restoredWithPassword 表示此次是否读取已存密码恢复 |
| `query` | `resource:String,options:Map={}` | `ok:true,state:'complete',result:Map,academicVerified:bool,unifiedVerified:bool`；教务另有 restoredWithPassword |
| `logout` | 无 | `ok:true,state:'idle'`，取消并等待在途请求后清除当前学校账号凭据 |
| `cancel` | 无 | `ok:true,state:'cancelled'` |

`local` 是路由标记，不是学校令牌；expiresAt=0 不表示 Cookie 永久有效。公开资源不把教务状态标为已验证。`AcademicStore(foundation:可注入实例)` 的 `sendLocal` 返回外层包装，转换错误为 AcademicApiException；`queryService(resource,{options})` 直接返回 result。原 api 仍根据 bearer 选择本机／保留的远程入口。

```dart
final api = DartFoundationClient(const AndroidFoundationPlatform());
await api.request({'action': 'inspect'});
final data = await api.request({
  'action': 'query', 'resource': 'exams', 'options': {},
});
final rows = data['result']['rows'];
api.cancel();
```

登录参数示例 `{'action':'login','username':'SYNTHETIC','password':'SYNTHETIC'}` 仅作格式说明，不应向真实学校提交占位凭据。离线验证应注入测试 transport/platform。

## resource 索引

| resource | 功能 | 分册 |
| --- | --- | --- |
| `schedule` | 整学期课表、学期与模板 | academic-port.md |
| `grades` | 成绩、性质、重修与显示模式 | academic-port.md |
| `student` | 学生信息，不返回身份证值 | academic-port.md |
| `exams` | 集中与自行申请考试 | academic-port.md |
| `credits` | 学分类别、学期与课程进度 | academic-port.md |
| `calendar` | 日期和教学周 | academic-port.md |
| `training-plan` | 方案目录、表单及课程筛选 | academic-port.md |
| `raw-schedule` | 原始课表响应导出 | academic-port.md |
| `notices` | 五个来源、日期策略和分页 | campus-port.md |
| `notice-detail` | 全文、图片、链接和附件 | campus-port.md |
| `notice-file` | 校内 PDF，20 MiB 限制 | campus-port.md |
| `library` | 统计、当前借阅与即将到期 | campus-port.md |
| `library-profile` | 读者资料 | campus-port.md |
| `library-loans` | 当前／历史／即将到期借阅 | campus-port.md |
| `library-search` | 原库书单目录名称筛选 | campus-port.md |
| `library-fines` | 违章 | campus-port.md |
| `library-requests` | 预约 | campus-port.md |
| `library-booklist` | 书单资料 | campus-port.md |
| `library-booklist-books` | 书单书目分页 | campus-port.md |
| `shuttle` | 校车时刻表 | campus-port.md |
| `second-class` | 第二课堂学分与评价 | campus-port.md |
| `laundry` | 状态与服务入口 | campus-port.md |
| `laundry-shops` | 区域和店铺 | campus-port.md |
| `laundry-devices` | 设备、排序和可用状态 | campus-port.md |
| `laundry-sms` | 显式短信预检与发送 | campus-port.md |
| `laundry-login` | 验证码／密码登录及退出 | campus-port.md |
| `laundry-orders` | 运行和历史订单分页 | campus-port.md |
| `laundry-order` | 详情及服务器时钟倒计时 | campus-port.md |

前八项用独立教务会话；library*、shuttle、second-class 各自保存业务 Cookie，失效时通过新版统一认证 SSO 取一次性 ST 重新建立。当前正式调用不要求用户提供 TGT，也不把 Cookie 当成 TGT。旧 TGT provider 只保留为原库兼容合同。胖乖凭据独立。library-search 遵循原库书单目录，原库没有全馆关键词检索端点。

## 通用结果与界面动作

`rows:[{title,fields:[{name,value}],action?:{resource,options}}]`，字段为显示字符串。可选 title/message/controls/actions/files，仅已确认的空结果才返回空 rows。全文、结构化详情等额外字段见分册。

`controls:[{key,label,type:'text'|'select'|'password',value,options?:[{value,label}]}]`，控件提交保留真实选项值。隐藏学校字段每次从新表单读取，不让 UI 保存或覆盖。`actions:[{label,resource,options}]`：同资源合并当前查询 options、控件、动作 options；跨资源只带控件与动作 options；行 action 直接使用其 options。固定分页值由动作覆盖。短信必须用户显式确认，不后台重试发送。

`files:[{name,mime,base64}]` 交 Android 导出／预览，不上传。通知全文不执行脚本。Android exportFile 返回 ok 才算保存；打开 PDF 不代表用户读完。

## 登录、重试和并发

首次登录先原子保存账号密码，预热教务入口，读取学校认证表单，按原 AES 协议提交。需要滑块时用 Dart isolate 中的灰度归一化相关匹配；Android 仅解码像素。最终校验空白页以及学校返回学号与所选账号一致。

重启分别恢复统一认证和业务 Cookie；业务失效先用 SSO 取票，统一认证过期才读取加密密码。临时失败首次后最多重试四次，总计五次，间隔一秒；明确账号密码错误、锁定、密码过期或额外验证立即停止。取消立即打断等待和网络。并发恢复共享一个流程，业务 authentication_required 触发一次共享恢复并重查一次。网络故障保留磁盘凭据。学校会话期限由学校决定。本机账号切换清可见旧课表；退出清当前学校账号的 password/session/dart-session/tgt 和 active-account。胖乖独立退出。

错误含稳定 code、可读 message、可选 HTTP status；不带个人响应、Cookie、密码。业务拒绝码保留数字。

| code | 含义／处理 |
| --- | --- |
| login_required | 无账号或无密码，显示登录入口 |
| operation_in_progress / cancelled | 等待当前操作／取消后不自动重启 |
| invalid_input / unsupported_action / unsupported_resource | 修正调用 |
| cookie_missing / invalid_session / student_id_mismatch | 会话校验失败 |
| invalid_response / invalid_login_form / unsafe_form / login_not_completed | 学校页面或认证变化 |
| system_unavailable / student_record_missing / remote_system_error / http_error | 学校禁用、缺记录或故障 |
| encryption_failed / invalid_slider_response / slider_no_match / slider_rejected / login_failed | 加密、滑块或最终登录失败 |
| network_error / network_timeout | 保留凭据，可重试 |
| unsafe_url / unsafe_redirect / redirect_limit / response_too_large | 地址、重定向、容量边界拒绝 |
| platform_failed | Android 能力失败 |

资源特有 parse_error、unsupported_form、selection_not_reflected、tgt_required、library_rejected_数字、胖乖业务码等见分册。

## HTTP、Cookie 与编码

`SchoolTransport.send(Uri,{method='GET',form:Map<String,String>?,formFields:List<MapEntry<String,String>>?,jsonBody,headers={},followRedirects=true})` 返回 SchoolResponse(status,uri,bytes,headers)，headers 为小写键，text 严格 UTF-8，json 解析 JSON。form 与 formFields 互斥，后者保留同名 hidden 多个值。跨源 307/308 禁止 POST，302 POST 转 GET 并去掉请求体／认证头；重定向响应 Cookie 逐条保存，最多十次。

默认 HTTPS 和正常证书校验。独立公开通知 transport 可访问学校域名 HTTP GET/HEAD，不能携带凭据或请求体；Android 网络安全策略须匹配。测试 HTTP 仅 loopback。连接 30 秒、响应及流间隔 40 秒，最大64 MiB；通知额外20 MiB。Cookie 按域名、路径、安全和过期隔离，拒绝公共后缀。通知仅在严格 UTF-8 失败且响应明确声明 GBK/GB2312/GB18030 时调用对应字符集解码。

## Android 能力接口

`MethodChannel('wiki/native').invokeMapMethod('foundationCapability',{'operation':名称,...参数})`。Dart 包装为 AndroidFoundationPlatform.invoke。所有二进制用标准 Base64。

| operation | 参数 | 返回 |
| --- | --- | --- |
| load | key | `{value:String}`，不存在 `{}` |
| save / clear | key,value / key | `{}`，持久化失败抛错 |
| saveAccount / clearAccount | username,password / username | `{}`，原子存储／清理 |
| deviceID | 无 | `{value:String}`，沿用原设备 ID |
| digest | algorithm,data(Base64) | `{data:Base64}`，门户使用 MD5 |
| aes | key,iv,data(Base64) | `{data:Base64}`，AES/CBC/PKCS5Padding |
| rsa | key,data(Base64) | `{data:Base64}`，原库1024位裸RSA协议 |
| raster | data(Base64),height?:int | `{width,height,pixels:Base64}`，预乘透明度RGBA |
| ocr | data(Base64) | `{text:String}`，ML Kit Latin 16.0.1，去换行 |
| decodeText | data(Base64),charset | `{text:String}`，仅GBK/GB2312/GB18030严格解码 |
| exportFile | name,mime,base64 | `{ok:true}`，用户取消 `{ok:false,cancelled:true}` |
| openPdf | name?,base64 | `{ok:true}`，打开本机PDF视图 |
| acceptanceStatus | 脱敏阶段字段 | `{}`，仅调试包，固定应用私有阶段文件 |

原 wiki/native 的 restore/save（Wiki设置和课表缓存）、wechat/external，以及 wiki/article、wiki/dorm、wiki/school-portal 平台视图仍保留。业务不再调用 academic/cancelAcademic/foundationTools Swift 桥。

## 存储与迁移

保持 Keystore 别名 WUSTFoundation.credentials、SharedPreferences credentials 和 Base64 IV + `.` + Base64 AES-GCM密文格式。key 为 active-account、password:账号、session:账号、dart-session:账号、tgt:账号、独立 laundry。旧 Swift Cookie 日期为2001纪元秒数，新会话为Base64 JSON `{version:2,cookies:[...]}`、Unix毫秒日期。新成功快照不覆盖旧格式；失效和退出清两种会话。胖乖保持原Base64 JSON和Swift日期，见分册。

Wiki课表缓存仍最长七天，校验 fetchedAt/expiresAt。应用私有凭据和真实查询内容不进日志与源码包。当前验收及未验证边界见 [集成记录](../foundation-integration.md)。

`SchoolAuthentication.verifyCaptcha({withService:false})` 提供原独立滑块示例能力，不提交账号密码；withService=true 先预热教务服务。可选 observer 只由调试入口消费脱敏阶段信息，正式调用默认关闭。Android 文件能力另有 busy（已有文件操作未结束）、invalid_arguments（参数／大小无效），文件上限20 MiB；MIME可带charset，交系统选择器前只保留基础类型。


0.6.1运动协议补充：`SliderSolution.payload({Random? random})` 每次生成新的有限加减速轨迹；random参数供离线确定性测试，正常调用使用系统安全随机源。横向小幅噪声和上下漂移均有界，保留20ms／2px采样与释放点。最后一点直接使用moveLength原值；提交前按各点依次等待，将c改写为实际相邻采样间隔，再进行一次AES加密提交。取消在等待前后校验代次，避免取消后继续等待或提交。定位阈值和最多3次滑块、最多5次登录限制不变。统计口径及同图诊断见 [滑块回归记录](slider-0.6.1.md)。

短距离轨迹的计划总间隔下限每次随机取1800–2300ms；只延长较短轨迹，按累计时间比例分配各点间隔。运行时仍记录实际等待，而非直接提交该计划时长。该值为0.6.1现场诊断后的工程选择，不宣称是学校公开常量。

## 0.6.3 统一认证与各业务会话

`SchoolAuthentication.login(username,password)` 建立并保存统一认证会话，不依赖教务系统是否可用；`ensureIdentity()` 共享恢复流程。认证中心取票使用已存在的教务 service 作为探测目标，验证重定向票据但不访问教务服务器，因此不是把教务 Cookie 当统一认证。`ensureSession()` 只负责教务业务；`withSession(operation)` 在业务认证失效时单独重建并重查一次。有效业务 Cookie 可独立复用。

`serviceTicket(String service)` 仅允许 schoolServices 中的四个原库 service；通过 GET /authserver/login?service=... 使用 SSO，不再次提交密码。只接受对应 HTTPS host/port/path、单一 ST-票据的重定向；不将密码 POST 转发到业务域。图书馆 service 字符串显式保留 :443。ST 只保留在内存，不写日志或磁盘。统一认证是否有效由认证中心签发 ST 确认。

`businessSession('library'|'shuttle'|'second-class')` 恢复独立 transport；`saveBusinessSession(key,http)` 保存当前账号的业务 Cookie。统一认证 transport 和业务 transport 分开，业务 transport 不导入认证中心 Cookie。CampusServices 构造可传 `ticketProvider:auth.serviceTicket` 和 `onQuery:回调`；未传 provider 时才走原库 credential/TGT 合同。请求取消与账号切换受代次约束；手动登录先取消并等待旧请求收尾，防止迟到快照写回。退出清当前账号的全部分层存储，胖乖独立。

新增加密存储键：`union-session:账号`（version:1,cookies）、`business-session:业务:账号`（version:1,cookies）、`auth-blocked:账号`（稳定错误码）。教务仍用 dart-session:账号（version:2）。首次升级从旧 Cookie 集合只迁移适用于认证中心的 Cookie，再向学校确认；业务快照不因单个业务过期而删除统一认证。密码错误清除这份已拒绝的保存密码并保留阻止自动尝试的标记；用户手动提交新账号密码才清标记。

`credentials_rejected` 提示“账号或密码错误，请检查并修改后重新登录。”；明确拒绝只提交一次，不进入剩余四次重试，后续查询及应用重启不继续使用旧密码。`account_locked`、`password_expired`、`interactive_login_required` 也立即停止。分类只读取学校实际错误容器（showErrorTip/msg/formErrorTip/errors），不扫描包含静态错误文案的整页脚本。验证码错误保持 captcha_rejected/slider_rejected，不误报密码错误。未识别的错误不推断为密码错误；学校二次验证不自动发短信。

## 统一过程状态

DartFoundationClient 同时实现 `FoundationProgressSource`：`progress:Stream<FoundationProgress?>`、`currentProgress:FoundationProgress?`。FoundationProgress 包含 message、startedAt、activeCount、resource?、attempt?，没有 URL、票据、账号、密码或响应正文。每个请求有独立编号，迟到完成／取消不能清掉新请求的状态。null 表示没有在途请求；错误仍由原 Future 抛出，状态流不吞错。

SchoolOperationStatus(api) 在登录、教务、课表和校园服务页面复用，显示正在恢复会话、正在登录、正在验证、正在为具体业务建立会话、正在查询具体服务、重试次数与已等待秒数。8秒后显示“仍在处理，请稍候”，不虚构百分比。状态来自实际步骤，密码被拒绝显示更新账号入口并隐藏原查询重试按钮。

本版现场证据与边界见 unified-0.6.3.md；0.6.1 验证码统计不自动变成本版手机成功率。
