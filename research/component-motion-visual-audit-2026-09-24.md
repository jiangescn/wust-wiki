# WUST Wiki / 博客组件、动效与视觉优化研究

日期：2026-09-24。

## 范围与判断方式

本轮研究对象是当前仓库的 WUST Wiki，以及接入的 blog-v3 正文和 Coder 页面。目标是寻找值得封装的内容组件、能解释状态变化的动画、以及有收益的视觉调整；不把“研究一下”扩展为重写页面或上线发布。

“当前事实”指本轮阅读的源码、实际浏览器观察或官方技术文档；“设计建议”指待比较、验证的改进方向，并不表示现有页面存在缺陷。校园正文、联系人和出处等内容事实不在本轮补全。

## 已有能力：避免重复建设

- blog-v3 已迁入 27 个正文组件，包含标签、折叠、时间线、图片灯箱、代码复制与展开、友链、Mermaid、乐谱等。新增需求先检查这些组件的插槽和数据接口，运行副本在 `app/clarity/`，追溯快照在 `vendor/blog-v3/`。来源：[迁移说明](../vendor/blog-v3/README.md)、[组件目录](../app/clarity/components/)。
- Coder 继续使用西邮原版 `BlurCard`、`LabItem`、`BlogCard` 和列表排序动画。新筛选或展示组件应装配这些原件，不能把已有翻面、复制和排序再次列为“待实现”。来源：[项目 README](../README.md)、[原版组件目录](../app/xupt/components/)。
- 全站已有 Nuxt 页面淡入：进入为 180ms 不透明度/6px 位移，离开为 100ms 不透明度变化；另有减少动态效果规则。来源：[app.vue](../app/app.vue)、[app.css](../app/app.css)。
- `WikiMotion` 已提供 220ms 高度衔接和 160ms 内容淡入；不复制或重新挂载插槽内容，并响应系统减少动态效果偏好。培养方案目录的筛选已明确关闭整体高度动画、淡入起点为 0.85。来源：[WikiMotion.vue](../app/components/WikiMotion.vue)、[CurriculumDirectory.vue](../app/components/content/CurriculumDirectory.vue)。
- 原生折叠内容已按 `interpolate-size` 支持情况渐进增强，培养方案版本折叠使用 `flat-more curriculum-more` 双类名接入。来源：[app.css](../app/app.css)、[CurriculumDirectory.vue](../app/components/content/CurriculumDirectory.vue)。
- 现有依赖包含 Vue 3.5.42、Nuxt 4.5.2、Nuxt UI 4.11.1、VueUse 14.4.0。本轮提及的基础动画与交互可以优先在现有栈内完成。版本事实来自 [package.json](../package.json)，不代表建议升级。

## 候选组件与页面优先级

结论：第一批优先做 **成绩展示共用、目录筛选与结果状态统一、手机首屏布局**。现有组件和动画已经较丰富，主要收益来自让已有能力覆盖真实业务，并让内容更容易找到。

优先级 P1 为第一批，P2 为后续精修，P3 为有明确需求再做。成本为相对判断，不是工期承诺。以下名称为建议名称，尚未创建。

