# 后续 Agent 工作指引

适用范围：本项目全目录。交接基线：2026-09-13。此文件记录项目约定；用户后续明确指令优先。修改前核对当前文件，不把交接记录当作实时检查结果。

## 1. 用户意图与实现原则

- 项目是 WUST（武汉科技大学）校园 Wiki，当前工作以参考站移植、组件拼接和必要适配为主。
- 优先找到原项目实现，复用组件、依赖、样式和数据结构。不要为已有功能重新写一个近似版本；确实无法兼容时，说明原因，把改动限制在接口边界。
- 保持简洁，搭建框架与入口即可，不添加大量口号、重复介绍或虚构的校园正文。
- 保留现有参考站分类、首页 15 个入口、CO 导航及页面路径，除非用户明确要求更换。参考站实际是**西邮 Wiki**，不要混写为西电。
- 西邮实验室、博客等参考名单不等于 WUST 信息；保留来源标记，不擅自改成“武科大名单”。未知联系人、地址、群号、域名、仓库等不猜测。
- 默认完成本地开发与验证。本轮对话没有提供发布、推送或部署授权，不把实现请求自动扩展为上线。
- 用中文沟通；交付时说明实际改动、源码入口、预览地址、已验证与未验证事项。

## 2. 先读哪些文件

1. `README.md`：运行方法、路由、内容状态和维护入口。
2. `vendor/blog-v3/README.md`：完整博客组件迁移说明、适配点和验证边界。
3. `vendor/blog-v3/migration-manifest.json`：逐组件来源与源码一致性记录。
4. `THIRD_PARTY_NOTICES.md`：来源及许可。
5. `package.json`、`pnpm-workspace.yaml`、`nuxt.config.ts`：当前依赖、补丁和集成配置。
6. `vendor/xupt-wiki/README.md` 及迁移清单：Coder 两页原版组件、动画和必要适配。

不要先删除缓存、升级依赖或更换框架。先定位问题及现有实现。

## 3. 当前实现与仍未完成的目标

| 部分 | 当前情况 |
| --- | --- |
| 框架 | Docus 5.13.0 / Nuxt 4.5.2 / Nuxt Content 3.15.2，默认静态生成 |
| 首页 | 保留参考站的 15 个入口、分类菜单、最近更新 |
| 校园正文 | 以框架和待补充条目为主，不能宣称 WUST 信息已经核实完整 |
| `/coder/`、`/coder/blog` | 已迁入西邮原版 12 个组件及 VitePress Badge，保留全部组件动画样式；`CoderDirectory.vue` 仅为装配包装 |
| `/components` | 早期三个适配组件的演示，仍保留 |
| `/blog-components`、`/previews/example` | 同一完整博客组件示例页；迁入原正文、27 个正文组件、BlogHeader 及相关依赖 |

Coder 两页原版移植已在博客组件迁移后完成。运行副本在 `app/xupt/`，源码快照在 `vendor/xupt-wiki/`。不要恢复旧的自写翻面按钮和排序实现；修改动画前核对上游 BlurCard、BlogCard 和两个列表的 TransitionGroup。

参考来源：

- 西邮 Wiki：<https://wiki.cooo.site/>；Coder：<https://wiki.cooo.site/coder/>、<https://wiki.cooo.site/coder/blog>。
- 博客示例：<https://blog.zhilu.site/previews/example>。
- 博客源码：<https://github.com/L33Z22L11/blog-v3>。
- 已迁移提交：`f6ea97d745517feb52f0c100e89acb36f0adc12f`。上游更新时先比较差异，不直接覆盖本地适配。

## 4. 文件定位

| 修改对象 | 入口 |
| --- | --- |
| 首页入口、顶部分类 | `app/data/wiki.ts`、`app/pages/index.vue` |
| 全部文章 | `app/pages/articles.vue` |
| Markdown 与侧栏结构 | `content/`、`content.config.ts`、`templates/article.md` |
| Coder 页面装配 | `app/pages/coder/`、`app/components/content/CoderDirectory.vue` |
| Coder 原版组件与样式接入 | `app/xupt/`、`app/assets/xupt-coder.css`、`app/assets/xupt-variables.css` |
| Coder 相对链接兼容 | `app/utils/coder.ts` |
| 实验室、博客名单 | `app/data/coder/labs.json`、`app/data/coder/blog.json` |
| 原博客组件运行副本 | `app/clarity/` |
| 原博客源码快照 | `vendor/blog-v3/components/` 及相邻依赖目录 |
| 完整示例正文 | `content/blog-components.md`；原文快照为 `vendor/blog-v3/example.md` |
| 示例布局、组件映射、侧栏与许可插槽 | `app/pages/blog-components.vue` |
| Wiki 样式 | `app/app.css` |
| 博客样式接入 | `app/assets/blog-components.scss`、`vendor/blog-v3/styles/` |
| 品牌、组件选项 | `app/app.config.ts`、`blog.config.ts` |
| 注册、Markdown 插件、构建配置 | `nuxt.config.ts` |
| 全局浮层、搜索、页面外壳 | `app/app.vue` |

