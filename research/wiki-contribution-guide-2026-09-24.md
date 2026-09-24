# Wiki 贡献指南社区调研

调研日期：2026-09-24。用途：补全 WUST Wiki 的 `/contributing`；以下区分社区做法与本项目的编辑建议，不移植其他站点的提交入口或技术配置。

## 一手社区资料

| 社区 | 已核实的做法 | 对 WUST Wiki 的启发 |
| --- | --- | --- |
| [西邮 Wiki：贡献指南](https://wiki.cooo.site/contributing) | 接受完整段落、文档和 Pull Request；简短说明主题、真实性、署名与内容更新时间。 | 保留轻量入口，允许从一段纠错开始；日期、作者字段按本项目实现说明。 |
| [OI Wiki：如何参与](https://oi-wiki.org/intro/htc/) | 分开介绍网页编辑和本地编辑；列出提交、追加修改、预览及评审流程；建议选择熟悉的主题并查阅资料。 | 小修改先介绍网页编辑，开发环境作为进阶路径；让读者知道提交后会发生什么。 |
| [SJTU Wiki：贡献指南](https://sjtu.wiki/contributing) | 同时提供 GitHub 和问卷投稿；制度、政策、流程优先引用学校原文；时效内容说明获取新信息的方式。 | 不把 Git 当作参与门槛；校园事实附官方来源和适用范围，投稿入口只使用本项目已有渠道。 |
| [爱特工作室 Wiki：贡献指南](https://wiki.itstudio.club/wiki/about/join.html) | 先列纠错、经历、资源、反馈等贡献类型；提供网页、本地、邮件三种途径；经验文章包含年级、署名和日期。 | 用具体的小任务引导参与；经历应交代时间与背景，署名形式尊重作者选择。 |
| [osu! wiki：Contribution guide](https://osu.ppy.sh/wiki/en/osu!_wiki/Contribution_guide) | 按编辑、自检、PR、评审、合并展开；不要求新人预先掌握 Git；自检集中于语言清楚、语气、结构及预览。 | 主文保留可立即执行的步骤和短自检；把详细语法放到可按需查阅的链接中。 |

另检索了 [ArchWiki：Contributing](https://wiki.archlinux.org/title/ArchWiki:Contributing)。搜索索引可见小步修改和清楚填写编辑摘要的建议，但直接打开触发站点访问保护，因此未把它列为本轮完整阅读的主要依据。

操作步骤补充依据：[GitHub 官方「编辑文件」](https://docs.github.com/zh/repositories/working-with-files/managing-files/editing-files)核实了文件页铅笔编辑、复刻其他用户仓库、预览、填写提交说明、创建 Pull Request 的网页流程。本站指南可直接链接仓库的 `content/` 目录，再指引读者找到对应文件。

## 推荐正文结构

以下是结合本项目需求作出的编写建议。

1. **从哪里开始。** 一句话欢迎，然后给出四类实际任务：修正过时信息、补充办事流程、分享有时间和范围的经历、完善目录数据。社区普遍将纠错与补充已有内容视为有效贡献，不必以新写长文为起点。[爱特工作室](https://wiki.itstudio.club/wiki/about/join.html)、[西邮 Wiki](https://wiki.cooo.site/contributing)
2. **选择参与方式。** 普通读者提供“页面地址、问题或新增内容、适用范围、来源”；熟悉 GitHub 的读者再查看网页编辑与 PR；多文件或组件修改再进入本地开发。多种入口能覆盖不同技术背景的贡献者。[SJTU Wiki](https://sjtu.wiki/contributing)、[OI Wiki](https://oi-wiki.org/intro/htc/)
3. **把内容写清楚。** 办事指南按“适用对象—入口—材料—步骤—结果”组织；先回答读者要办什么事。校规、费用、学分等事实附发布部门、原文链接及适用年份；个人体验直接写发生时间、校区、具体情况。前者依据社区对官方资料与时效性的要求，后者是面向本 Wiki 的建议。[SJTU Wiki](https://sjtu.wiki/contributing)
4. **本 Wiki 的编辑方法。** 说明内容目录与实际数据入口、最小文章头、站内链接、图片、可复用正文组件；直接引用项目现有模板和示例，避免把其他站点的字段、路径复制过来。
5. **提交与后续。** 只要求描述改了什么、为什么、根据什么；提供几项短自检，说明作者可继续补充资料和回应修改建议。评审与后续修改是完整参与流程的一部分。[OI Wiki](https://oi-wiki.org/intro/htc/)、[osu! wiki](https://osu.ppy.sh/wiki/en/osu!_wiki/Contribution_guide)

## 本项目落地要点

- 改写前的贡献页只有编辑路径、来源范围、发布字段与隐私等简短提示；本轮补上了从选题到提交的完整路径。见 [`content/contributing.md`](../content/contributing.md)。
- 本站使用 Nuxt Content。文章头、排序与路由按 [`templates/article.md`](../templates/article.md)、[`content.config.ts`](../content.config.ts) 和 [`README.md`](../README.md) 核实，不能照搬西邮的 `date` / `lastUpdated` 或 SJTU 的 `order`。
- 为专业、实验室、博客、导航等内容列出实际源码入口，帮助贡献者找到数据文件；公开指南只写修改者需要的信息，迁移历史与详细工程约定留在 README 和 `docs/`。
- 普通投稿模板建议仅有五项：主题或页面、建议内容、适用范围与时间、资料链接或附件、署名。无公开链接的亲历可以如实说明，不把未核实描述写成通用事实。
- 用户明确要求减少无意义警告。正文采用正常段落与例子；隐私、转载署名、政策出处各用一句有行动价值的说明即可。不要复刻其他站点的长立场规则、重复免责声明、积分制度或逐项许可勾选。
- 当前 [`app/app.config.ts`](../app/app.config.ts) 的 `github: false` 关闭 Docus 源文件编辑入口；[`DocsArticleAside.vue`](../app/components/docs/DocsArticleAside.vue) 的“补充与纠正”链接为 [本项目 Issues](https://github.com/jiangescn/wust-wiki/issues)。因此正文从仓库文件页介绍铅笔编辑，不声称本站已有“编辑此页”。没有确认的表单、邮箱不编造，不使用参考站的联系人。
- 不从其他社区移植 DCO、内容许可、管理员票数或审核时限；这些属于各项目自己的协作政策。
- GitHub API 已确认本项目为公开仓库、默认分支是 `main`、Issues 已启用。初稿时有 11 个仓库文件或目录链接已用远端树核对；后续发布准备中补上随本次入库的培养方案维护说明、两份导航数据链接。原始培养方案归档仅保留本地，公开指南改为引导通过 Issue 提供原件。

## 一份简短自检

建议最终页只保留四项：信息及适用范围清楚；来源可追溯；链接和图片可打开；预览后的标题、表格与步骤易读。组件或代码修改另外链接项目开发检查，不让普通文字贡献者先读完整工程规范。此安排综合了社区指南对来源、时效和预览的要求。[SJTU Wiki](https://sjtu.wiki/contributing)、[osu! wiki](https://osu.ppy.sh/wiki/en/osu!_wiki/Contribution_guide)

## 本轮落地与验证

正文已写入 `content/contributing.md`，沿用现有 Markdown 与博客正文组件，README 增加维护入口。`pnpm check:content` 通过（29 篇文档、14 个首页入口、47 个内部链接），`pnpm generate` 生成 103 条路由。

本地静态预览 `http://127.0.0.1:4178/contributing` 已验证直接访问、从“编辑指南”站内跳转、目录锚点、桌面与 390px 手机深浅色显示；手机表格在自身容器内横向滚动，页面无横向溢出。浏览器未捕获警告或错误。构建仍有依赖外置、动态导入及体积提示，未阻止生成。本轮未提交、推送或部署。
