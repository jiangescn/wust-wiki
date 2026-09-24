# WUST Wiki

Docus 文档站基础框架。沿用西邮 Wiki 的分类与路径结构，按维护需求调整条目；移除“校园墙”文章及相关入口后，首页现有 14 个入口。Coder 首页和校友博客页已开始使用用户提供的武科大资料，其余校园正文待补充。

正式 Wiki 域名为 **https://wiki.wustacm.com**，保持静态部署。课表后端为 **https://schedule.wiki.jianges.com**，只提供学校微信扫码 API，不承载另一个网站；接入与维护见 [课表后端说明](docs/schedule-deployment.md)。

课程安排页 `/study/curriculum` 已嵌入学校微信扫码查询，显示当前学期课程、教师、地点、节次、周次与教务备注。入口为 `content/2.study/2.curriculum.md`，查询由 `AcademicSchedule.vue` 装配 `SchoolAcademicQuery.vue`，周课表与日列表复用 `ScheduleBoard.vue`，课表结果在当前浏览器保存七天。页面下方说明仍为待完善草稿，查询结果以教务系统为准。

学业成绩与学分绩点合并为 `/study/grades`“成绩与绩点”，旧 `/study/gpa` 跳转到此页。成绩和课表共用学校扫码会话，登录成功起最多保留 24 小时；学校 Cookie 只留在后端内存，浏览器保存随机会话令牌。成绩结果只在页面内存展示，不写入浏览器持久缓存。前端调用 `/api/academic`，后端版本为 `20260924-1`；源码、接口和验证见 [教务查询说明](docs/academic-query.md)。

成绩展示前端样例：`/study/grades?grades=sample`，入口为 `GradeDisplayPrototype.vue`，通过现有 `GradeQuery.vue` 切换。使用虚构课程，支持学期筛选、搜索、桌面表格/手机卡片、课程详情及绩点分段表；分段表按用户提供截图录入，仅供样例展示。复用 Wiki 外壳及 Nuxt UI 弹窗、按钮，自行实现样例布局；不请求教务接口，不保存演示数据。运行现有 `pnpm dev:login:lan` 即可预览。

真实查询及样例均默认全部学期、最多展示 6 条，可展开其余成绩；切换学期或搜索时恢复折叠。展开按钮及计算器课程选择使用固定 16px SVG 箭头，通过旋转表示展开状态。样例汇总区直接使用 Wiki 主题变量，避免独立深色选择器失效造成浅底浅字。汇总和成绩行采用紧凑间距，仅保留“演示数据”标识。

正式成绩页下方“学分与绩点”已加入 `GradeGpaCalculator.vue`，读取当前查询结果，支持课程勾选、最新重修成绩选择及学分加权计算；结果明确标注仅供参考。计算与去重逻辑在 `app/utils/gpa.ts`，纳入 `pnpm check:academic`。

后续 Agent 开始工作前请阅读 [AGENTS.md](./AGENTS.md)，其中记录复用原则、源码入口、兼容适配、验证方法和未完成事项。

参与内容编写见[贡献指南](content/contributing.md)（站内 `/contributing`）：包含资料反馈、GitHub 网页编辑、校园信息写作、各目录的维护入口及本地预览方法。指南的社区参考与取舍见[研究记录](research/wiki-contribution-guide-2026-09-24.md)。

“写在开头”页 `/overview` 的正文入口为 `content/0.overview.md`，简述资料整理的缘由、内容现状和反馈方式，沿用现有正文排版及两张 LinkCard 入口。正文不复述侧栏目录，不虚构编写者经历；校园 Wiki 的写法参考见 [对照笔记](research/campus-wiki-writing-2026-09-24.md)。

“写在开头”目前临时隐藏：`content.config.ts` 将 `0.overview.md` 排除出文档集合，因此不进入导航、搜索、文章列表和最近更新，原地址暂不生成。正文文件保留；恢复时移除这项排除配置即可。首页“开始阅读”现指向 `/campus`“学校简介”。

“兴趣小组”页 `/study/labs` 通过 `CoderDirectory` 的 `embedded` 模式直接复用“武科大俱乐部”的 `WustLabList`、原版 `LabItem` 和同一份 `app/data/coder/labs.json`。嵌入时隐藏重复的俱乐部标题，保留页面标题、来源说明及卡片翻面，不复制名单。

课表展示样例：`/study/curriculum?schedule=sample`，由 `ScheduleCurriculum.vue` 切换真实查询与 `ScheduleGridPrototype.vue`。正式查询与样例共用 `ScheduleBoard.vue`，自行实现 Vue + CSS Grid 并复用 Nuxt UI 控件与 Wiki 外壳。样例课程明确标注为虚构，不写入课表缓存。支持周次、周表/日列表、课程详情和两校区作息切换；作息来自用户提供图片，仅覆盖第 1–10 节。正式版数据流、七天缓存及验收见 [课表正式版说明](docs/schedule-production.md)。

