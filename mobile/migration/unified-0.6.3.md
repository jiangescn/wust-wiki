# 0.6.3 统一认证、业务会话与过程状态

目标为维护统一认证登录态，再为各业务建立独立会话。账号密码、Cookie仍只存本机Android Keystore加密区；原学校网页／微信入口继续保留。首次临时失败后重试四次、累计五次停止；明确密码错误立即停止，要求用户更新。

## 协议选择与来源

直接复用原库 AuthServerLoginService 的现行 CAS 表单、AES、滑块和安全边界，必要适配为 authserver 的 SSO 取 ST 与各业务 Cookie 分层。原库 UnionAuthRequestFactory 的 /lyuapServer/loginType 和 /lyuapServer/kaptcha 在本次公开只读核对中为404，/lyuapServer/login跳转/authserver/login。因此本版不伪造TGT，不依赖不可用的旧TGT配置接口。旧credential provider仅为原库兼容调用保留。

统一认证只跟踪auth.wust.edu.cn；业务各有独立transport。SSO恢复通过认证中心给已注册service签发一次性ST来确认，不依赖教务服务器响应。取得票据与业务查询分开验证。只允许原库四个service，图书馆必须保留注册地址中的显式:443；受控回调不能携带用户信息、重复ticket或额外目标参数。票据不落盘。

## 恢复和失败

统一认证存union-session:账号。教务存dart-session:账号，其余业务存business-session:业务:账号。业务失效只重建业务；统一认证过期才读取保存密码，多个并发恢复共享一次密码登录。升级先从旧Cookie集合迁移认证域Cookie，再确认有效性。手动登录取消并等待旧查询完成后再替换凭据，退出清当前账号全部学校凭据。

明确credentials_rejected只提交一次，清除已拒绝的保存密码、写入auth-blocked标记。后续查询或重启不会再次提交它，用户手动更新才解除。账号锁定、密码过期和额外验证也立即停止；不推断未知错误是密码错误，不把验证码失败当密码错误，不自动发送学校短信。

## 统一过程状态

自行实现FoundationProgressSource/Hub及SchoolOperationStatus。登录、检查、教务、课表和所有校园查询使用同一状态合同，实际阶段包括恢复本机会话、恢复统一认证、正在登录、验证码验证、学生身份验证、为具体业务建立会话、查询具体资源。每个请求独立编号与Zone上下文；取消／迟到完成不会清除新请求状态，也不会覆盖其他请求阶段。组件显示重试次数、等待秒数与并发数量；没有虚构百分比。不可见页面不运行状态计时器。

## 已验证与边界

- API37 x86_64模拟器，Flutter AOT profile，使用既有加密账号；日志只保留阶段、布尔值及错误码。
- 统一认证SSO恢复、四项service取票通过（未再次读取密码）：verification/unified-identity.json。
- 统一认证与教务同时过期后，保存密码恢复通过；重启复用会话且未再提交密码：unified-expire.json、unified-warm.json。
- 图书馆、第二课堂真实只读查询通过；校车进入业务卡片解析后返回invalid_schedule，该查询不算通过：unified-campus.json。本次不声称校车时刻表已适配，也不以取票成功代替数据正确。
- 合成回归验证错误密码仅一次POST、后续查询／重启不再试、手动更新解除阻止、并发共享恢复、各业务隔离与持久化、取消和账号切换，以及真实阶段显示。未向真实学校故意提交错误密码。
- 发现并修复业务加载完成回调等待自身Future的死锁；unified-business-before.log保留1秒超时的失败证据，统一回归验证修复。
- 验证码识别和时序沿用0.6.1，未把旧30轮统计冒充本版手机成功率。ARM64手机与多日稳定性仍需用户验收。

完整调用、返回、存储和错误码见[接口总册](api.md)，教务／校园分册分别保留原库端点与字段来源。

最终离线回归93项通过，见 verification/unified-all-tests.log；本次修改模块分析No issues found，见unified-owned-analysis.log。全项目分析仍有countdown.dart两项既有提示（多余非空断言和dart:ui导入），本次未改动该模块。
