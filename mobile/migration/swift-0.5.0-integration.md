# 0.5.0 本机教务集成与验证

此版本在 0.4.17 的四栏、课表、文章阅读器和动效基础上接入 WUSTFoundation。上游固定提交为 `f421a1e3d4da364cdf773b1bd54433e2630dd10b`，原始 147 个 Swift 文件保持不变，Android 适配通过 `WUSTFoundation-android/Android/prepare.py` 生成。

## 调用与登录

Flutter 的 `AcademicStore` 经 `wiki/native` MethodChannel 调用 `MobileAcademic`，后者在本机执行 `libWUSTMobileBridge.so`。此程序直接复用原 `WUSTLoginClient` 和业务服务连接学校 HTTPS 接口，无需 Wiki 后端处理这一登录方式的密码、Cookie 或查询。
Swift 调用 Android 图像、OCR、加密及存储时使用带随机令牌的 `127.0.0.1` 通信桥。算式验证码使用内置 ML Kit Latin Text Recognition 16.0.1，本机识别；滑块保留原像素相关性算法。

密码和会话使用应用自己的 Android Keystore AES-GCM 加密，关闭系统备份；APK 和对应源码不包含个人凭据。本机方案首次需在本设备填写学号和统一认证密码。Flutter 偏好设置中的 `local` 只是方案标记，不是学校令牌。

重启先恢复本机保存状态，显示“教务登录已保存”；实际查询前校验学校会话与学号，通过后显示“教务已登录”。有效会话复用，过期后自动使用密码登录。首次失败后最多重试 4 次，间隔 1 秒，累计 5 次失败停止本次流程。取消会终止本机进程。应用不依靠后台常驻或定时保活，下次查询时自动恢复。
网络临时失败保留本机凭据与现有缓存。手动切换账号前清除课表缓存，失败也不显示旧账号数据。退出教务登录清除本账号密码、会话、TGT 和课表缓存。

学校网页与微信入口保留在“登录设置”中，其原有方式继续使用 Wiki `/api/academic` 服务。原先保存的后端会话仍可继续查询；本机账号密码登录成功后切换。Android 7/8 保留旧方式；新本机模块要求 Android 9+。本次构建包含 ARM64 和 x86_64，ARM64 尚未实机验证。

## 入口及呈现

| 功能 | Flutter 路径 | 实现 |
| --- | --- | --- |
| 课表、成绩、绩点 | 原有课表及成绩页面 | 本机接口适配原页面数据结构，保留筛选、重修选择与缓存 |
| 考试安排 | `/study/exams` | 原 ExamService，Flutter 字段卡片 |
| 学分完成 | `/study/credits` | 原 CreditProgressService，类别及课程卡片 |
| 学生信息 | `/study/student` | 原 StudentInfoService，Flutter 卡片；不主动显示身份证号 |
| 教学周 | `/study/calendar` | 原 TeachingCalendarService，周次和日期范围卡片 |
| 个人培养方案 | `/services/training-plan` | 原服务菜单 8 |
| 课表采集 | `/services/captures` | 原服务菜单 4，保留原始采集和系统文件导出 |
| 学校通知 | `/services/notices` | 原通知菜单，保留详情及 PDF 预览 |
| 图书馆 | `/services/library` | 原服务菜单 12 |
| 校车 | `/services/shuttle` | 原服务菜单 13 |
| 第二课堂 | `/services/second-class` | 原服务菜单 14 |
| 洗衣机 | `/services/laundry` | 原胖乖生活菜单，保留设备查询、短信登录和订单查询 |

新增 11 个入口收在首页“更多学业服务”和“校园服务”，原有工具位置保留。复杂交互先直接复用原版菜单，未替换成静态占位。
图书馆、校车和第二课堂仍遵循原库的 TGT 凭据要求；当前新教务登录不产生这些服务所需的 TGT，入口显示该要求，并保留原服务返回状态。本次没有把不可用授权包装为登录成功。

## 验证结果

- Flutter：36 项测试通过，`dart analyze lib test` 无问题。覆盖原界面和动效、原网页登录、本机恢复、密码隐藏、账号切换隔离和考试字段呈现。
- Swift：71 项、10 个测试组通过，包含最多 4 次重试、并发恢复合并、取消、退出、账号隔离和网络错误保留存储。
- Android x86_64 API 37：真实账号身份核验通过；课表、成绩、考试、学分、教学周、学生信息六项本机查询完成。验证输出不含个人字段或凭据。
- 过期恢复：仅将本机保存的会话标记过期，确认实际使用保存密码恢复；随后再次校验确认复用会话，未再调用密码登录。
- 正式界面：核对 `dist/android/WUST-Wiki-0.4.17-preview.apk`；0.5.0 保留四栏，增加服务分组、登录设置及账号密码表单。
- 构建使用项目原有 Flutter 3.41.5、JDK 17、Android SDK 36，原生 Swift 使用 6.4.3 Android SDK。安装包使用开发签名。

尚未进行 ARM64 实体手机、Android 7/8 回退、连续数日运行、图书馆/校车/第二课堂真实授权、胖乖短信与运行中订单验收。学校密码变更、额外验证或服务不可用时可能需要用户处理，失败流程达到上限后停止。

## 构建和源码入口

先配置 Swift 主机工具链、同版本 Android SDK 和 NDK r30，运行 `bash mobile/scripts/build-foundation.sh`。再在 `mobile/` 使用 JDK 17 执行 Flutter 构建：

```sh
flutter pub get
flutter test
dart analyze lib test
flutter build apk --release --target-platform android-arm64,android-x64
flutter build apk --release --target-platform android-arm64,android-x64 --split-per-abi
```

Windows 路径含空格时使用对应短路径运行 Flutter，避免原生资源 hook 的命令行解析问题。若 Android Studio 自动选择 JDK 25，可为当前构建进程设置 `JAVA_HOME` 及 `GRADLE_OPTS=-Dorg.gradle.java.home=<JDK17路径>`；不必修改全局配置。

`lib/academic.dart` 管理方案选择与缓存，`lib/local_academic.dart` 提供登录和新页面，`lib/main.dart` / `native_pages.dart` 管理入口。Java 入口为 `android/app/src/main/java/cn/edu/wust/foundation/MobileAcademic.java`；Swift JSON 接口为 `WUSTFoundation-android/Android/swift/MobileAcademicAPI.swift`。原版交互菜单由共享的 Android Activity 直接复用。

测试程序位于 `mobile/android/app/src/androidTest/`，仅用于私有临时凭据导入、会话过期触发及无敏感输出验证，不将测试 APK 作为用户安装包交付。