本科专业页已接入 22 个学院（部）、76 个独立本科专业的原版翻面卡片；招生大类、拔尖班、双学士学位项目等仍在备注表中区分。维护入口及资料核对范围见 [专业卡片说明](./docs/major-mvp-sources.md)。

后续补全专业请遵循 [本科专业列表填写指南](./docs/major-editing-guide.md)。

本科与研究生培养方案按学院整理，公开目录、来源及附件的维护方法见[培养方案页面说明](./docs/curricula-directory.md)。原始采集归档 `docs/curricula/` 仅保留在维护者本地；`build:curricula` 与 `check:curricula` 需要该归档，常规网站构建直接使用已入库的目录与公开附件。

原“学号与学籍”页 `/study/status` 改为“培养方案”，用户已选定平铺版，默认由 `CurriculumDirectory.vue` 按学院分组展示专业卡片，支持培养层次切换、搜索、仅有资料及学院定位。已移除布局切换器与原型命名，旧 `?variant=flat`、`?variant=select` 链接也显示同一平铺页面。直接复用归档文件与元数据，必要适配为静态目录，自行实现平铺布局；卡片圆角 12px、控件圆角 6px，筛选复用 `WikiMotion` 的 160ms 轻淡入（0.85→1），不插值整个目录高度，版本折叠复用全局 220ms 动画及 16px 旋转箭头，并响应减少动态效果偏好。按用户确认保留简化文案，来源元数据仍在归档中保存。PDF 点击查看、DOC 下载。维护和校验见 [培养方案页面说明](./docs/curricula-directory.md)。页面状态为 `published`，公开附件按来源清单发布。

竞赛与证书页 `/study/contest` 已按用户提供的 2024 年文件整理 253 项竞赛，支持搜索、类别、组织单位及面向对象筛选，保留管理办法摘要与原 PDF 页码。来源版本、维护入口及核验方式见 [竞赛目录来源与维护](./docs/competition-catalog-sources.md)。

普通 Markdown 正文与博客示例共享原博客排版、链接、行内代码、代码块和表格渲染；接入入口为 `app/utils/blog-prose.ts` 和 `app/pages/[[lang]]/[...slug].vue`，页面外壳仍沿用 Docus。

普通文档页的侧栏提供“补充与纠正”入口，提示“信息有误或缺漏？欢迎补充。”，链接到本项目 `https://github.com/jiangescn/wust-wiki/issues`。直接复用原博客 `BlogLinkCard`，由 `app/components/docs/DocsArticleAside.vue` 装配；桌面显示在右侧目录下方，侧栏随整页滚动，不设置独立滚动区域，手机显示在正文前。文章已有 `meta-aside-contribute` 时使用其专用入口（例如“补充培养方案”），不重复显示通用卡片。

页面动效：`app/app.vue` 直接使用 Nuxt 页面过渡，全站跳转淡入；自行实现的 `app/components/WikiMotion.vue` 为成绩、绩点、课表、竞赛和美食查询提供 220ms 高度衔接，课表视图切换使用 160ms 淡入。不会为动画重新挂载查询组件，也不延迟请求。原博客、Coder 卡片及 Nuxt UI 弹窗继续复用原动画。原生折叠区在支持 `::details-content` 的浏览器中渐进增强；系统减少动态效果时取消动画。本次变化见站内更新日志。

## 本地开发

需要 Node.js 24 LTS（>=24.11）和 pnpm 11。

```sh
pnpm install --frozen-lockfile
pnpm dev
```

访问终端显示的本地地址。若 Windows 的 npm 缓存目录不可写，可仅为当前 PowerShell 会话设置：

```powershell
$env:npm_config_cache = Join-Path (Get-Location) '.cache/npm'
pnpm install --frozen-lockfile
```

## 检查与构建

```sh
pnpm check:content
pnpm typecheck
pnpm generate
```

静态产物位于 `.output/public/`，可部署到支持静态网站的服务器。正式构建前设置 `NUXT_SITE_URL` 为实际域名；未设置时仅作本地预览。部署平台需支持目录下 `index.html`、提供 `404.html`，保留 `_nuxt/` 和内容数据库资源。新增页面后重新构建。

运行 `pnpm preview:static` 可检查静态产物，默认地址 `http://127.0.0.1:4173`。若端口占用，在当前终端设置 `PORT` 为其他端口即可。此预览服务只绑定本机，不用于生产部署。

