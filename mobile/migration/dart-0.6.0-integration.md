# 0.6.0 Dart 业务集成与验证

本版保留现有首页、课表、校园、个人四栏和文章／动效，把原 WUSTFoundation 认证、教务、校园及洗衣业务移至 Dart。Java 仅提供 Android Keystore、AES／RSA／MD5、图像、ML Kit、文件／PDF、WebView 与外部应用能力。Flutter 构建不再依赖 Swift 工具链，不启动 Swift 子进程。

上游固定提交 `f421a1e3d4da364cdf773b1bd54433e2630dd10b`；`WUSTFoundation-android/Sources/` 原始快照保留供追溯和许可交付，不加入当前 APK。历史 [0.5.0 集成记录](migration/swift-0.5.0-integration.md) 描述旧运行方式。

## 登录和使用

账号密码入口直接连接学校，密码和会话仍采用原 Android Keystore AES-GCM 格式，旧保存账号可继续读取。先验证会话与学号，有效则复用；失效后读取保存密码。首次失败后最多重试四次，总计五次，间隔一秒；并发恢复共享流程，取消中断网络和等待。学校会话期限由学校决定，下次查询时恢复，不依赖后台常驻。退出清当前学校账号凭据和可见课表；网络失败保留凭据。

原学校网页／微信入口仍保留并使用原 Wiki 后端。图书馆、校车、第二课堂需要 TGT，当前教务 CAS 不生成 TGT，缺少时明确提示。胖乖独立登录，短信需用户显式确认。没有对未获授权的服务伪造成功。

## 入口与实现

| 入口 | Dart resource |
| --- | --- |
| 原课表、成绩与绩点 | schedule、grades |
| /study/exams、/study/credits | exams、credits |
| /study/student、/study/calendar | student、calendar |
| /services/training-plan、/services/captures | training-plan、raw-schedule |
| /services/notices | notices、notice-detail、notice-file |
| /services/library | library 及其七个细分资源 |
| /services/shuttle、/services/second-class | shuttle、second-class |
| /services/laundry | laundry 及其六个细分资源 |

新服务页使用 Flutter 的原有 BlogPanel 与表单／字段卡片，支持来源与学期选择、目录、分页、全文、行和顶层动作、密码／验证码隐藏输入、系统文件保存和 PDF 预览。原有四栏及课表布局保留。原 Swift 演示控制台菜单已替换为服务表单。

## 接口与源码

完整合同由 [接口总册](migration/api.md)、[教务分册](migration/academic-port.md)、[校园与洗衣分册](migration/campus-port.md) 组成。总册覆盖二十八个 resource、认证状态、重试／取消、存储迁移和 Android 通道；分册逐项列 options、返回、动作、错误与原学校端点。`test/foundation/api_docs_test.dart` 核对资源索引。

- `lib/foundation/`：Dart 认证、Cookie／HTTP、滑块、教务、校园／洗衣服务。
- `lib/academic.dart`：现有应用状态、缓存和保留的后端入口；`lib/local_academic.dart`：登录表单。
- `lib/foundation_service_page.dart`：服务控件、动作、文件和错误呈现。
- `android/app/src/main/java/com/wustacm/wiki/`：Android 能力、PDF 和平台视图。
- `migration/decisions.tsv`：按证据记录的迁移决策；`verification/`：脱敏验证产物。

## 已验证

- Dart analysis 无问题；完整 Flutter 回归七十项通过，含十七项服务控件／动作／短信确认／文件回调测试。
- 教务解析二十组合成断言、请求十二组合成断言通过；校园七十八解析断言、八十四请求断言通过。
- 新 APK 在 API 37 x86_64 模拟器安装成功；真实学校登录学号一致性通过，确认使用保存密码恢复，随后重启复用会话且未再次用密码。
- 主动过期后的自动密码恢复、重启后不重新提交密码的会话复用，以及六项基础教务查询通过，证据见 verification/real-auth-*.json 与 real-queries.json。
- 学校当前 Word 版培养方案已兼容，原始课表采集和公开通知真实只读查询通过，见 verification/real-additional.json。
- Android 系统 MD5/GB18030、SAF 用户取消、保存字节一致、PDF 打开及返回通过，见 verification/android-system.json 和两张 synthetic 截图。合成夹具不含个人内容。
- 通用／ARM64／x86_64 正式 APK 全部成功，实际包的 native inventory 与 DEX 检查确认无 Swift/WUSTFoundation 运行库及旧业务桥，见 verification/apk-inventory.jsonl。ARM64 签名校验通过，证书与0.5.0一致。
- 最终 x86_64 release 已覆盖安装，原四栏、正式入口、课表同步与学校登录验证通过；未开放调试夹具入口，见 verification/release-ui.json。

## 未验证边界

图书馆／校车／第二课堂真实 TGT、胖乖短信及运行订单、ARM64 实体手机、连续多日使用尚未验收。学校滑块曾返回业务码零，独立与带教务 service 的验证码随后均可成功；保存完整阶段记录，不把单次成功当长期稳定保证。

## 构建

Flutter 3.41.5、JDK17、Android SDK36／NDK28.2.13676358。无需 Swift SDK。Windows 带空格路径使用短路径 Flutter SDK，进程可设置 JAVA_HOME 和 GRADLE_OPTS 指向 JDK17，不改全局设置。

```sh
flutter pub get
dart analyze lib test
flutter test
flutter build apk --release --target-platform android-arm64,android-x64
flutter build apk --release --target-platform android-arm64,android-x64 --split-per-abi
python scripts/verify-apk.py build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/app/outputs/flutter-apk/app-x86_64-release.apk
```

调试阶段入口仅 kDebugMode 与 Android debuggable 同时成立时启用，记录只含阶段与布尔值／学校业务数字码。正式 release 不开放该入口。APK 使用现有开发签名，包名仍为 com.wustacm.wiki，保持原数据升级兼容。组合移动端按 AGPL-3.0 提供完整对应源码，其他文章和组件保留原许可。

正式包体积：通用106696034字节，ARM64 59669624字节，x86_64 60072068字节。各包SHA-256见交付目录校验清单。Windows曾遇R8 classes.dex占用；仅关闭本项目已确认空闲的旧Gradle守护进程，并以 org.gradle.daemon=false 串行构建后通过。
