# 0.6.3 统一认证与业务会话集成

本版维护新版authserver统一认证SSO，再为教务、图书馆、门户校车和第二课堂建立独立业务会话。业务有效时直接复用；业务失效优先使用SSO签发ST，统一认证过期才读取本机加密密码。原网页／微信入口仍保留并使用已有Wiki后端。胖乖独立登录，短信需用户显式确认。

账号或密码被学校明确拒绝时立即停止，不进入剩余重试，提示检查并修改密码；清除已拒绝的保存密码，并阻止后续自动重复提交，用户手动更新后解除。临时网络／验证码失败最多首次加四次，总计五次。未知错误不推断为密码错误。

登录、教务、课表和校园服务共用实际过程状态：恢复会话、正在登录、正在验证、为具体业务建立会话、查询具体服务，附重试次数、已等待时间及并发数。没有模拟进度百分比。

## 源码与完整接口

- lib/foundation/auth.dart、auth_response.dart：统一认证、受控ST回调、业务恢复、密码错误停止与升级迁移。
- lib/foundation/client.dart、progress.dart：业务分发、请求生命周期和实际阶段。
- lib/school_operation_status.dart：统一状态组件；四栏、课表、登录和服务页接入。
- android/app/src/main/java/com/wustacm/wiki/NativeCapabilities.java：沿用Keystore格式并清理全部分层键。
- [完整接口](migration/api.md)、[教务分册](migration/academic-port.md)、[校园分册](migration/campus-port.md)、[本版方案与证据](migration/unified-0.6.3.md)。

业务仍为Dart，Android Java只提供系统能力。原WUSTFoundation提交f421a1e3d4da364cdf773b1bd54433e2630dd10b的147个Swift源码保留用于追溯与AGPL许可交付，不加入APK运行时。四栏及原有Wiki入口保留。此前[0.6.1记录](migration/dart-0.6.1-integration.md)仅为历史证据。

## 实测与未验证边界

API37 x86_64 AOT验证：四项业务SSO取票、保存密码恢复、重启会话复用、图书馆和第二课堂只读查询通过。校车已进入业务数据解析但返回invalid_schedule，不能算查询验收通过；手机和连续多日使用尚待用户验收。真实错误密码不做试错，由合成协议验证一次拒绝即停止及持久化阻止。

验证文件只含阶段、布尔值、稳定错误码及合成数据，不含账号、密码、Cookie或ST值。unified-identity.json区分取票，unified-campus.json区分实际查询，unified-expire.json与unified-warm.json区分重新提交密码和复用。

## 构建和交付

Flutter3.41.5、JDK17、Android SDK36／NDK28.2.13676358；业务不需要Swift工具链。Windows带空格路径使用短路径SDK，设置进程级JAVA_HOME与GRADLE_OPTS指向JDK17，并用org.gradle.daemon=false串行构建。

```sh
dart analyze lib test
flutter test --no-pub
flutter build apk --release --no-pub --target-platform android-arm64,android-x64
flutter build apk --release --no-pub --target-platform android-arm64,android-x64 --split-per-abi
python scripts/verify-apk.py build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/app/outputs/flutter-apk/app-x86_64-release.apk
python scripts/package-android.py
```

正式构建使用lib/main.dart，专用验收入口不分发。包名com.wustacm.wiki、旧开发签名和Keystore格式继续保留，支持覆盖升级。dist/android保留旧包，交付三种APK、完整对应源码、全部接口文档、验证记录与SHA-256。不得静态重新生成站点覆盖dist目录联接中的交付物。

最终离线回归93项通过，见 verification/unified-all-tests.log；本次修改模块分析No issues found，见unified-owned-analysis.log。全项目分析仍有countdown.dart两项既有提示（多余非空断言和dart:ui导入），本次未改动该模块。

三份实际APK检查均无Swift载荷与旧业务桥，见unified-apk-inventory.jsonl；ARM64 v2签名校验通过，证书与旧版一致（SHA-256 4e866559b7b9b7228dc47582be5aebc1146667a6ac02bf80bbb0900d8c635a84）。通用107440894字节、ARM64 60043080字节、x86_64 60444956字节。

最终x86_64 release覆盖升级、四栏、正常入口、分层登录文案通过，真实查询中间帧观察到“正在查询成绩”；快速请求在闲置UI转储前已完成，因此另以短暂原生帧观察确认。临时截图不加入源码或交付，仅保存固定标签与布尔结果，见unified-release-ui.json。

0.6.3 ARM64已通过Tailscale发送到测试手机，CLI返回sent且退出0；手机安装和实际效果尚未确认。记录见verification/taildrop.json。

版本核对：最终APK manifest为versionName=0.6.3，ARM64 versionCode=2028（基础构建28）。早先发送的0.6.2文件名是同一APK的错误标签，SHA-256与正式0.6.3相同；以0.6.3命名的交付物为准。源码pubspec为0.6.3+28，无需修改或重建相同二进制。
