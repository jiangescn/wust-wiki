---
title: 贡献指南
description: 提供资料、纠正错误，或直接参与编写 WUST Wiki
status: published
updated: '2026-09-24'
---

发现过期的办事入口、手里有缺少的培养方案，或者想补充自己熟悉的校园生活经验，都可以参与。改正一个错字、补上一条来源，也是一份贡献。

## 提供资料或反馈问题

不熟悉 Markdown 和 Git，可以直接[提交 Issue](https://github.com/jiangescn/wust-wiki/issues/new)，把材料交给维护者整理。页面上的“补充与纠正”也通往同一个项目。提交前看一眼[已有反馈](https://github.com/jiangescn/wust-wiki/issues)，同一件事可以接着补充。

标题写清具体事项，例如“补充某专业 2025 级培养方案”。正文说明这三件事即可：

```text
相关页面：页面链接，或希望新增的主题
补充或更正：哪里有误、建议怎样改，或提供了什么资料
信息依据：原通知链接、文件；亲身经历请写明时间和校区
```

培养方案请附上学院、专业、本科或研究生、适用年级及原文件；俱乐部、兴趣群和博客收录请提供名称、简介与公开主页。字段不全也可以先提交已有资料。

如果是页面或查询功能出错，请说明操作步骤、预期结果和实际现象，附上浏览器名称及必要截图。

## 直接修改页面

少量文字修改可以在浏览器里完成，只需要一个 GitHub 账号：

1. 打开仓库的 [content 目录](https://github.com/jiangescn/wust-wiki/tree/main/content)，找到对应文章。文件开头的 `title` 就是页面标题。
2. 点击文件右上角的铅笔按钮。没有写入权限时，按提示 Fork（创建自己的副本），再编辑内容。
3. 检查改动，填写一句明确的说明，例如“更新黄家湖校区快递领取地点”，提交到自己的分支。
4. 按提示创建 Pull Request（简称 PR，合并请求），目标选择 `jiangescn/wust-wiki` 的 `main` 分支，说明改了什么并附上依据。维护者会在 PR 中讨论和审阅；需要调整时，继续修改同一分支即可。

一次提交围绕一个主题，便于核对和合并。GitHub 的预览可以检查普通 Markdown；卡片、折叠块等本站组件需要在本地预览。更详细的操作可看 [GitHub 网页编辑说明](https://docs.github.com/zh/repositories/working-with-files/managing-files/editing-files)。

## 内容怎么写

**先回答读者的问题。** 办事指南写清入口、材料和步骤，地点介绍写清校区与位置，经验文章写具体做法。尽量使用短段落、明确的小标题；步骤用列表，需要比较时再用表格。

**把来源放在相关内容旁。** 学籍政策、收费、招生和培养要求优先引用学校或学院原文，注明通知日期和适用年级。文件资料保留标题、版本和原始链接；旧版资料可以收录，写明适用范围即可。转载文字或图片时保留作者与出处，按原作的授权使用。

**经验写清范围。** 住宿、食堂、校园网等亲身体验很有用，请写明时间、校区和具体条件。一栋楼、一届学生的情况就按这个范围写；尚未确认的细节标为“待核实”，目录里不知道的字段留空。整理群聊线索时，提炼可核对的信息，不直接贴原始聊天记录。截图遮去学号、手机号、登录二维码等个人或登录信息，群联系方式只收录同意公开的招新入口。

## 找到要修改的文件

普通文章放在 `content/`，部分卡片和目录由独立数据文件生成。常用入口如下：

| 要修改的内容 | 文件位置 |
| --- | --- |
| 校园、学习、生活文章 | [content/1.campus](https://github.com/jiangescn/wust-wiki/tree/main/content/1.campus)、[content/2.study](https://github.com/jiangescn/wust-wiki/tree/main/content/2.study)、[content/3.life](https://github.com/jiangescn/wust-wiki/tree/main/content/3.life) |
| 本科专业卡片 | [app/data/majors.ts](https://github.com/jiangescn/wust-wiki/blob/main/app/data/majors.ts)，补充前看[专业填写指南](https://github.com/jiangescn/wust-wiki/blob/main/docs/major-editing-guide.md) |
| 培养方案文件与来源 | 通过 Issue 提供原件；归档与生成步骤见[目录维护说明](https://github.com/jiangescn/wust-wiki/blob/main/docs/curricula-directory.md) |
| 武科大俱乐部、校友博客 | [app/data/coder/labs.json](https://github.com/jiangescn/wust-wiki/blob/main/app/data/coder/labs.json)、[app/data/coder/blog.json](https://github.com/jiangescn/wust-wiki/blob/main/app/data/coder/blog.json) |
| 兴趣群列表 | [app/data/interest-groups.ts](https://github.com/jiangescn/wust-wiki/blob/main/app/data/interest-groups.ts) |
| 武科大导航 | [app/data/navigation.ts](https://github.com/jiangescn/wust-wiki/blob/main/app/data/navigation.ts)、[app/data/navigation-extra.ts](https://github.com/jiangescn/wust-wiki/blob/main/app/data/navigation-extra.ts) |

目录和文件的数字前缀只决定排序，不进入网址。例如 `content/1.campus/3.accommodation.md` 对应 `/campus/accommodation`。

### 新增文章与排版

在合适的分类目录中复制[条目模板](https://github.com/jiangescn/wust-wiki/blob/main/templates/article.md)，使用简短的英文文件名。先看看同主题的页面，能补进现有条目的内容就直接补充。

文章开头的元数据写法如下，正文从二级标题开始，页面会自动显示标题和描述：

```markdown
---
title: 条目名称
description: 一句话说明这篇文章能解决什么问题
status: draft
---

## 办理步骤

在这里写具体内容。

## 来源

在这里列出通知或资料的链接与日期。
```

`draft` 表示仍待补充，页面仍会公开显示。关键内容补齐并核对后改为 `published`，再填写 `updated: 'YYYY-MM-DD'`，使用本次实际修改日期；这一日期用于首页“最近更新”的排序。资料本身的年份另写在正文中。

正文支持常用 Markdown。站内链接使用 `/campus/accommodation` 这样的页面路径；图片放入 `public/images/` 对应主题目录，引用时从 `/images/` 开始。需要图注、折叠块或标签页时，参考[完整正文组件示例](/blog-components)；普通文章使用 `::blog-pic`、`::blog-folding`、`::blog-tab` 等带 `blog-` 前缀的名称。

## 本地预览与提交

编辑多篇文章、调整数据或组件时，可以将自己的 Fork 克隆到本地，在新分支中修改。项目使用 Node.js 24（至少 24.11，低于 25）和 pnpm 11.20.0，在仓库目录运行：

```sh
pnpm install --frozen-lockfile
pnpm dev
```

打开终端显示的地址，检查改过的页面。提交前运行 `pnpm check:content`，并确认链接、图片和手机布局正常。涉及组件或代码时，再运行 `pnpm typecheck` 和 `pnpm generate`；修改 Coder 组件还需运行 `pnpm check:xupt`。

本站基于 Docus / Nuxt，正文和 Coder 页面复用了现有组件。开发时先查找已有实现，具体源码入口及组件来源见[项目 README](https://github.com/jiangescn/wust-wiki/blob/main/README.md)。

把修改提交到当前分支并推送至自己的 Fork，再在 GitHub 创建 PR，写清修改内容、资料来源和实际做过的检查。合并后还需发布网站，页面才会更新。