`content/` 的数字前缀用于排序，不进入 URL。`status: draft` 仍会生成页面；最近更新要求 `status: published` 且填写 `updated`。不要用今天的日期代替实际内容更新时间。

文档导航在 `app/app.vue` 查询后递归添加 `exact: true`，使用 Nuxt UI 原生精确匹配。不要移除：默认非精确匹配会让 `/campus` 的“学校简介”在 `/campus/anti-fraud` 等子页同时高亮，学习/生活分类同理。`scripts/qa-navigation.cjs` 是对应浏览器回归检查，验证直接访问、栏目切换和前进后退仅高亮当前文档；需要 Playwright、Edge 和 `WIKI_QA_URL` 指定的预览服务。

## 5. 博客组件的接入约定

- 普通文档正文现由 `app/pages/[[lang]]/[...slug].vue` 接入博客渲染。该文件复用 Docus 5.13.0 页面外壳，仅调整正文及本地类型/查询键；升级 Docus 时对照上游。共享基础 Markdown 映射在 `app/utils/blog-prose.ts`，作用于普通正文和完整示例。正文使用 `.blog-components .article.md-tech`、关闭默认 Prose 映射并保留段落和标题组件。不要恢复为裸 ContentRenderer，否则会回到 Docus 默认排版。

- `vendor/blog-v3/` 的组件和示例快照用于追溯，实际修改运行副本 `app/clarity/`。样式和 Markdown 插件部分直接从 vendor 使用，并非整个 vendor 都是只读快照；适配范围见其 README。
- 27 个正文组件通过 `nuxt.config.ts` 显式注册，名称带 `Blog` 前缀。普通 Markdown 使用 `::blog-tab`、`::blog-pic` 等，参数和插槽以原组件与完整示例为准。
- 完整示例页专门映射 `::tab`、`::pic` 等原名称，并映射链接、行内代码、代码块和表格。不要误认为全站自动拥有同样的 Markdown 映射。
- 示例页保留段落组件与标题锚点，正文关闭默认 Prose 映射，避免 Docus 表格等样式覆盖原博客样式。Chat、Timeline 依赖段落插槽结构，修改渲染方式时必须回归验证。
- 原文章与可复用样式作用于 `.blog-components` 范围，正文使用 `.article.md-tech`。迁入其他文档时核对实际容器和样式覆盖；仅注册组件不能保证外观完全一致。
- 样式范围必须使用 `:where(.blog-components)`，避免前缀提高优先级后覆盖原组件的图片高度和代码块行号留白。KaTeX CSS 版本须与 rehype-katex 实际渲染版本一致，当前为 0.16.47；不一致会使分数等公式重叠。对应布局回归脚本为 `scripts/qa-blog-layout.cjs`。
- 当前 27 个正文组件中，25 个保持源文件原样；FeedCard/FeedGroup 仅改类型导入路径。改动后同步更新迁移清单，不继续沿用过期的一致性声明。
- BlogHeader 使用 `useBlogComponentConfig` 隔离博客与 Docus 的 header 配置。
- `BlogInlineCodeBridge.vue` 将当前 Content 版本的行内代码插槽转换为原组件的 `code` 属性；不要删掉后只检查构建成功，需查看行内代码是否真正显示。
- `rehype-meta-slots` 提取侧栏和许可内容，由示例页显式渲染；保留具名插槽。
- Mermaid、ABC 乐谱、KaTeX、Shiki、Tippy 与灯箱使用原项目库和插件；保留按需加载、深色模式重绘及浮层挂载。
- Shiki 远程模块导入已通过 alias 指向本地包；新增图标时检查客户端图标集合，不依赖碰巧可用的远程加载。
- 保留 `patches/` 及 `pnpm-workspace.yaml` 中的 Docus、plain-shiki 补丁与 Content 版本统一配置。升级时复核上游是否已修复。
- 原源码可保留作者说明。代码 MIT、示例正文自述 CC0；字体、外部素材及其他文章不因此自动获得相同许可。