| 候选 | 具体位置与当前依据 | 建议形态与用户收益 | 复用分类 | 顺序 / 成本 |
| --- | --- | --- | --- | --- |
| `GradeResults` 成绩展示 | [真实查询](../app/components/content/GradeQuery.vue) 第 25–39 行；[展示样例](../app/components/content/GradeDisplayPrototype.vue) 第 54–78 行 | 真实查询仍是 7 列横向表格，样例已有桌面表格、手机课程卡片和详情弹窗。两者共用展示层，手机先显示课程、成绩、学分/绩点，次要字段进详情。 | 提炼现有样例，必要适配真实数据，直接复用 `UModal`、`WikiMotion`。 | **P1 / 中** |
| `DirectoryToolbar` 筛选工具条 | [竞赛](../app/components/content/CompetitionDirectory.vue) 第 40–49 行；[培养方案](../app/components/content/CurriculumDirectory.vue) 第 31–39 行；[美食](../app/components/content/FoodDirectory.vue) 第 191–201 行；[导航](../app/pages/navigation.vue) 第 38–51 行 | 统一搜索、筛选、结果数、清空的布局与尺寸。多个条件时可显示可删除的条件标签；培养方案继续保持简洁。查询规则留在各业务页，控件用插槽装配。 | 自行提炼业务布局，优先装配现有 `UInput/USelect/UButton`；不制作万能表单引擎。 | **P1 / 中** |
| `DirectoryState` 结果状态 | [竞赛](../app/components/content/CompetitionDirectory.vue) 第 51 行；[培养方案](../app/components/content/CurriculumDirectory.vue) 第 43 行；[美食](../app/components/content/FoodDirectory.vue) 第 176–177、203–209 行；[导航](../app/pages/navigation.vue) 第 85–88 行 | 统一“标题 + 简短原因 + 当前可做的操作”。无匹配给清除条件，加载失败给重试；暂无资料与搜索无结果保持不同语义。真实请求加载复用骨架，静态筛选不伪造等待。 | 提炼现有状态布局；复用 `UEmpty/USkeleton/UButton`，不接管请求状态机。 | **P1 / 低** |
| `ExpandControl` 展开控件 | [真实成绩](../app/components/content/GradeQuery.vue) 第 39 行；[样例](../app/components/content/GradeDisplayPrototype.vue) 第 70 行；[绩点](../app/components/content/GradeGpaCalculator.vue) 第 42 行 | 三处同类箭头和展开按钮可共用，统一计数、焦点、`aria-expanded/aria-controls`。加载下一批数据与展开已有内容仍分开。 | 提炼现有控件；继续使用现有箭头旋转和高度动画。 | **P1 / 低** |
| `DocumentResource` 文件与版本行 | [培养方案](../app/components/content/CurriculumDirectory.vue) 第 52–58、62–68 行，两处分支重复文件标题、版本、查看/下载规则 | 将文档格式、版本、查看/下载动作组合成清晰文件行，保留外围专业卡片和版本折叠。同一文件有多个动作，独立业务组件比普通单链接卡片更合适。 | 自行提炼业务组件；直接使用现有归档数据，不重写文件服务。 | **P2 / 低** |
| `ArticleEntryList` 文章列表 | [首页](../app/pages/index.vue) 第 27–30 行；[全部文章](../app/pages/articles.vue) 第 7 行 | 共用标题、日期、草稿标识；全部文章可增加既有栏目分组和搜索。首页最近更新仍保持 5 条。仅抽模板收益有限，应和文章查找体验一起做。 | 提炼现有列表；保持首页 15 个入口和路径。 | **P2 / 低至中** |
| `SourceNote` 内容依据说明 | [竞赛正文](../content/2.study/7.contest.md) 第 10–12 行已有版本提示；[快递正文](../content/3.life/4.delivery.md) 第 36 行起已有来源段；[周边正文](../content/3.life/6.nearby.md) 有来源说明 | 按维护者实际填写内容，紧凑展示资料版本、适用范围和来源。长来源可以折叠，帮助读者辨别往届资料。`updated` 不能自动解释成“已核实”。 | 装配现有 `WikiCallout/BlogAlert/BlogFolding`，不另做一套提示框。 | **P2 / 中，含内容整理** |
| `GuideChecklist` 办事准备清单 | [入学办理](../content/1.campus/4.enrollment.md) 中入学准备、材料移交和各类卡办理；当前以长段落、Tab、Folding 为主 | 若需要“带齐哪些材料 / 哪些事项已完成”，可增加可勾选清单与可选说明。只用于确实存在多个事项的攻略；纯阅读顺序继续用现有列表/时间线。 | 新业务组合，复用 Nuxt UI Checkbox/Stepper 和原正文组件；内容须由维护者确认。 | **P3 / 中** |

组件接口的取舍：`GradeResults` 只接收适配后的展示数据并发出选中事件；`DirectoryToolbar` 只管理控件布局和输入；`DirectoryState` 只展示状态及操作。不要把登录、网络请求、教务数据缓存或 GPA 计算搬入这些视觉组件。真实成绩的补重学期、考试性质、备注、非数值成绩必须保留，不能用虚构样例的简化数据模型覆盖正式数据。