`pnpm build` 用于需要 Node 服务端的部署；本项目默认采用静态部署，不需要在线数据库或账号系统。

## 修改位置

课表扫码登录的本地实验模板：运行 `pnpm dev:login`（本机）或 `pnpm dev:login:lan`（局域网），访问终端地址的 `/previews/schedule-login`。包含学习通、学校微信、武科大助手三个分支，默认不启用服务端认证接口、不进入公开导航。三种方式已由用户确认可登录；学校分支已接入当前学期课表读取与备注解析；实现和验证边界见 [登录模板说明](docs/schedule-login-templates.md)。

组件维护原则：优先直接复用原项目组件及依赖，只做必要的框架接口与主题适配；避免重写已有功能。原博客组件示例在 `/blog-components`，原始文件和集成说明见 `vendor/blog-v3/`。

| 路径 | 用途 |
| --- | --- |
| `app/data/wiki.ts` | 首页入口、顶部分类菜单 |
| `app/pages/index.vue` | 首页、最近更新 |
| `app/pages/articles.vue` | 全部文章 |
| `content/` | Markdown 正文和侧栏分类 |
| `app/components/content/` | 可在 Markdown 中调用的正文组件 |
| `app/clarity/` | 原博客全部组件及依赖的运行副本 |
| `content/blog-components.md` | 原博客完整示例文档 |
| `app/pages/blog-components.vue` | 原示例的渲染映射、侧栏与许可插槽 |
| `app/data/interest-groups.ts` | 武科大兴趣群卡片数据（群名、方向、群号与分组） |
| `app/components/content/GroupDirectory.vue` | 兴趣群卡片网格与群号复制装配 |
| `app/app.css` | 页面与组件样式 |
| `app/app.config.ts` | 中文界面、品牌、搜索与目录配置 |
| `nuxt.config.ts` | 框架和构建配置 |
| `templates/article.md` | 新条目模板 |

目录/文件的数字前缀只用于排序，例如 `content/1.campus/3.accommodation.md` 对应 `/campus/accommodation`。

## 内容状态

首页“最近更新”直接复用文档集合，显示带实际 `updated` 日期的 5 篇已发布页面，按日期降序、同日按路径升序排列；更新日志不占条目，通过区块右侧“完整更新日志”进入。`content/navigation.md` 为独立 Vue 导航页提供搜索、文章列表及最近更新元数据，页面仍由 `app/pages/navigation.vue` 渲染，且不重复出现在文档侧栏。

- `status: draft`：待补充条目，页面仍能打开，并可被搜索，全部文章中标记为“待补充”。
- `status: published`：已发布；只有同时填写 `updated: 'YYYY-MM-DD'` 才会进入首页最近更新。
- `updated` 表示内容更新日期，不代表校园信息已经核实。适用校区、时间、来源写在正文。
- 页面标题和描述由 frontmatter 提供，不要重复写一级标题。

访问 `/blog-components` 或 `/previews/example` 查看原博客完整组件示例；`/components` 保留此前三个适配组件的示例。原组件使用 `Blog` 前缀注册，例如 `::blog-pic`，详细使用方式与必要适配见 `vendor/blog-v3/README.md`。

`/life/groups` 通过 `::group-directory` 渲染武科大兴趣群卡片，数据维护入口为 `app/data/interest-groups.ts`。卡片直接复用迁入的 BlurCard、Link 与 QQ 群头像工具；群号点击后复制。名单是用户提供的静态汇总，不代表学校官方认证，也不会在线同步。

## 待配置

美食页 `/life/food` 已加入「吃在武科」店铺目录、店内菜单、口碑榜和公开评价；默认南苑，先选店铺再加载菜单。源码入口 `app/components/content/FoodDirectory.vue`。复用现有 Wiki 外壳和 Nuxt UI 组件。开发与本地静态预览自带只读接口代理；**纯静态托管需另配同源转发，不能只上传静态文件就宣称接入完成**。详见 [美食页面接入](docs/food-integration.md)。