## 6. 开发与验证

环境以 `package.json` 为准：Node.js `>=24.11.0 <25`，pnpm `11.20.0`。PowerShell 中在项目根目录运行：

```powershell
pnpm install --frozen-lockfile
pnpm dev
```

采用终端实际输出的地址。开发服务支持热更新；静态预览不会随着源码修改自动重新生成。不要假设旧会话的 4178 端口仍有服务。若端口无法绑定，检查占用和 Windows 排除端口，选择可用端口，不直接改系统保留范围。

代码、样式或依赖变更后，执行与改动相关的检查：

```powershell
pnpm check:content
pnpm check:xupt
pnpm typecheck
pnpm generate
$env:PORT = '4178'
pnpm preview:static
```

静态产物为 `.output/public/`。仅文档指引修改不必重跑应用构建。不要编辑 `.nuxt/`、`.output/`、`node_modules/` 来代替源码修复。

涉及组件或页面时，至少验证相关实际交互，不能仅凭构建通过判断功能可用：

- 直接访问及站内跳转到 `/blog-components`、`/previews/example`；检查标题、侧栏插槽、许可及行内代码。
- 检查标签切换、代码展开/复制、可编辑命令与撤销、灯箱开关、友链浮层、键盘反馈、表格换行。
- 滚动至 Mermaid 和乐谱触发懒加载；检查 Mermaid 缩放与深色切换、乐谱 SVG 和播放控件。
- 检查桌面、390px 手机视口、深浅色，区分组件内部横向滚动与整页溢出。
- 查看浏览器运行时异常、hydration 和组件解析警告；全局变更同时回归首页、普通正文及 Coder 两页。
- 仅 Coder 博客页可用 `?shuffle=false` 固定顺序，实验室沿用上游挂载时随机排序。检查悬停 3D 翻面、博客淡入淡出、复制、排序位移动画、二维码浮层和真实外链目标。
- 示例里的命令是渲染/复制测试文本，不应执行这些示例命令。

2026-09-13 的历史验证：静态生成 108 条路由，内容检查 31 篇文档、15 个入口、44 个内部链接，类型检查及主要浏览器交互通过。这些数量不是未来必须固定的断言。

博客历史浏览器测试脚本位于 `.cache/full-blog-qa.cjs`、`.cache/blog-extra-qa.cjs`，属于被忽略的临时文件，其他 checkout 可能没有。旧 `.cache/qa-coder.cjs` 针对已移除的自写版本，不再适用。原版 Coder 测试为 `scripts/qa-xupt.cjs`，通过 `WIKI_QA_URL` 指定服务地址，需要环境可解析 Playwright 且安装 Edge，未将测试浏览器加入生产依赖。`pnpm check:xupt` 则不依赖浏览器，校验迁移清单和原样动画样式。不要把本机运行时路径写成项目依赖。

外部资源验证须单独报告：历史灯箱自动检查替换了随机图片响应；外部图片服务可用性、外部视频实际播放、乐谱实际出声尚未验证。播放控件存在不等于已播放成功。

## 7. 交接与后续工作

补全本科专业列表前，先读 [本科专业列表填写指南](./docs/major-editing-guide.md) 和 [专业卡片来源记录](./docs/major-mvp-sources.md)。沿用原文学院分类及原版翻面组件，保持无图标、桌面5列和背面的“所属学院”“学院地点”标签。材料学院链接按用户指定使用 `https://cl.wust.edu.cn/`。楼宇信息须查证校区与用途，不能将学院办公地点当作所有专业的上课地点。2026-09-13 已按官方招生计划补全为22个学院（部）和76张卡片；后续扩展或调整时同步原表格、数据、来源及 QA 数量断言。

完成修改后更新相应 README、迁移清单或本文件中的过期事实，保留来源与适配理由。总结使用“直接复用”“必要适配”“自行实现”的真实分类。

未完成方向包括：WUST 真实资料替换、其他文档使用完整博客组件时的逐页样式验证、外部媒体实际播放验证、正式域名与仓库配置。按用户下一次任务推进，不默认全部执行，也不为此重写现有组件。