`GuideChecklist` 是可选的新能力，默认不保存用户的办理状态，也不采集个人资料；如将来需要跨刷新保存，应单独定义保存与清除行为。本轮没有核实或修改入学政策。

已有的 `SchoolAcademicQuery` 已共享成绩/课表扫码，`ScheduleBoard` 已共享正式/样例课表；普通文档也已有手机“本页目录”。这些无需新增第二套组件。

## 浏览器观察与视觉优化

本轮使用运行中的开发预览 **http://127.0.0.1:3017/**，未启动新服务。检查对象是带有既存未提交更改的当前工作区，不是线上发布版本。

| 页面 / 检查方式 | 本轮实际观察 | 设计建议与边界 |
| --- | --- | --- |
| 首页，桌面 | 标题、15 个入口、最近更新构成清晰结构；入口以较大的低透明度 emoji 作背景，当前 hover 主要改变边框。 | 保留结构、顺序和 emoji。统一 hover/focus 的边框与轻阴影即可；如需更鲜明的首页，可把主按钮/标题蓝色的使用层次整理一致。无需再添加口号或背景粒子。 |
| `/study/status`，390×844 | 本科默认展示 22 个学院索引，手机上连续换行；首个专业卡片位于首屏底部附近。 | **P1：仅将手机学院索引改为可折叠的“定位学院”，或紧凑的可搜索定位菜单**，选择后仍跳到下方原有分组。保留用户已确定的平铺专业卡片，不能改回学院选择式目录。入口见 `CurriculumDirectory.vue:40–42`。 |
| `/blog-components`，桌面与390×844 | 手机把完整目录、正文提取的侧栏块和链接卡排在文章前，首屏看不到正文。桌面侧栏结构正常。 | **P1：手机目录默认折叠，辅助侧栏内容移到正文后或单独折叠**；维持具名插槽和许可内容。修改示例布局即可，不用动 27 个原正文组件。入口见 `app/pages/blog-components.vue:24–26,38–39`。 |
| `/study/grades?grades=sample`，桌面与390×844 | 样例的汇总、筛选和手机课程卡片可正常呈现；点击“高等数学 A（二）”打开已有详情弹窗。 | **P1：把已经可用的样例展示用于真实成绩**，优先补齐数据适配。真实登录与真实数据结果未执行，本轮“正式版是7列表格”的判断来自源码。 |
| `/study/curriculum?schedule=sample`，390×844 | 手机默认按日列表；切换周二后显示对应样例课程。页面标题、说明、章节标题、样例说明和工具容器连续占用较多纵向空间。 | **P2：工具页采用较紧凑的顶部间距与说明布局**，让操作栏更靠前；正文攻略页保持正常阅读节奏。样例说明和来源不得删除，真实查询首屏需另行验证。 |
| `/study/contest`，1440×1000、浅色/深色 | 搜索可变为 0 结果，已有文字说明；重置后恢复 253 项。界面已有筛选栏、类别标识和折叠条目。 | **P1：统一筛选/状态组件**，无结果可把“清除条件”操作同时放在结果区；不要宣称当前没有重置按钮。深色卡片可用表面色差和细边框强化层次，无需加重阴影。 |
| `/navigation`，桌面 | 页面已有紧凑双列分组、搜索框、入口说明。 | **P2：统一搜索控件高度与输入反馈，静态强调命中词**；保留 CO 导航的分组和多栏形式。暂无证据需要改成大卡片墙。 |
| `/campus/accommodation`，桌面 | 原博客卡片、标题锚点和 Wiki 查询框共处正文；三张区域卡片在观察宽度下为两列，第三张占下一行。 | **P2：针对信息关系选合适列数**：此类三项并列短卡，在足够宽度可尝试三列、窄屏单列；只做页面级适配。不同组件的边框、阴影与文字灰度可通过语义主题变量协调，避免全局覆盖原卡片。 |
| `/coder/blog?shuffle=false`，桌面 | 头像加载完成后六个博客卡片正常出现；早期瞬时空白不能当成图片永久失效。 | 保留原版卡片和随机排序。可考虑加载失败时的头像回退、键盘焦点和触屏链接可见性；实际网络失败和触屏翻面未测试。 |

