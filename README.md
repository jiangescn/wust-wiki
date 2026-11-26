# WUST Wiki

武汉科技大学非官方校园生活指南，包含 **Web 静态站点**（基于 Docus / Nuxt）与配套 **Android 客户端**（基于 Flutter）。

## 项目简介

本项目面向武汉科技大学在校生及新生，提供持续维护的校园信息与常用工具：

- **校园与生活指南**：入学办理、住宿生活、防骗指南、快递外卖、美食与周边地图等。
- **学习与社团目录**：课程与培养方案索引、成绩与绩点说明、竞赛证书、武科大导航、校园俱乐部与校友博客。
- **Android 客户端**：在手机端集成课表、成绩与绩点、考试倒计时、校内常用服务以及离线 Wiki 阅读。

## 环境要求

- **Web 站点**：Node.js `>=24.11.0 <25`、pnpm `11.20.0`
- **Android 客户端**（仅构建 APK 时需要）：Flutter `3.41.5`、Android SDK 36、NDK `28.2.13676358`、JDK 17、Python 3

## 快速开始（Web）

1. 克隆仓库并安装依赖：

```bash
git clone git@github.com:jiangescn/wust-wiki.git
cd wust-wiki
pnpm install --frozen-lockfile
```

2. 启动本地开发服务：

```bash
pnpm dev
```

启动后访问终端输出的地址即可实时预览。

### 常用命令

| 命令 | 说明 |
| --- | --- |
| `pnpm dev` | 启动本地开发服务器（支持热更新） |
| `pnpm generate` | 生成静态站点到 `.output/public/` |
| `pnpm preview:static` | 本地预览静态生成产物（可通过环境变量 `PORT` 指定端口） |
| `pnpm check:content` | 检查 Markdown 文档与站内链接 |
| `pnpm typecheck` | 运行 TypeScript 类型检查 |

## 参与编辑与贡献

欢迎补充资料、修正过期信息或新增条目：

- **提交反馈 / 提供资料**：直接在 [GitHub Issues](https://github.com/jiangescn/wust-wiki/issues/new) 说明对应页面、补充内容与信息来源。
- **直接修改文章**：编辑 `content/` 下对应的 Markdown 文件并提交 Pull Request（目录与文件名的数字前缀仅用于排序，不进入 URL）。
- **修改目录数据**：专业列表、武科大导航、俱乐部、校友博客、兴趣群等结构化数据位于 `app/data/`。

详细的写作规范、元数据格式与提交流程请参考 [贡献指南](./content/contributing.md)。

## 构建 Android 客户端

需先在仓库根目录生成静态内容与移动端资源，再使用 Flutter 构建 APK：

```bash
# 1. 在仓库根目录生成站点与移动端资源
pnpm install --frozen-lockfile
pnpm generate
node mobile/scripts/build-native-data.mjs
node mobile/scripts/build-tools.mjs
python mobile/scripts/build-reader.py

# 2. 进入 mobile 目录构建安装包
cd mobile
flutter pub get
flutter test
flutter build apk --release
```

更多移动端功能与发版说明见 [mobile/README.md](./mobile/README.md)。

## 目录概览

```text
├── content/    # Wiki 文章（Markdown）
├── app/        # 网站页面、组件与结构化数据
├── mobile/     # Flutter Android 客户端
├── public/     # 静态资源
└── docs/       # 维护说明与参考记录
```

## 致谢与许可

- 本项目参考或复用了 [西邮 Wiki](https://wiki.cooo.site/)、[blog-v3](https://github.com/L33Z22L11/blog-v3)、[xupt-nav](https://github.com/xupt-wiki/xupt-nav)、[Docus](https://github.com/nuxt-content/docus) 与 [WUSTFoundation](https://github.com/xiaoka520/WUSTFoundation) 等开源项目。
- 各模块的详细来源与许可证（含导航模块 GPL-3.0、移动端教务模块 AGPL-3.0 及文章/字体说明）请查阅 [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)。
