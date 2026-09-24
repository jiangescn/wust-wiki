# 发现更多：扩充来源

核对日期：2026-09-24。页面数据：`app/data/navigation-extra.ts`。“发现更多”合计 8 类、52 个入口，全导航共 12 类、78 个入口。按用户要求移除“自学与学术”，保留现有 5 个国内 AI 助手并补充 7 个国外产品，新增“软件下载”7 项；在线学习补充“你缺失的那门计算机课”，现有 6 项。

AI 和通用平台使用平台、项目或主办单位的公开页面；“软件下载”的名称及目标 URL 由用户指定，逐项记录公开网页读取结果。学校以外的平台不代表武科大推荐或认证。只验证公开入口及用途，未执行登录、报名、下载或付费操作。

## 本地验证

### 电脑入门课程补充（78 个入口）

- 仅在“在线学习”新增“你缺失的那门计算机课”，直接复用已有卡片及 `lucide:laptop` 图标；全导航现为 78 项，“发现更多”为 52 项。
- 内容检查、原版组件来源检查通过。将本次导航数据同步到既有隔离快照后，类型检查与静态生成均退出 0，生成 106 条路由；日志为 `.cache/navigation-missing-typecheck.log`、`.cache/navigation-missing-generate.log`。此增量验证不包含工作区其他并行任务的后续改动。
- 开发页与静态页均确认标题、用户指定 URL 和图标正常；搜索“电脑入门”只返回该条目，Esc 恢复全部入口。390px 手机视口完整显示名称，无横向溢出。

### 历史验证（77 个入口）

- 本轮直接复用现有卡片、搜索与 Wiki 样式，仅调整分类数据；“自学与学术”及其 5 个入口已移除，AI 助手为 12 项，软件下载为 7 项。
- 全导航 12 类、77 个入口；“发现更多”8 类、51 个入口。分类 ID、目标 URL 无重复；全部图标均存在于本地 Lucide 集合并被现有配置自动收集。
- `pnpm check:content`、`pnpm check:xupt`、隔离快照 `typecheck` 和 `generate` 均通过。构建生成 106 条路由，产物为 `.cache/wiki-navigation-software-20260924/.output/public`。相比上一快照的路由数量变化来自同一工作区独立移除的论坛内容，与本轮导航条目无关。
- 静态页面实际渲染 77 个入口及图标，软件下载名称与 URL 逐项匹配用户输入。搜索“国外”返回 7 项，“软件下载”返回 7 项，“自学与学术”返回空结果；清空按钮和 Esc 正常。
- 桌面及 390px 手机视口检查通过，深浅色显示清晰，无整页横向溢出。新开的静态页面未捕获运行时错误或 hydration 警告。
- 构建仍报告大 chunk、BlogKey 混合导入、BigInt 构建目标及依赖外置等既有警告，详见 `.cache/navigation-software-generate.log`。本轮未提交、推送或部署，外部账号及下载功能未测试。

## 首次扩充验证（68 个入口）

- 继续直接复用现有导航模板、搜索和 Wiki 样式；分类数据增加可选 `icon` 字段，新增分组沿用同一渲染入口。
- 全导航 68 个 URL、12 个分类 ID 唯一；55 个外部入口均有来源。全部条目与分类图标在本地 Lucide 集合中存在，继续由 Nuxt 配置自动收集并打包。
- 内容检查、14 个原组件来源检查、类型检查通过；独立静态构建生成 109 条路由。产物在 `.cache/wiki-navigation-more-20260924/.output/public`，未停止已有开发服务。
- 最终静态浏览器验证了 8 个“发现更多”分类、42 个链接和全导航 68 个实际渲染图标；“图标”“LaTeX”“高数”等关键词搜索、空结果与清空正常。390px 手机布局和深浅色显示无整页溢出，未捕获运行时或 hydration 警告。
- 本轮未提交、推送或发布，外部平台个人账号功能未验证。

# 导航扩展：考试与升学及已移除条目