视觉统一建议：先统一 **控件高度、卡片与控件圆角、边框强度、主要/次要/辅助文字层次、区块间距**。现有培养方案明确采用卡片 12px、控件 6px，可作为自有业务组件的起点；迁移来的原版正文和 Coder 动画需保持来源约定，通过 Wiki 适配层调整。不要用全站统一圆角或通配选择器强行覆盖所有原件。

正文排版的下一步可比较标题前蓝色锚点标记的显著度、段落行长与表格密度，但本轮未做阅读速度或对比度量化测试，不能据截图断言不合格。桌面右侧长目录标题有截断，可以先确认完整标题提示和点击识别，再决定是否加宽；手机已有原生目录，应直接复用。

## 动画：新增位置与建议参数

以下时长为待验证的设计建议，不是测量结果。优先使用当前 CSS/Vue/`WikiMotion`，无须添加 GSAP、Lottie 等依赖。

| 位置 | 建议反馈 | 复用及限制 | 顺序 |
| --- | --- | --- | --- |
| 成绩、竞赛的筛选结果 | 结果区 120–160ms、透明度约 0.88→1；即使条数不变也能看出内容已换。 | 复用 `WikiMotion` 的 key 淡入，只包结果，输入框不闪。连续输入时可合并动画触发，数据过滤仍即时；不重挂载查询组件。 | P1 |
| 导航搜索结果 | 120–160ms 轻淡入，命中词用静态颜色/字重强调。 | 当前 CO 布局使用 CSS columns，不建议直接给分组加跨列移动动画，不插值整页高度。入口 `navigation.vue:54,70`。 | P1 |
| 本科/研究生、课表视图等分段选择 | 选中底板约 140–180ms 滑到新项，当前文本保持清晰。 | 先复用 Nuxt UI Tabs indicator；需要按原语义选择正确控件，不能为动效改变键盘行为。课表正文已有淡入，不再叠方向滑动。 | P2 |
| 首页入口 | hover/focus 的边框与轻阴影；鼠标可选上移 2px、150ms。 | 位移仅用于精确指针，触屏用按压底色；键盘焦点同样清晰。保留 15 入口原顺序。入口 `app/app.css:31–35`。 | P2 |
| 培养方案学院定位 | 定位后标题一次淡底色强调，约 500–700ms，说明已跳到哪里。 | 优先原生锚点与 `:target`；不让整组卡片闪光。减少动态效果时用静态目标边框。 | P2 |
| 原博客 Tab / Folding | 确有需求时，内容区约 120–160ms 淡入，折叠继续渐进增强。 | 只做必要适配并更新迁移记录；保留 `v-show` 等状态语义，不能销毁图表、音乐或输入状态。 | P3 |

不建议：所有正文滚动入场、长目录逐条错时浮现、常驻漂浮 logo、鼠标追光铺满页面、绩点数字滚动、再叠一套全页转场。现有首页/文档的阅读任务更需要稳定内容与快速定位。

## 实施前需复核的源码风险

这些是有依据的待验证项，不是本轮已经复现的故障。

1. **减少动态效果的覆盖范围。** `app/app.css:53` 的通配符 `transition:none!important` 与 `vendor/blog-v3/styles/animation.scss:21,31` 中更具体的 `.float-in-*` 的 `!important` 规则存在级联竞争；`app/clarity/components/FeedGroup.vue:48` 使用该 TransitionGroup。需实测 reduced-motion 的计算样式与排序行为，再在适配层加精确覆盖。现有 JavaScript 动画也要单独取消，不能仅靠 CSS。
2. **嵌套高度动画。** `CompetitionDirectory.vue:39` 外层 `WikiMotion` 与 `app/app.css:12–19` 的原生 details 内容高度动画可能同时响应一次展开；`WikiMotion.vue:29–40` 每次 ResizeObserver 更新会取消并重启动画。应录制连续展开/收起的表现，必要时只保留一个高度动画负责者；本轮没有性能轨迹，不能宣称已经卡顿。
3. **Coder 的键盘等效操作。** `LabItem.vue:14` 和 `BlurCard.vue:80` 主要依赖 hover；项目的 `MajorCards.vue:13,44–49`、`GroupDirectory.vue:62–73` 已有可参考的 `tabindex/focus-within` 适配。`WustBlogList.vue:18` 的排序入口是点击 Icon，可用原生按钮外壳补键盘语义。优先沿用现有翻面，不另造翻面按钮。
4. **博客附加链接的可发现性。** `BlogCard.vue:121,138` 默认隐藏附加链接并在 hover 显示，可在装配层补 focus-within；触屏是否常显实际存在的入口需实测。空的 GitHub/RSS 字段仍为空，不能用虚构入口填版面。

