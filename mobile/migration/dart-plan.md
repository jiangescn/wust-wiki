# Dart 业务迁移工作流

目标：保留 0.5.0 的四栏和全部服务入口，把 Swift 业务迁至 Dart；Android 仅承担图像/OCR、加密安全存储、文件/PDF及系统视图。成功后 APK 中不含 Swift 可执行程序、Swift/Foundation/ICU 运行库，也不通过子进程处理业务。

基线：`dist/android/WUST-Wiki-0.5.0-source.zip` 及对应三个 APK，36 项 Flutter、71 项 Swift 回归。保留旧产物，不修改站点线上服务。原网页/微信登录保留；账号密码直接连接学校，原先的 TGT 要求不弱化。

## 验收谓词

1. 认证：业务入口预热、严格重定向、响应 Cookie、学号一致性校验；有效会话复用，过期密码恢复，首次失败后最多重试四次，取消立即停止，账号隔离及退出清理。
2. 原有加密存储继续可读取；旧版 Swift 日期格式的会话可迁移。密码、令牌及个人结果不写入测试输出或交付包。
3. 课表、成绩、考试、学分、学生信息、教学周，以及培养方案、采集导出、通知/PDF、图书馆、校车、第二课堂、洗衣机/SMS/订单都有对应 Dart 实现和入口。
4. 原有 Flutter 回归、移植的解析/协议测试通过；真实账号的前六项只读查询、过期恢复在 APK 中验证，未取得授权的服务明确列为未验证。
5. 安装包架构和动态依赖检查确认无 Swift；源码、许可、版本、验证说明和交付校验值对应。
6. 完整接口文档随源码交付：业务 resource/options、返回模型、状态和错误码、鉴权/TGT、重试/取消、安卓能力与文件交互、旧存储迁移、可运行的脱敏示例；用测试防止文档中的接口名与实际分发不一致。

## 阶段与分工

- 主线：Dart HTTP/Cookie/取消和会话协调器，Android 能力插件，界面及打包接入。
- 隔离工作树 A：教务解析和查询、培养方案及原始采集；新增 academic 模块及合成测试，不修改主线文件。
- 隔离工作树 B：通知、图书馆、校车、第二课堂、洗衣机及短信/订单；新增 campus 模块及合成测试，不修改主线文件。
- 合并：先核对返回结构与原库证据，再运行组合测试。所有调用方改用 Dart 后删除 Swift 启动和打包路径。
- 收尾：真实安装包验证、独立审查决策记录、输出 APK 与完整对应源码。默认只本地构建，不推送或部署。

## 模块合同

`transport.dart`：`SchoolTransport.send(Uri uri, {String method='GET', Map<String,String>? form, Object? jsonBody, Map<String,String> headers=const{}, bool followRedirects=true}) -> Future<SchoolResponse>`；响应含 `int status`、`Uri uri`、`Uint8List bytes`、`String text`、`Object? json`、`Map<String,String> headers`（小写键，含 Location/Date）。`FoundationException(code,message,{status})` 表示边界错误。

`platform.dart`：`FoundationPlatform.invoke(String operation,[Map<String,dynamic> arguments=const{}]) -> Future<Map<String,dynamic>>`，`load(String key)`、`save(String key,String value)`、`clear(String key)` 提供加密存储，原 crypto/ocr/raster 参数仍为 Base64 数据。

`academic_queries.dart`：`AcademicQueries(SchoolTransport http).query(String resource,{Map<String,dynamic> options=const{}})`。
`campus_services.dart`：`CampusServices(SchoolTransport http,FoundationPlatform platform,{Future<String?> Function()? credential}).query(String resource,{Map<String,dynamic> options=const{}})`。

结果为 JSON 对象。现有 schedule/grades 字段保持不变；通用结果使用 `rows:[{title,fields:[{name,value}],action?:{resource,options}}]`。交互查询可返回 `controls:[{key,label,type:'text'|'select',value,options:[{value,label}]}]`、`actions:[{label,resource,options}]`；文件使用 `files:[{name,mime,base64}]`。缺少授权抛出 `FoundationException('tgt_required',...)`，教务会话失效使用 `authentication_required`，不伪造空记录或授权成功。