核对日期：2026-09-24。候选数据：`.cache/navigation-more-study.json`。最初共 2 类、10 项；随后按用户要求移除“自学与学术”整个分组及其 5 个入口（学堂在线、智慧高教、PubScholar、国家社科文献中心、国家图书馆）。下表保留原始来源记录，后 5 项不再出现在页面中。

只读取公开官方页面，未登录、报名、缴费或获取个人信息。以下“已读取”指公开页面内容或官方来源身份得到确认，不代表报名、课程播放、全文下载等业务已测试。

| 条目 | 官方目标 / 来源 | 本次抓取与核对边界 |
| --- | --- | --- |
| 英语四六级 | [CET 官网](https://cet.neea.edu.cn/)，由[中国教育考试网](https://www.neea.edu.cn/)“社会证书考试 / 全国大学英语四、六级考试”链接进入 | 已读取官网公开页面；仅收录公告与报名入口，不写死考试日期或宣称个人报名资格已确认。 |
| 计算机等级考试 | [NCRE 官网](https://ncre.neea.edu.cn/)，由[中国教育考试网](https://www.neea.edu.cn/)“全国计算机等级考试”链接进入 | 已读取考试介绍、考生须知及服务栏目；个人报名与成绩查询未执行。 |
| 研招网 | [中国研究生招生信息网](https://yz.chsi.com.cn/) | 已读取公开首页，包含院校库、招生简章、硕士目录、推免与报名栏目；页脚注明主办单位为教育部学生服务与素质发展中心。未登录。 |
| 教师资格考试 | [NTCE 官网](https://ntce.neea.edu.cn/)，由[中国教育考试网](https://www.neea.edu.cn/)“中小学教师资格考试”链接进入 | 已读取公开页面；具体省份报考资格与安排不在导航中概括或推断。 |
| 中国教育考试网 | [官方首页](https://www.neea.edu.cn/) | 已读取考试项目、考试报名、成绩、证书服务栏目；主办单位为教育部教育考试院。 |
| 学堂在线 | [平台首页](https://www.xuetangx.com/)；[清华大学平台介绍](https://www.tsinghua.edu.cn/jyjx/zxjy/ptjs.htm)；[清华经管课程平台页](https://www.sem.tsinghua.edu.cn/jxxm/zxjyn/kcpt.htm) | 平台首页能返回“XuetangX: Online Courses from Top Universities”标题，但正文是动态页面，抓取器未提取；清华大学官方页面确认平台身份及地址。没有声称所有课程或证书免费。 |
| 智慧高教 | [平台首页](https://higher.smartedu.cn/)；[官方关于网站](https://higher.smartedu.cn/help) | 已读取关于页面，确认教育部主办、课程/教材/虚仿等资源范围；本次主页直接抓取返回前端校验内容，未测试课程跳转或播放。 |
| PubScholar | [平台首页](https://pubscholar.cn/)；[中国科学院文献情报中心上线说明](https://www.las.cas.cn/news/fwcx/202303/t20230327_6717628.html)；[中科院国家天文台平台介绍](https://www.bao.ac.cn/library/xkhfw/pubscholar/) | 已读取中科院官方介绍并确认 HTTPS 平台地址；平台本身返回正确标题但动态正文未提取。不把“公益”解释为所有文献都能下载。 |
| 国家社科文献中心 | [国家哲学社会科学文献中心](https://www.ncpssd.cn/) | 已取得官网公开页面，确认中国社会科学院图书馆承建及期刊、古籍等资源；官网提示域名由 `.org` 调整为 `.cn`，采用当前 `.cn`。全文或下载未测试。 |
| 国家图书馆 | [官方首页](https://www.nlc.cn/web/select.html)；[官方资源介绍例页](https://www.nlc.cn/web/ziyuanfuwu/ziyuantuijian/sjksx/20260603_2653354.shtml) | 搜索工具取得官方主页栏目与读者云门户说明；直接打开正文为动态页面，抓取器未提取。官方资源介绍明确部分资源要求实体读者卡账号，故未宣称免登录全文开放。 |

选择教师资格考试作为第五项考试服务，来源为教育部教育考试院现行直链。没有加入来源或入口未确认的中国人事考试站点，也没有猜测站内报名端点。

图标统一使用项目现有 Lucide 线性图标，已用本地 `@iconify-json/lucide@1.2.131` 的 `icons` 或 `aliases` 校验全部 12 个分类/条目图标引用，无无效名称。10 项 URL 与来源地址均通过 URL 解析，10 个目标互不重复，也不与现有导航 URL 重复；说明文字为 8–10 字。分类与条目均提供 `icon`，供主页面本地打包。

## 编程与开发（2026-09-24）

新增 6 个通用入口，已检查现有 `app/data/navigation.ts` 与 `app/data/navigation-extra.ts`，不重复 PTA 等已收录链接。这里的“官方入口”指平台或项目自身主页，不代表武科大官方推荐。

| 入口 | 来源与确认用途 | 核查边界 |
| --- | --- | --- |
| GitHub | [GitHub 首页](https://github.com/)列出代码协作、仓库、Issues、开源项目等功能。 | 已读取公开首页；未登录或操作仓库。 |
| MDN 中文文档 | [MDN 中文首页](https://developer.mozilla.org/zh-CN/)提供 HTML、CSS、JavaScript 与 Web API 文档及教程。 | 已读取公开首页；中文站也会包含部分英文内容。 |
| CS 自学指南 | [项目首页](https://csdiy.wiki/)列出计算机学习规划、必学工具与课程目录。 | 社区维护的学习指南；未逐一核查课程链接与作业。 |
| 力扣 | [力扣首页](https://leetcode.cn/)展示题库、学习计划、竞赛及面试练习。 | 已读取公开首页；未登录、提交代码或验证会员内容。 |
| 洛谷 | [洛谷首页](https://www.luogu.com.cn/)展示题库规范、评测环境和程序设计竞赛。 | 已读取公开首页；未登录、报名或提交代码。 |
| 清华开源镜像 | [镜像站首页](https://mirrors.tuna.tsinghua.edu.cn/)列出开源软件镜像、软件下载与使用帮助，并说明由清华大学 TUNA 协会维护。 | 文本读取器显示 JavaScript 兼容提示但可读取站点说明与官方域名；未下载软件或测量速度。 |

各条目采用本地 `@iconify-json/lucide` 1.2.131 图标，已验证 `code-xml`、`github`、`file-code-2`、`book-open-check`、`braces`、`trophy`、`hard-drive-download` 均存在。不依赖运行时新增远程图标集合。

### AI 助手

2026-09-24 核实官方公开入口，未测试账号登录、内容上传或付费功能；不固定模型版本，不承诺免费额度。

| 入口 | 官方来源与验证 |
| --- | --- |
| DeepSeek | [官方网站](https://www.deepseek.com/)由 Node fetch 返回200，标题“DeepSeek / 深度求索”，页面直接链接 `https://chat.deepseek.com/`；抓取工具超时不等于网站不可用。 |
| 豆包 | [官方网站](https://www.doubao.com/)跳转[对话入口](https://www.doubao.com/chat/)，标题为字节跳动旗下AI助手，动态正文未展开。 |
| Kimi | [官方网站](https://www.kimi.com/)公开页面有对话输入框、任务与项目入口；未测试账号中的文档。 |
| 腾讯元宝 | [官网](https://yuanbao.tencent.com/)通过Node fetch返回200；[腾讯官方平台](https://ai.tencent.com/platform/)说明问答与创作用途。页面需要JavaScript。 |
| 千问 | [官网](https://www.qianwen.com/)公开标题为“阿里旗下全能AI助手”。 |

# 导航补充：在线工具、设计与写作

核实日期：2026-09-24。对应数据：`.cache/navigation-more-tools.json`。共两组 11 项（6 + 5），采用项目官网、官方帮助中心或官方仓库作为来源。仅补充名称、功能简介、入口及语义图标，不把第三方工具写成武科大官方服务。

| 分类 | 条目与访问入口 | 功能及入口的第一方证据 | 本次网页读取结果 |
| --- | --- | --- | --- |
| 在线工具 | [draw.io](https://app.diagrams.net/) | 官方编辑器页面说明流程图、网络图、UML、ER 图等用途。 | 页面标题与功能说明可读，编辑器依赖 JavaScript。 |
| 在线工具 | [Excalidraw](https://excalidraw.com/) | [官方仓库](https://github.com/excalidraw/excalidraw) 明确链接该编辑器，并说明手绘白板与实时协作。 | 编辑器返回 JavaScript 提示；仓库 README 可读。 |
| 在线工具 | [Desmos](https://www.desmos.com/calculator?lang=zh-CN) | [官方入门指南](https://help.desmos.com/hc/en-us/articles/4406040715149-Getting-Started-Desmos-Graphing-Calculator) 说明函数、点、方程及图形绘制。 | 计算器标题可读，交互内容未被文本读取；官方指南可读。 |
| 在线工具 | [GeoGebra](https://www.geogebra.org/calculator) | [官网](https://www.geogebra.org/) 的 Calculator Suite 条目说明函数、解方程与几何构造，并链接该计算器。 | 计算器标题、登录按钮和数学键盘可读；官网介绍可读。 |
| 在线工具 | [Squoosh](https://squoosh.app/) | 官方页面介绍图片缩小、设置调整与本地处理；[官方源码](https://github.com/GoogleChromeLabs/squoosh) README 说明多格式图片压缩。 | 文件输入与功能说明可读，工具依赖 JavaScript；本次未上传图片。 |
| 在线工具 | [ProcessOn](https://www.processon.com/) | 官网展示流程图、思维导图和多人实时协作，提供登录与价格入口。 | 产品首页可读；没有注册、登录或创建文件。 |
| 设计与写作 | [Overleaf](https://www.overleaf.com/) | 官网说明在线 LaTeX、协作编辑、公式与参考文献，并区分免费与付费功能。 | 首页与产品介绍可读；未注册或创建项目。 |
| 设计与写作 | [Zotero](https://www.zotero.org/) | 官网说明研究资料收集、组织、注释、引用与同步，并给出下载入口。 | 首页与用途说明可读；未下载、登录或同步资料。 |
| 设计与写作 | [Iconify](https://iconify.design/) | 官网提供开源图标集合和开发文档，并链接[图标浏览器](https://icon-sets.iconify.design/)。 | 官网与图标列表可读；图标集使用各自许可。 |
| 设计与写作 | [Yesicon](https://yesicon.app/zh-Hans) | [官网](https://yesicon.app/) 提供图标检索、图标集列表与逐集作者/许可证，并提供简体中文入口。 | 首页、图标分类及简体中文入口可读。 |
| 设计与写作 | [Doocs Markdown](https://md.doocs.org/) | [官方仓库](https://github.com/doocs/md) README 给出同一在线入口，说明 Markdown 转微信图文、排版与导入导出。 | 在线编辑器标题可读，正文为动态应用；仓库 README 可读。 |

## 验证边界

这是 2026-09-24 的公开网页及官方文档核实，不代表已逐个完成编辑、导出、保存、协作或付费能力测试。没有登录账号、提交表单、上传文件、读取个人资料，未执行第三方项目代码。没有根据产品宣传添加性能、稳定性、校园授权或永久免费承诺。

图标字段使用当前项目已有的 `lucide:` 名称，逐项核对本地 `@iconify-json/lucide@1.2.131` 的 `icons` / `aliases`。两组分类图标与 11 个条目图标全部可解析，最终接入与验证结果另列。

分组刻意区分画图用途：draw.io 对应结构图，Excalidraw 对应草图白板，ProcessOn 对应思维导图及协作。Iconify 对应图标开发文档，Yesicon 对应可视化检索；每个链接只出现一次。

## 软件下载（用户指定）

2026-09-24 按用户提供的名称与 URL 原样收录，使用项目已有的 Lucide 图标。下列读取边界不作为页面宣传文案，也不把第三方站点标成软件厂商官网。

| 条目 | 用户指定地址 | 公开页面读取结果 |
| --- | --- | --- |
| Win软件 | <https://lestore.lenovo.com/> | 页面标题为联想应用商店，正文依赖 JavaScript。 |
| 应用推荐 | <https://www.ghxi.com/> | 页面标题为果核剥壳，抓取器未提取正文。 |
| 微软商店解析 | <https://store.rg-adguard.net/> | 页面说明是 Microsoft Store 链接生成工具，可读取链接输入框；没有提交解析。 |
| Win镜像 | <https://www.uupdump.cn/> | 抓取工具无法访问；按用户指定保留原地址，未据此断言网站失效。 |
| 开源镜像 | <https://mirror.nju.edu.cn/> | 抓取工具报告重定向循环；保留用户指定的单数 `mirror` 域名。 |
| Mac软件 | <https://www.digit77.com/> | 公开页显示 Mac 应用及软件资源目录；未下载文件。 |
| JB激活 | <https://3.jetbra.in/> | 页面自述为个人页面，非官方站点；仅收录用户指定入口，未获取或运行激活工具。 |

## 国外 AI 助手补充

保留原有国内产品，同组新增以下 7 项。仅核对公开入口和用途，不固定模型版本、价格或地区可用性。

| 产品 | 对话入口 | 第一方来源与读取边界 |
| --- | --- | --- |
| ChatGPT | <https://chatgpt.com/> | [官方说明](https://chatgpt.com/overview/)：公开对话入口显示 New chat、输入区域与登录入口；官方产品页说明问答、学习、写作与创作用途。 公开页面可读取；未登录或发送对话。 |
| Claude | <https://claude.ai/> | [官方说明](https://claude.com/)：当前 claude.com 官方首页链接 Try Claude 到 claude.ai，并说明文本与代码生成等用途。 对话入口跳转登录页，入口页面抓取标记较旧；用途与入口由本次可读取的当前 claude.com 首页交叉确认，未登录。 |
| Gemini | <https://gemini.google.com/> | [官方说明](https://gemini.google/us/about/?hl=en)：Google 官方 Gemini 产品页的 Try Gemini 指向 gemini.google.com，说明日常任务、对话与内容创作用途。 对话入口文本仅显示登录及 Google apps；用途由官方产品页确认，未登录。 |
| Microsoft Copilot | <https://copilot.microsoft.com/> | [官方说明](https://www.microsoft.com/en-us/edge/copilot)：对话入口可读取 Message Copilot；微软第一方说明页介绍问答、文本草拟、创意构思，并给出 copilot.microsoft.com 入口。 入口文本内容较少；来源 URL 当前重定向至 explore.microsoft.com 同属微软的产品页，未登录或发送对话。 |
| Perplexity | <https://www.perplexity.ai/> | [官方说明](https://www.perplexity.ai/en-GB/hub/products/search)：官方 Search 产品页说明网页搜索、回答来源引用，并提供 Get started with Search 链接至 Perplexity。 首页主要为动态内容，文本读取仅得到图片链接；用途与入口由官方 Search 产品页及官方入门指南交叉确认，未发起查询。 |
| Grok | <https://grok.com/> | [官方说明](https://docs.x.ai/grok/overview)：公开入口显示探索问题提示、登录与注册；xAI 官方 Grok 概览明确给出 grok.com 网页入口，并说明问答、构思与写作用途。 入口和官方概览可读取，未登录或发送对话。 |
| Poe | <https://poe.com/> | [官方说明](https://poe.com/)：官方入口登录页说明可与多种 AI 对话，并列出多个模型与助手。 公开入口跳转 Poe 登录页，未登录或验证具体模型可用性。 |

## 在线学习补充：你缺失的那门计算机课

2026-09-24 按用户提供的地址收录至“在线学习”，保留完整标题与原始 URL。第一方课程首页介绍其为电脑使用入门课程，内容包含文件管理、软件寻找与安装、电脑维护、Office 和浏览器使用；导航简介为“电脑入门与实用技巧”，图标沿用本地 `lucide:laptop`。

| 条目 | 目标地址与第一方来源 | 公开页面读取边界 |
| --- | --- | --- |
| 你缺失的那门计算机课 | [课程首页](https://www.criwits.top/missing/) | 已读取首页标题、课程介绍与内容范围；未逐章验证操作步骤，也未下载或运行教程涉及的软件。 |