## 建议实施顺序与本轮交付

1. **第一批：阅读与操作收益。** 调整两个手机首屏布局；共享真实/样例成绩展示；统一目录工具条与空状态；复核焦点和减少动态效果。
2. **第二批：反馈与一致性。** 局部筛选淡入、分段控件选中反馈、文件版本行与展开按钮；协调自有组件的尺寸、边框和间距。
3. **第三批：内容驱动的新能力。** 全部文章分类检索、内容依据说明、确有需要的办事清单。阅读进度和共享元素转场放在具体需求之后。

本轮仅新增本研究文档；未修改页面实现、依赖、数据或既有未提交更改，未推送/部署。浏览器检查了上表页面，以及样例课程详情、日课表切换、竞赛搜索/重置；课表与成绩使用虚构样例，未执行真实教务登录。未进行全站性能分析、真实手机触摸测试、减少动态效果实测或完整交互回归。

仅研究文档变动，因此未运行应用构建与类型检查；这些检查应在后续实施时按修改范围执行。源码行号为本轮快照，后续变更可能移动。

## 技术依据与适合本项目的做法

### 1. 小型状态切换优先沿用 Vue 与现有 WikiMotion

Vue `Transition` 面向元素进入、离开及互斥状态；其文档明确区分高效的 `transform`/`opacity` 与会引发布局计算的 `height`/`margin`。本项目已存在高度动画，建议只在局部结果区、展开区使用；大量目录过滤继续沿用轻淡入，不为整页高度变化增加动画。来源：[Vue Transition](https://vuejs.org/guide/built-ins/transition.html#performance-considerations)。

**设计建议：**统一交互反馈的时长与曲线，复用现有 160–220ms 范围。复制成功标记、局部空结果提示、选中项变化可以使用短淡入或图标状态替换；业务结果立即更新，动画仅承担反馈。160–220ms 是本项目可复用的现状，不是通用规范要求。

**反例：**为了交叉淡入给整个教务查询组件添加变化的 `key`；这可能导致重新挂载、丢失输入/查询状态。需要变化的通常只是显示层，不应把登录或网络请求生命周期交给动画管理。

### 2. 列表动画用于保留位置感，不用于装饰每一条数据

Vue `TransitionGroup` 原生支持列表元素的新增、移除与重排，并要求每项有唯一 `key`；移动动画需要与退场布局协同。来源：[Vue TransitionGroup](https://vuejs.org/guide/built-ins/transition-group.html)。

**设计建议：**少量卡片的筛选/排序可以采用原组件已有的列表移动方案；如果是数十乃至数百条目录，每次输入只做结果区轻淡入或无动画更新。长列表是否需要移动动画，应以真实条目数量、手机设备和连续输入时的性能实测决定。

**反例：**使用数组下标当业务身份；所有结果每次输入都从屏幕外飞入；逐条延迟叠加到数秒；为了动画延后显示检索结果。

### 3. 新业务组件装配现有 UI 原件

本地已安装的 Nuxt UI 4.11.1 源码包含 `Accordion`、`Tabs`、`Stepper`、`Skeleton`、`Empty` 等组件。其中 `Tabs` 已有 indicator 和具名内容插槽，`Stepper` 支持横纵方向与受控步骤，`Empty` 接受标题、说明、操作和加载状态；`Accordion` 默认 `unmountOnHide: true`，不能在需要保留查询状态的面板上忽略这一点。

来源：本轮读取的 `node_modules/@nuxt/ui/dist/runtime/components/{Tabs,Stepper,Skeleton,Empty,Accordion}.vue`，上游为 [Nuxt UI 官方仓库](https://github.com/nuxt/ui)。官方组件文档页面本轮抓取失败，因此具体接口判断以本地锁定版本源码为准，不据较新文档承诺本地能力。

**设计建议：**

- 办事流程或入学步骤若需要“当前步骤”和切换，装配 `UStepper`；只需阅读顺序时直接使用现有 `BlogTimeline`/列表，不强迫用户逐步点击。
- 真实异步数据区的加载占位可以由 `USkeleton` 构造，并使占位形状接近最终布局；静态正文和即时过滤没有必要伪造加载。
- 无结果、待登录、请求失败等状态可以统一视觉结构，但保留各自明确的说明和操作，不能用一个大插画遮蔽原始错误。
- 筛选框、分组切换和结果数量若在多个目录中重复，可以抽出轻量布局与控件组合；数据过滤规则继续留在业务模块。

### 4. 减少动态效果覆盖 CSS 和 JavaScript 两条路径

`prefers-reduced-motion` 表达用户希望移除、减少或替代非必要运动的系统偏好；缩放和平移大面积内容可能造成不适。来源：[MDN prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion)。

**设计建议：**保留现有全局 CSS 降级，以及 `WikiMotion` 对 `matchMedia` 和偏好变化事件的处理。将来新增 Web Animations API、Canvas 或滚动监听动效时，分别检查其启动、取消和静态终态，不能假设全局 `animation:none` 会取消 JavaScript 创建的动画。

**反例：**减少动态效果模式只是把时长改为极短但仍保留大幅翻转；取消动画后元素停在 `opacity:0`；只有悬停才出现关键链接，手机或键盘用户无法触发。

### 5. 滚动驱动动画只做渐进增强

CSS 滚动驱动动画可以把进度绑定到滚动或元素在视口中的位置；本轮 MDN 对 `animation-timeline` 仍标为 Limited availability。来源：[MDN 滚动驱动动画](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Scroll-driven_animations)、[MDN animation-timeline](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/animation-timeline)。

**设计建议：**若长文确实需要阅读进度，可做细进度线或目录当前位置提示；先评估现有目录是否已经满足需求。采用 `@supports`，支持不足时保留正常阅读、目录与锚点跳转。若做单次入场提示，内容初态应可读，不应等待脚本运行后才显示。

**反例：**正文各段持续视差、整页滚动劫持、滚动时不断改变文字透明度、将内容可见性依赖于某个浏览器特性。

### 6. View Transition 属于备选研究，不是本轮默认方案

View Transition API 提供 DOM 状态或页面之间的视图转换；`document.startViewTransition()` 针对同文档视图，本轮 MDN 标为 Baseline 2025，并提示老版本浏览器仍可能不支持，官方示例保留即时更新回退。来源：[MDN View Transition API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API)、[MDN startViewTransition](https://developer.mozilla.org/en-US/docs/Web/API/Document/startViewTransition)。

**设计建议：**只有在确有“卡片进入详情”等共享视觉对象需求时再做隔离原型，并测量焦点、返回位置与连续点击。当前全站已经有 Nuxt 过渡，不宜为追求新 API 同时叠加另一套全页动画。主题切换的圆形揭幕、整页截图变形等应排在内容与布局优化之后。

## 后续落地验证边界

本轮技术建议未新增运行依赖。实现时按选定页面验证，而不是一次性重写组件库：

1. 检查桌面与 390px 手机视口、浅色和深色；包含长标题、缺失图片、无结果、多结果。
2. 检查鼠标、键盘、触摸等效操作；焦点不丢失，关键内容不依赖 hover，动效结束后内容可读。
3. 检查普通与减少动态效果两种系统偏好，及浏览器缺少新 CSS/API 的降级。
4. 连续输入过滤、快速切换、取消请求、展开/折叠时，确认不会重新登录、重复请求或丢失已加载结果。
5. 若修改共享排版/主题，回归普通正文、完整博客示例、首页与 Coder；维护迁移清单的实际一致性声明。

上述为后续实施验收建议，不代表本轮已执行这些验证。
