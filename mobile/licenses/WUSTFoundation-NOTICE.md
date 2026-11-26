# 第三方来源

0.6.0 的 Flutter APK 已移除 Swift、SwiftSoup 和 Swift Android 运行库。下表保留历史 0.5.0 及源代码快照的来源以便追溯；现行业务以 Dart 移植，仍遵循 WUSTFoundation AGPL-3.0。ML Kit 继续随 APK 提供。Flutter 构建以 mobile/android/app/build.gradle.kts 为准（Gradle 8.14）；原快照 Android/app/build.gradle 属于参考工程。

| 组件 | 版本或提交 | 来源 | 许可 |
| --- | --- | --- | --- |
| WUSTFoundation | f421a1e3d4da364cdf773b1bd54433e2630dd10b | https://github.com/xiaoka520/WUSTFoundation | GNU AGPL 3.0，根目录 LICENSE |
| SwiftSoup | 2.14.3 / e7f85f4d3dd91ca9a1e94d3328aa1ed5120a8c0f | https://github.com/scinfu/SwiftSoup | MIT，SwiftSoup-LICENSE.txt |
| Swift / Foundation / Dispatch / ICU runtime | 6.4.3 Android SDK | https://www.swift.org/ | Apache 2.0 及运行库例外，Swift-LICENSE.txt，SDK-SBOM.spdx.json |
| Android NDK libc++ runtime | r30 | https://developer.android.com/ndk | Apache 2.0 及 LLVM 例外，NDK-NOTICE.txt |
| ML Kit Latin Text Recognition | 16.0.1 | https://developers.google.com/ml-kit/vision/text-recognition/v2/android | Google ML Kit 条款 https://developers.google.com/ml-kit/terms |
| Gradle Wrapper | 9.3.1 | https://github.com/gradle/gradle | Apache 2.0 |

Maven 依赖由 `app/build.gradle` 固定入口版本，通过 Gradle 获取。
Swift SDK 软件物料清单随源码交付，用于追溯 SDK 内第三方组件。
