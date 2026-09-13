# WUST Wiki

Docus 文档站基础框架。保留西邮 Wiki 的分类、首页 15 个入口与原有路径结构；Coder 目录使用标注来源的西邮参考数据，其余校园正文待补充。

后续 Agent 开始工作前请阅读 [AGENTS.md](./AGENTS.md)，其中记录复用原则、源码入口、兼容适配、验证方法和未完成事项。

本科专业页已接入 22 个学院（部）、76 个独立本科专业的原版翻面卡片；招生大类、拔尖班、双学士学位项目等仍在备注表中区分。维护入口及资料核对范围见 [专业卡片说明](./docs/major-mvp-sources.md)。

后续补全专业请遵循 [本科专业列表填写指南](./docs/major-editing-guide.md)。

普通 Markdown 正文与博客示例共享原博客排版、链接、行内代码、代码块和表格渲染；接入入口为 `app/utils/blog-prose.ts` 和 `app/pages/[[lang]]/[...slug].vue`，页面外壳仍沿用 Docus。

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
| `app/app.css` | 页面与组件样式 |
| `app/app.config.ts` | 中文界面、品牌、搜索与目录配置 |
| `nuxt.config.ts` | 框架和构建配置 |
| `templates/article.md` | 新条目模板 |

目录/文件的数字前缀只用于排序，例如 `content/1.campus/3.accommodation.md` 对应 `/campus/accommodation`。

## 内容状态

- `status: draft`：待补充条目，页面仍能打开，并可被搜索，全部文章中标记为“待补充”。
- `status: published`：已发布；只有同时填写 `updated: 'YYYY-MM-DD'` 才会进入首页最近更新。
- `updated` 表示内容更新日期，不代表校园信息已经核实。适用校区、时间、来源写在正文。
- 页面标题和描述由 frontmatter 提供，不要重复写一级标题。

访问 `/blog-components` 或 `/previews/example` 查看原博客完整组件示例；`/components` 保留此前三个适配组件的示例。原组件使用 `Blog` 前缀注册，例如 `::blog-pic`，详细使用方式与必要适配见 `vendor/blog-v3/README.md`。

## 待配置

- 正式域名：`NUXT_SITE_URL`。
- 项目 GitHub 地址：`app/app.config.ts` 中将 `github: false` 改为实际仓库信息，再启用源文件编辑入口。当前不使用虚构仓库链接。
- 首页保留了参考站的 `CO 导航` 外链，它属于西邮项目；如需 WUST 专属导航，修改首页按钮地址。
- 所有 WUST 校园信息、联系人和外部办事入口须由维护者填写。
- 沁湖宿舍查询嵌入：部署沁湖站点时在其 `.env` 设置 `EMBED_ALLOWED_ORIGINS=https://wiki.wustacm.com`；Wiki 默认使用 `https://dorm.wustacm.com/embed`，如需测试或迁移可通过 `NUXT_PUBLIC_DORMITORY_EMBED_URL` 覆盖。Wiki 组件仅经 iframe 桥接传递区域、寝室号和最终允许公开的结果，不直接调用 `/api/query`，也不接触 GeeTest 验证字段。

## Coder 目录

`/coder/` 和 `/coder/blog` 已迁入西邮原版 LabList/LabItem、BlogList/BlogCard 及 BlurCard 等依赖，运行源码在 `app/xupt/`。`CoderDirectory.vue` 仅负责装配，也可通过 Markdown 中的 `::coder-directory{kind="labs"}` / `::coder-directory{kind="blogs"}` 调用。数据仍在 `app/data/coder/labs.json` 和 `app/data/coder/blog.json`，保留并标注西邮参考名单，不代表 WUST 信息。来源、适配和校验方法见 [迁移说明](./vendor/xupt-wiki/README.md)。

实验室沿用原版悬停 3D 翻面，博客沿用头像/访问箭头/标签/链接淡入淡出；两页使用原版 TransitionGroup 排序动画。频道二维码浮层、群号及 RSS 复制也使用原版。仅博客的 `?shuffle=false` 可固定初始顺序；头像和剪贴板失败行为同上游，旧版本的文字占位与状态栏已移除。目录数据是静态快照，原始信息表链接不代表已接入在线同步。`pnpm check:xupt` 校验迁移源码与原样动画样式。

可维护字段：实验室 `id/name/tags/belong/addr/qq/github/website/plan`；博客 `author/title/grade/belong/tags/link/feed/github`。`tags` 为逗号分隔字符串；无值字段保持空字符串；新增实验室 id、博客 link 必须唯一。西邮相对培养计划链接由 `app/utils/coder.ts` 补全原站域名。替换为 WUST 内容时应改用真实链接。

## 来源

框架为 Docus 5.13.0 / Nuxt 4.5.2 / Nuxt Content 3.15.2；依赖版本和 lockfile 已固定。
栏目参考西邮 Wiki；完整组件示例及依赖来自 blog-v3，并保留此前三个适配组件。详见 `THIRD_PARTY_NOTICES.md` 和 `licenses/`。

`patches/docus@5.13.0.patch` 修复该版缺失的 TypeScript 入口、SEO 类型与无多语言模块时的类型声明，安装时由 pnpm 自动应用。`pnpm-workspace.yaml` 将 Nuxt Content 统一到同一版本，避免组件与内容集合使用不同的类型实例。升级 Docus 时应复核并移除已被上游修复的补丁。
