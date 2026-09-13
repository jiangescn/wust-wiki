# WUST Wiki 框架候选调查

核查日期：2026-09-12。范围：官方文档与源码支持的内容框架、组件、搜索与协作方式；未安装、未运行原型。工作区初始为空，未发现 AGENTS.md 或既有笔记目录，因此使用 research/。本笔记合并主调查对参考 Wiki、博客组件及 Docus 的源码审阅。

## 结论与决策条件

**结合博客源码后的建议：若“大量复用该博客文档组件”是优先条件，首选评估 Docus；若只移植少数视觉组件，更推荐 VitePress 官方默认主题扩展。** Docus 与博客同属 Nuxt/Content 技术体系，减少重建 Nuxt 上下文和内容管线的需要；但它的 Nuxt UI 样式、配置和组件约定仍可能冲突，不能承诺复制即可运行。这是架构判断，尚未做移植试验。[Docus 官方仓库](https://github.com/nuxt-content/docus)、[博客核查快照](https://github.com/L33Z22L11/blog-v3/tree/f6ea97d745517feb52f0c100e89acb36f0adc12f)

**如果维护者愿意通过 Git 审核投稿，以维护成本为先，VitePress 是稳妥选择。** 文档内容和导航先稳定，再移植少量内容组件。VitePress 可直接在 Markdown 中使用 Vue SFC；但 Nuxt 专属 API、全局状态、样式和内容解析约定仍需移植，不能因同为 Vue 就判定零改动兼容。[VitePress 1.x Vue 文档](https://vuejs.github.io/vitepress/v1/guide/using-vue)

**若优先追求内容站性能、丰富静态组件和内置搜索，且愿意接受 MDX/Astro 适配，Starlight 是最有力的备选。** 它也能接 Vue，不应误说成“只能用 React”。[Starlight 组件文档](https://starlight.astro.build/components/using-components/)

**若多数贡献者要求登录网页即编辑，先选协作产品，再选外观：应认真考虑 Wiki.js。** 静态文档站可以多人协作，但编辑、审核、账户和历史通常交给 Git 平台或另外的 CMS，和 Wiki.js 自带的网页编辑体系是两回事。[Wiki.js 功能](https://js.wiki/)、[VitePress CMS](https://vitepress.dev/guide/cms)

以上是工程建议，不是实际性能或移植测试结果。

## 官方事实比较

| 候选 | 内容与组件 | 搜索 | 协作定位 | 对本项目的建议 |
| --- | --- | --- | --- | --- |
| Docus | Nuxt 4、Nuxt Content、Nuxt UI 4；支持 MDC、自定义组件和布局 | 提供内容搜索 | 内容文件型站点，协作流程另配 | 大量复用指定 Nuxt 博客组件时优先评估；来源：[官方仓库](https://github.com/nuxt-content/docus) |
| VitePress | Markdown 编译成 Vue 组件，可直接导入 SFC；Vue 使用需兼容 SSR | 内建 MiniSearch 本地全文搜索，也能接 Algolia | 文件型内容；可接 CMS | 少量普通 Vue 组件与维护成本优先时推荐 |
| Astro Starlight | Markdown、MDX、Markdoc；组件用于 MDX/Markdoc；可增加 Vue 集成 | 默认 Pagefind 全文搜索，构建部署后可用 | 文件型内容；编辑流程需另配 | 适合静态内容占多数、接受 Astro/MDX 的团队 |
| Docusaurus | MDX 将内容编译为 React 组件；Vue SFC 不是原生内容组件格式 | 官方支持 Algolia；本地搜索方案主要由社区维护 | 文件型文档站 | 若团队已有 React 经验才更值得优先；为复用 Vue 组件而选它成本偏高 |
| Wiki.js | 网页 Markdown 编辑器及可视化编辑器；并非直接编译任意 Vue SFC 的文档管线 | 内置数据库搜索，可扩展搜索服务 | 自带账号、组权限、页面规则、版本历史 | 非技术贡献者网页编辑优先时选；外观和组件复用需要更多适配 |

事实来源：[VitePress Vue](https://vuejs.github.io/vitepress/v1/guide/using-vue)、[VitePress 搜索](https://vuejs.github.io/vitepress/v1/reference/default-theme-search)、[Starlight 内容目录](https://starlight.astro.build/guides/project-structure/)、[Starlight 组件](https://starlight.astro.build/components/using-components/)、[Starlight 搜索](https://starlight.astro.build/guides/site-search/)、[Docusaurus Markdown](https://docusaurus.io/docs/markdown-features)、[Docusaurus 搜索](https://docusaurus.io/docs/search)、[Wiki.js](https://js.wiki/)。表中移植成本和优先级为根据这些架构事实作出的判断。

## 参考站和博客源码审阅

参考 Wiki 的源码快照为 `xupt-wiki/xupt-wiki@f1ba156d8f91374422921df51a9bc26703c298ab`；主题入口扩展 `vitepress/theme-without-fonts` 默认主题，并叠加布局槽、组件和 CSS。因此复现其整体导航形态无需重新实现完整 Wiki 引擎。[主题入口](https://github.com/xupt-wiki/xupt-wiki/blob/f1ba156d8f91374422921df51a9bc26703c298ab/docs/.vitepress/theme/index.ts)

博客源码快照为 `L33Z22L11/blog-v3@f6ea97d745517feb52f0c100e89acb36f0adc12f`，基于 Nuxt 4 + Nuxt Content 3。主调查读取对应组件源码发现：LinkCard 依赖 UtilLink、UtilImg、joinWith、getDomain、ImgService 和全局 card 样式；Alert 依赖 app config、Icon 及 `--c`/`--ld` CSS 变量；Pic 依赖自动导入的 LazyPopoverLightbox、useModalStore、UtilImg；ProsePre 依赖 Nuxt Content props、app config、useShiki/useCopy 和图标函数；Tab 较接近纯 Vue + CSS 变量。由此判断这些组件不是独立的通用组件包。[博客源码目录快照](https://github.com/L33Z22L11/blog-v3/tree/f6ea97d745517feb52f0c100e89acb36f0adc12f)

主调查核对 README 与 LICENSE：代码 MIT、文章 CC BY-NC-SA 4.0，LICENSE 版权信息为 2024 Zhilu。实施应区分代码与文章/图片，保留适用的许可和署名，不把整个仓库素材默认视为 MIT。[README](https://github.com/L33Z22L11/blog-v3/blob/f6ea97d745517feb52f0c100e89acb36f0adc12f/README.md)、[LICENSE](https://github.com/L33Z22L11/blog-v3/blob/f6ea97d745517feb52f0c100e89acb36f0adc12f/LICENSE)

这些结论来自源码审阅，不是运行或迁移验证。

## Vue 组件复用的边界

- 对普通独立 Vue 组件，VitePress 的导入方式很直接；本次 Nuxt Content/MDC 组件仍需上述环境适配。内容页局部导入组件可以按页拆分；常用组件可以全局注册。所有 Vue 代码要满足 SSR 要求，DOM 操作、浏览器 API 和第三方库要单独检查。[官方文档](https://vuejs.github.io/vitepress/v1/guide/using-vue)
- Starlight 可在 MDX 中使用受支持框架组件，包括 Vue；Astro 官方 Vue 集成负责渲染与客户端 hydration。因此 Vue 文件可能复用，但 Nuxt 应用环境、交互水合策略、组件插槽和内容渲染方式不能默认一致。[Starlight](https://starlight.astro.build/components/using-components/)、[Astro Vue 集成](https://docs.astro.build/en/guides/integrations-guide/vue/)
- Docusaurus 的 MDX 组件模型是 React。仅希望相同视觉效果时可以重写；如果希望保留原 Vue 组件源码和交互逻辑，它不是最顺的路径。[官方 MDX 文档](https://docusaurus.io/docs/markdown-features)
- Wiki.js 的页面编辑和内容渲染与前端源码构建不同。官方列有 CSS/JS 注入能力，但这不等于可直接把 Vue SFC 写进文章。其官网自定义主题仍标为 Coming Soon，不能据此承诺成熟可替换主题 API。[官方功能表](https://js.wiki/)

## 中文搜索与运行版本

VitePress 的“本地全文搜索”不等于已验证校园专有词分词效果。应使用“黄家湖、青山、沁湖、选课、补考”等真实词、缩写、别名和长查询验收，并检查组件内部文本是否进入索引。[VitePress 搜索与索引渲染接口](https://vuejs.github.io/vitepress/v1/reference/default-theme-search)

Pagefind 明确支持无空格文字分词；中日韩使用 extended release，`npx pagefind` 默认使用该版本。它会按页面 `lang` 区分索引，因此应正确设置中文语言，并用实际构建产物测试。[Pagefind 多语言搜索](https://pagefind.app/docs/multilingual/)

校园生活百科不要默认能获批免费 Algolia DocSearch：Docusaurus 官方说明其免费托管计划面向开发者文档和技术博客，仍需申请并符合要求。优先本地搜索能减少这个外部条件。[Docusaurus 搜索说明](https://docusaurus.io/docs/search)

核查时 VitePress 主站文档导航显示 2.0.0-alpha.20，同时提供 1.6.4 链接。实施时应确认并锁定所选稳定版本，避免直接把新版本文档特性用于旧版；本报告的核心 VitePress 能力同时参考了 1.x 文档。[主站 Vue 文档](https://vitepress.dev/guide/using-vue)、[1.x 文档](https://vuejs.github.io/vitepress/v1/guide/using-vue)

## 对校园知识库的工程建议

以下为建议，并非宣称框架已提供这些完整机制：

1. 起步采用“少数维护者审核 + 普通同学提交表单/Issue + 熟练贡献者 PR”的双入口，减少 Git 门槛；若网页直接编辑是硬需求，改以 Wiki.js 或成熟 CMS 为主。
2. 为内容记录适用校区、适用学年、来源、最近核实日期与负责人；不要把 Git 提交日期当作事实核实日期。
3. 先用 10—20 篇真实页面试信息架构：新生、学习、办事、住宿、交通、校园服务；避免照搬个人博客时间线导航。
4. 常规内容保持 Markdown；把卡片、标签页、时间线等收敛为少量稳定组件，给投稿者模板，避免每页混入任意脚本。
5. 不可信投稿应走审核后构建；MDX/Vue Markdown 具有代码能力，构建任务不要随意向外部投稿提供敏感凭证。
6. 组件样式需验收手机阅读、长表格、夜间模式、键盘操作；公开校园知识与包含个人信息的数据服务分开设计。
7. 交接文档应包含域名续费、部署、备份、回滚、投稿审核与维护者接替方式，防止毕业即失维护。

此调查没有搭建网站、跑分或完成博客组件移植；具体兼容性仍需对拟移植组件做最小原型验证。
