# CO 导航上游快照与武科大适配

来源：[xupt-wiki/xupt-nav](https://github.com/xupt-wiki/xupt-nav)，提交 `22c863940ce888ae744929b8aaa205ff6c280f19`，保存日期 2026-09-24。

上游是纸鹿维护的「CO导航 - 西邮导航服务」，使用原生 JavaScript 和 CSS。上游页面标注 `Copyright 2026 纸鹿` 与 `GPL-3.0`；完整许可证保存在 [LICENSE](./LICENSE)，原 README 保存在 [upstream-README.md](./upstream-README.md)。这份文件是 WUST Wiki 的迁移说明，不是上游 README。

## 精确快照

| 上游路径 | 本地快照 | 用途 |
| --- | --- | --- |
| `asset/index.css` | `asset/index.css` | 原版多栏布局、圆角分类卡片、紧凑链接与小字说明样式 |
| `asset/nav.js` | `asset/nav.js` | 原版导航数据结构与卡片模板 |
| `index.html` | `index.html` | 原页面结构、依赖和版权声明 |
| `LICENSE` | `LICENSE` | GPL-3.0 完整许可文本 |
| `README.md` | `upstream-README.md` | 原项目说明 |

这些文件以 HTTP 响应字节直接保存，未改换行或格式；本目录 `.gitattributes` 为这五份快照禁用 Git 文本换行转换。各文件的上游路径、下载地址、字节数和 SHA-256 记录在 [migration-manifest.json](./migration-manifest.json)。本目录不是可独立运行的完整上游站点；计时器、弹窗、更新检查等外围文件不在本次快照范围。

## 原版实现与适配边界

原版 `.col-auto` 使用 `column-width: 20em`、`column-gap: 1rem` 自动多栏；分类卡片保持 `break-inside: avoid`，圆角为 `1rem`，卡片子项边距为 `.8rem 1rem`。卡片内 `.list` 使用可换行的 flex，间距为 `.5em 1rem`；链接 `data-sub` 通过伪元素显示下方的小字说明，字号为正文的 `.6em`。上游链接使用缩放和强调色背景的 hover 反馈，卡片有边框及阴影过渡；这些是原站行为，运行版的视觉适配见下文。

`nav.js` 把数据和 DOM 操作放在同一文件：`nav.list[0]` 为主要导航，`nav.list[1]` 为「发现更多」；分类使用 `name/icon/desc/item`，条目使用 `text/desc/icon/link` 或 `js`。原实现通过 `innerHTML` 字符串生成 `.card`、`.between`、`.list`、`a[data-sub]`，没有搜索或筛选功能。

武科大版本保留上述分类卡片结构和布局样式，并在 Nuxt 页面边界进行必要适配：用 Vue 模板循环替换直接 DOM 写入；用页面容器限制原版全局选择器，接入 Wiki 外壳与主题；图标使用项目已有组件与本地图标集合。武科大链接另行维护和核实，原版西邮名单不作为武科大信息。

运行入口为 `app/pages/navigation.vue`，官方入口数据在 `app/data/navigation.ts`，已有 Wiki 入口及公开学习平台在 `app/data/navigation-extra.ts`。页面通过 `<style scoped src>` 接入 `app/assets/co-navigation.css`，该样式直接衍生自本目录 `asset/index.css`，文件头保留版权、GPL-3.0、来源提交和修改日期。

按用户要求使用原 Wiki 风格：运行 CSS 将 `:root` 改为 `.co-navigation`，`body > *` 改为页面直接子项；颜色直接读取 `--ui-*` 变量，字体与深浅色状态继承 Wiki。外壳直接复用现有顶栏、页脚和主题切换，宽度沿用首页的 `1200px` 上限、桌面 `2rem` / 手机 `1.25rem` 留白，卡片使用首页同款淡底、`12px` 圆角和 `.15s` 边框悬停反馈。链接仅变主题色，不保留原版缩放、彩色背景或阴影。分类仍复用原版 `20em` 栏宽、两列上限与 flex 换行结构，小屏自然单列。快照 CSS 保持原样。

必要适配还包括：说明从 `data-sub` 伪元素改成可访问的真实文本，以 `.75rem` 展示；每个入口及分类标题使用 Iconify Lucide 线性图标，图标名与链接一同维护，并由 Nuxt 配置扫描加入本地客户端图标包；外链新窗口打开，Wiki 内链使用 NuxtLink。搜索、关键词匹配、结果计数、无结果提示和清空按钮是自行实现的增强，不属于上游已有功能。未新增依赖。

上游 `index.html` 含 Clarity 统计、远程图标 CSS、群聊/联系入口以及计时器、弹窗和更新检查脚本。本次快照只用于来源追溯，不能作为 Wiki 页面直接加载；原 `nav.js` 的 `onclick`、弹窗内容及西邮专属入口不参与武科大页面运行。保留上游文件中的原始资料是为了验证快照一致性，不代表把这些资料推荐给武科大学生。

## 许可与维护

CO 导航上游代码按 GPL-3.0 保存，相关改编保留来源、提交、修改说明及许可声明，不归入项目中其他来源的 MIT 许可。链接所指网站的内容、商标、服务及其他资源仍由各自权利人管理。

更新上游时应选定提交，比较原版变化，重新保存精确快照并更新哈希；不要以运行适配覆盖原文件。导航页面的内容检查、类型检查及实际浏览器验证由 Wiki 项目完成，快照哈希一致只证明来源完整性。