- 正式构建设置 `NUXT_SITE_URL=https://wiki.wustacm.com`。课表 API 默认指向 `https://schedule.wiki.jianges.com`，可用 `NUXT_PUBLIC_SCHEDULE_API_BASE` 覆盖；静态页面配置变更后需重新生成。
- 项目 GitHub 地址：`app/app.config.ts` 中将 `github: false` 改为实际仓库信息，再启用源文件编辑入口。当前不使用虚构仓库链接。
- 首页“武科大导航”指向 `/navigation`：参考 CO 导航的双列分组与紧凑链接结构，使用现有 Wiki 的外壳、字体、主题色和卡片风格。共 78 个入口，均配有本地打包的 Lucide 图标，支持名称、用途与网址搜索。“发现更多”现有 8 组、52 项，覆盖 Wiki 查询、在线学习、考试升学、编程开发、AI 助手、在线工具、设计写作和软件下载；在线学习共 6 项，包含“你缺失的那门计算机课”。页面入口为 `app/pages/navigation.vue`，数据在 `app/data/navigation.ts` 与 `navigation-extra.ts`；[来源与访问边界](docs/navigation-sources.md)、[发现更多扩充来源](docs/navigation-discovery-sources.md)、[原版来源与适配](vendor/xupt-nav/README.md)。导航链接不代表外部系统登录已经验证。
- 所有 WUST 校园信息、联系人和外部办事入口须由维护者填写。
- 沁湖宿舍查询嵌入：部署沁湖站点时在其 `.env` 设置 `EMBED_ALLOWED_ORIGINS=https://wiki.wustacm.com`；Wiki 默认使用 `https://dorm.wustacm.com/embed`，如需测试或迁移可通过 `NUXT_PUBLIC_DORMITORY_EMBED_URL` 覆盖。Wiki 组件仅经 iframe 桥接传递区域、寝室号和最终允许公开的结果，不直接调用 `/api/query`，也不接触 GeeTest 验证字段。

## Coder 目录

`/coder/` 和 `/coder/blog` 继续复用西邮原版 LabItem、BlogCard 及 BlurCard 等依赖，运行源码在 `app/xupt/`。`CoderDirectory.vue` 负责按页面选择装配：`/coder/` 由 `WustLabList.vue` 读取 `app/data/coder/labs.json`，`/coder/blog` 由 `WustBlogList.vue` 读取 `app/data/coder/blog.json`；两者均为用户提供的武科大首批条目。也可通过 Markdown 中的 `::coder-directory{kind="labs"}` / `::coder-directory{kind="blogs"}` 调用。来源、适配和校验方法见 [迁移说明](./vendor/xupt-wiki/README.md)。

武科大条目沿用原版悬停 3D 翻面、QQ 群头像和群号复制；按录入顺序展示，不随机排序。武科大博客沿用头像/访问箭头/标签/链接淡入淡出与原版 TransitionGroup 排序动画，`?shuffle=false` 可固定初始顺序；`avatar` 优先使用博主指定头像，否则使用主页声明的站点图标。Chord 按 [Issue #1](https://github.com/jiangescn/wust-wiki/issues/1) 中博主提供的链接使用 `https://blog.songline-blog.com/uploads/songline/qiandai.jpg`。目录数据是本地静态快照，不代表已接入在线同步。`pnpm check:xupt` 校验迁移源码与原样动画样式。

可维护字段：武科大条目 `id/name/tags/belong/addr/qq/github/website/plan`；博客 `author/title/avatar/grade/belong/tags/link/feed/github/qq`。`tags` 为逗号分隔字符串；无值字段保持空字符串；新增条目 id、群号及博客 link 必须唯一。群图片由 `qq` 自动生成 QQ 群头像；博客 `avatar` 应从对应主页的 icon 声明或实际图片取得，官网和博客地址必须填写完整 URL。

`/coder` 页面名称为“武科大俱乐部”，当前收录用户提供的 21 项组织资料。2026-09-22 新增虚拟现实俱乐部、知行思政、排球协会、短视频中心、美育中心、合唱团、台球协会、广播站、音乐与吉他协会、coding 俱乐部、“向日葵计划”志愿服务队和羽毛球；名称、群号按用户提供内容录入，主题标签从组织名称提取，未提供的所属单位、地址等留空，不保留聊天发言者和时间戳。“社团与爱好”侧栏入口通过其 frontmatter 的 `navigation.to` 指向 `/coder`，旧地址 `/study/clubs` 由 `app/pages/study/clubs.vue` 跳转，兼容站内跳转及静态直接访问。

## 来源

框架为 Docus 5.13.0 / Nuxt 4.5.2 / Nuxt Content 3.15.2；依赖版本和 lockfile 已固定。
栏目参考西邮 Wiki；完整组件示例及依赖来自 blog-v3，并保留此前三个适配组件。详见 `THIRD_PARTY_NOTICES.md` 和 `licenses/`。

`patches/docus@5.13.0.patch` 修复该版缺失的 TypeScript 入口、SEO 类型与无多语言模块时的类型声明，安装时由 pnpm 自动应用。`pnpm-workspace.yaml` 将 Nuxt Content 统一到同一版本，避免组件与内容集合使用不同的类型实例。升级 Docus 时应复核并移除已被上游修复的补丁。
