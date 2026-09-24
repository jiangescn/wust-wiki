import type { NavigationCategory } from './navigation'

// Existing Wiki routes; descriptions describe the destination, not an official service.
export const wikiLifeCategory: NavigationCategory = {
  id: 'wiki-life',
  title: '武科大生活',
  links: [
    { title: '住宿生活', icon: 'lucide:bed-double', description: '宿舍信息与寝室查询', url: '/campus/accommodation', keywords: ['寝室', '沁湖'] },
    { title: '吃在武科', icon: 'lucide:utensils', description: '食堂菜单与公开评价', url: '/life/food', keywords: ['美食', '食堂', '南苑', '北苑'] },
    { title: '武科大俱乐部', icon: 'lucide:users-round', description: '校园社团与兴趣小组', url: '/coder', keywords: ['社团', '实验室'] },
    { title: '兴趣群', icon: 'lucide:messages-square', description: '同好交流与兴趣社群', url: '/life/groups', keywords: ['QQ群'] },
    { title: '校友博客', icon: 'lucide:notebook-pen', description: '看看大家在写什么', url: '/coder/blog' },
    { title: '快递与外卖', icon: 'lucide:package', description: '收货地址与取件指南', url: '/life/delivery' },
    { title: '入学准备', icon: 'lucide:luggage', description: '新生报到与校园生活', url: '/campus/enrollment', keywords: ['迎新'] },
    { title: '手机必备 APP', icon: 'lucide:smartphone', description: '学习与生活应用', url: '/campus/apps', keywords: ['武科大助手', '今日校园', '完美校园'] },
  ],
}

export const navigationExtras: NavigationCategory[] = [
  {
    id: 'wiki-study',
    title: 'Wiki 查询',
    icon: 'lucide:search',
    links: [
      { title: '课程安排', icon: 'lucide:calendar-range', description: '扫码查询与周课表', url: '/study/curriculum', keywords: ['课表', '上课'] },
      { title: '成绩与绩点', icon: 'lucide:chart-no-axes-combined', description: '成绩查询与绩点计算', url: '/study/grades', keywords: ['GPA', '学分', '查分'] },
      { title: '培养方案', icon: 'lucide:route', description: '按学院与专业查阅', url: '/study/status', keywords: ['本科', '研究生'] },
      { title: '本科专业', icon: 'lucide:layers', description: '学院分类与专业目录', url: '/campus/major' },
      { title: '竞赛与证书', icon: 'lucide:trophy', description: '竞赛目录与类别筛选', url: '/study/contest', keywords: ['比赛'] },
    ],
  },
  {
    id: 'online-learning',
    title: '在线学习',
    icon: 'lucide:monitor',
    links: [
      { title: '学习通', icon: 'lucide:notebook-tabs', description: '课程与在线作业', url: 'https://i.chaoxing.com/', source: 'https://i.chaoxing.com/', keywords: ['超星'] },
      { title: 'U 校园', icon: 'lucide:languages', description: '外语学习平台', url: 'https://u.unipus.cn/', source: 'https://u.unipus.cn/', keywords: ['U校园', '英语'] },
      { title: '中国大学 MOOC', icon: 'lucide:book-open', description: '高校公开课程', url: 'https://www.icourse163.org/', source: 'https://www.icourse163.org/', keywords: ['慕课'] },
      { title: '雨课堂', icon: 'lucide:presentation', description: '课堂互动与学习', url: 'https://www.yuketang.cn/', source: 'https://www.yuketang.cn/' },
      { title: 'PTA', icon: 'lucide:code-xml', description: '程序设计练习', url: 'https://pintia.cn/', source: 'https://pintia.cn/', keywords: ['编程', '程序设计'] },
      { title: '你缺失的那门计算机课', icon: 'lucide:laptop', description: '电脑入门与实用技巧', url: 'https://www.criwits.top/missing/', source: 'https://www.criwits.top/missing/', keywords: ['电脑入门', '计算机基础', '文件管理', '软件安装', 'Windows', '新手'] },
    ],
  },
  {
    id: 'exam-study',
    title: '考试与升学',
    icon: 'lucide:clipboard-check',
    links: [
      { title: '英语四六级', icon: 'lucide:languages', description: '报考通知与成绩查询', url: 'https://cet.neea.edu.cn/', source: 'https://www.neea.edu.cn/', keywords: ['CET', 'CET4', 'CET6', '英语', '四级', '六级'], note: '教育部教育考试院的四六级考试官网；报名时间与资格以学校和考试公告为准。' },
      { title: '计算机等级考试', icon: 'lucide:laptop', description: '考试大纲与报考服务', url: 'https://ncre.neea.edu.cn/', source: 'https://www.neea.edu.cn/', keywords: ['NCRE', '计算机二级', '计算机三级', '计算机四级', '证书'], note: '全国计算机等级考试官网；报名需按所在省级承办机构公布的流程办理。' },
      { title: '研招网', icon: 'lucide:graduation-cap', description: '考研、推免与招生目录', url: 'https://yz.chsi.com.cn/', source: 'https://yz.chsi.com.cn/', keywords: ['考研', '研究生', '硕士', '博士', '推免', '调剂', '中国研究生招生信息网'], note: '教育部学生服务与素质发展中心主办；公开资讯可浏览，报名等个人业务需登录。' },
      { title: '教师资格考试', icon: 'lucide:presentation', description: '教资报考与考试大纲', url: 'https://ntce.neea.edu.cn/', source: 'https://www.neea.edu.cn/', keywords: ['NTCE', '教资', '教师资格证', '笔试', '面试'], note: '中小学教师资格考试官网；具体报考条件、时间及考区安排以省级公告为准。' },
      { title: '中国教育考试网', icon: 'lucide:badge-check', description: '考试报名与证书查询', url: 'https://www.neea.edu.cn/', source: 'https://www.neea.edu.cn/', keywords: ['教育部教育考试院', '成绩', '证书', '雅思', '托福', '日语', 'JLPT', 'PETS'], note: '教育部教育考试院主办；各考试报名、成绩与证书服务从站内官方入口进入。' },
    ],
  },
  {
    id: 'developer',
    title: '编程与开发',
    icon: 'lucide:code-xml',
    links: [
      { title: 'GitHub', icon: 'lucide:github', description: '开源项目与代码协作', url: 'https://github.com/', source: 'https://github.com/', keywords: ['开源', 'Git', '代码', '仓库', '开发'] },
      { title: 'MDN 中文文档', icon: 'lucide:file-code-2', description: '网页开发文档与教程', url: 'https://developer.mozilla.org/zh-CN/', source: 'https://developer.mozilla.org/zh-CN/', keywords: ['前端', 'HTML', 'CSS', 'JavaScript', 'Web', '文档'] },
      { title: 'CS 自学指南', icon: 'lucide:book-open-check', description: '计算机课程与自学路线', url: 'https://csdiy.wiki/', source: 'https://csdiy.wiki/', keywords: ['计算机', '编程', '公开课', 'CS61A', 'CS61B', '自学'], note: '开源社区维护的课程索引与学习经验，不代表学校培养方案。' },
      { title: '力扣', icon: 'lucide:braces', description: '算法练习与面试题库', url: 'https://leetcode.cn/', source: 'https://leetcode.cn/', keywords: ['LeetCode', '算法', '刷题', '面试', '数据结构'] },
      { title: '洛谷', icon: 'lucide:trophy', description: '程序设计题库与竞赛', url: 'https://www.luogu.com.cn/', source: 'https://www.luogu.com.cn/', keywords: ['算法', '编程', '刷题', 'OI', 'ICPC', '竞赛'] },
      { title: '清华开源镜像', icon: 'lucide:hard-drive-download', description: '开源软件镜像与下载', url: 'https://mirrors.tuna.tsinghua.edu.cn/', source: 'https://mirrors.tuna.tsinghua.edu.cn/', keywords: ['TUNA', 'Linux', '软件源', '镜像站', '下载'] },
    ],
  },
  {
    id: 'ai-assistants',
    title: 'AI 助手',
    icon: 'lucide:sparkles',
    links: [
      { title: 'DeepSeek', icon: 'lucide:brain-circuit', description: '对话与学习辅助', url: 'https://chat.deepseek.com/', source: 'https://www.deepseek.com/', keywords: ['AI', '人工智能', '深度求索', '编程'] },
      { title: '豆包', icon: 'lucide:message-circle', description: '日常问答与创作', url: 'https://www.doubao.com/chat/', source: 'https://www.doubao.com/', keywords: ['AI', '人工智能', '字节'] },
      { title: 'Kimi', icon: 'lucide:moon', description: '对话与文档阅读', url: 'https://www.kimi.com/', source: 'https://www.kimi.com/', keywords: ['AI', '人工智能', '月之暗面', '文档'] },
      { title: '腾讯元宝', icon: 'lucide:bot', description: '智能问答与写作', url: 'https://yuanbao.tencent.com/', source: 'https://yuanbao.tencent.com/', keywords: ['AI', '人工智能', '腾讯'] },
      { title: '千问', icon: 'lucide:wand-sparkles', description: '通用智能助手', url: 'https://www.qianwen.com/', source: 'https://www.qianwen.com/', keywords: ['AI', '人工智能', '通义', '阿里', 'Qwen'] },
      { title: 'ChatGPT', icon: 'lucide:message-square-text', description: '智能问答与内容创作', url: 'https://chatgpt.com/', source: 'https://chatgpt.com/overview/', keywords: ['AI', '人工智能', '国外', '海外', 'OpenAI', 'GPT'] },
      { title: 'Claude', icon: 'lucide:sun', description: '文本写作与编程辅助', url: 'https://claude.ai/', source: 'https://claude.com/', keywords: ['AI', '人工智能', '国外', '海外', 'Anthropic', '编程'] },
      { title: 'Gemini', icon: 'lucide:sparkle', description: '谷歌智能问答与创作', url: 'https://gemini.google.com/', source: 'https://gemini.google/us/about/?hl=en', keywords: ['AI', '人工智能', '国外', '海外', 'Google', '谷歌'] },
      { title: 'Microsoft Copilot', icon: 'lucide:panels-top-left', description: '微软智能问答与创作', url: 'https://copilot.microsoft.com/', source: 'https://www.microsoft.com/en-us/edge/copilot', keywords: ['AI', '人工智能', '国外', '海外', '微软'] },
      { title: 'Perplexity', icon: 'lucide:search-check', description: '联网搜索与来源引用', url: 'https://www.perplexity.ai/', source: 'https://www.perplexity.ai/en-GB/hub/products/search', keywords: ['AI', '人工智能', '国外', '海外', '搜索', '引用'] },
      { title: 'Grok', icon: 'lucide:orbit', description: '问题解答与内容创作', url: 'https://grok.com/', source: 'https://docs.x.ai/grok/overview', keywords: ['AI', '人工智能', '国外', '海外', 'xAI'] },
      { title: 'Poe', icon: 'lucide:messages-square', description: '多种模型与助手对话', url: 'https://poe.com/', source: 'https://poe.com/', keywords: ['AI', '人工智能', '国外', '海外', 'Quora', '多模型'] },
    ],
  },
  {
    id: 'online-tools',
    title: '在线工具',
    icon: 'lucide:wrench',
    links: [
      { title: 'draw.io', icon: 'lucide:workflow', description: '流程图与系统结构图', url: 'https://app.diagrams.net/', source: 'https://app.diagrams.net/', keywords: ['diagrams.net', '流程图', 'UML', '数据库', '拓扑图'] },
      { title: 'Excalidraw', icon: 'lucide:pencil-ruler', description: '手绘风格协作白板', url: 'https://excalidraw.com/', source: 'https://github.com/excalidraw/excalidraw', keywords: ['白板', '手绘', '草图', '协作'] },
      { title: 'Desmos', icon: 'lucide:chart-spline', description: '函数绘图与方程计算', url: 'https://www.desmos.com/calculator?lang=zh-CN', source: 'https://help.desmos.com/hc/en-us/articles/4406040715149-Getting-Started-Desmos-Graphing-Calculator', keywords: ['函数', '数学', '计算器', '图像', '高数'] },
      { title: 'GeoGebra', icon: 'lucide:shapes', description: '动态几何与数学计算', url: 'https://www.geogebra.org/calculator', source: 'https://www.geogebra.org/', keywords: ['几何', '代数', '数学', '函数', '计算器'] },
      { title: 'Squoosh', icon: 'lucide:image-down', description: '图片压缩与格式转换', url: 'https://squoosh.app/', source: 'https://github.com/GoogleChromeLabs/squoosh', keywords: ['图片', '压缩', '转换', '图像'] },
      { title: 'ProcessOn', icon: 'lucide:network', description: '思维导图与团队协作', url: 'https://www.processon.com/', source: 'https://www.processon.com/', keywords: ['思维导图', '脑图', '流程图', '协作'], note: '官网提供登录及价格入口，具体功能与使用额度以服务当前方案为准。' },
    ],
  },
  {
    id: 'design-writing',
    title: '设计与写作',
    icon: 'lucide:palette',
    links: [
      { title: 'Overleaf', icon: 'lucide:file-pen-line', description: '论文写作与公式排版', url: 'https://www.overleaf.com/', source: 'https://www.overleaf.com/', keywords: ['LaTeX', '论文', '排版', '公式', '协作'], note: '官方在线 LaTeX 编辑器，部分协作与历史功能属于付费方案。' },
      { title: 'Zotero', icon: 'lucide:library-big', description: '文献整理与引用管理', url: 'https://www.zotero.org/', source: 'https://www.zotero.org/', keywords: ['参考文献', '论文', '引用', '文献管理'] },
      { title: 'Iconify', icon: 'lucide:component', description: '开源图标与开发文档', url: 'https://iconify.design/', source: 'https://iconify.design/', keywords: ['图标', 'SVG', '图标库', '前端', '开发'], note: '图标集合各有许可，使用素材时查看对应图标集说明。' },
      { title: 'Yesicon', icon: 'lucide:search-code', description: '矢量图标检索与选用', url: 'https://yesicon.app/zh-Hans', source: 'https://yesicon.app/zh-Hans', keywords: ['图标', 'SVG', '图标搜索', '设计'], note: '图标集合各有许可，使用素材时查看对应图标集说明。' },
      { title: 'Doocs Markdown', icon: 'lucide:notebook-pen', description: '公众号排版与图文编辑', url: 'https://md.doocs.org/', source: 'https://github.com/doocs/md', keywords: ['Markdown', '微信', '公众号', '图文', '编辑器'] },
    ],
  },
  {
    id: 'software-downloads',
    title: '软件下载',
    icon: 'lucide:download',
    // Labels and destinations supplied by the user; provenance is recorded in docs/navigation-discovery-sources.md.
    links: [
      { title: 'Win软件', icon: 'lucide:app-window', description: '联想应用商店', url: 'https://lestore.lenovo.com/', source: 'https://lestore.lenovo.com/', keywords: ['Windows', '应用', '下载', '联想'] },
      { title: '应用推荐', icon: 'lucide:package-search', description: '果核剥壳软件资源', url: 'https://www.ghxi.com/', source: 'https://www.ghxi.com/', keywords: ['果核', '软件', '下载', '工具'] },
      { title: '微软商店解析', icon: 'lucide:store', description: '商店应用链接解析', url: 'https://store.rg-adguard.net/', source: 'https://store.rg-adguard.net/', keywords: ['Microsoft Store', 'Windows', '下载', 'rg-adguard'] },
      { title: 'Win镜像', icon: 'lucide:disc-3', description: 'UUP 系统镜像', url: 'https://www.uupdump.cn/', source: 'https://www.uupdump.cn/', keywords: ['Windows', 'UUP', '系统', 'ISO', '下载'] },
      { title: '开源镜像', icon: 'lucide:hard-drive-download', description: '南京大学镜像站', url: 'https://mirror.nju.edu.cn/', source: 'https://mirror.nju.edu.cn/', keywords: ['NJU', 'Linux', '软件源', '南京大学', '下载'] },
      { title: 'Mac软件', icon: 'lucide:laptop', description: 'Digit77 应用资源', url: 'https://www.digit77.com/', source: 'https://www.digit77.com/', keywords: ['macOS', '苹果', '应用', '下载'] },
      { title: 'JB激活', icon: 'lucide:key-round', description: 'JetBra.in 工具页面', url: 'https://3.jetbra.in/', source: 'https://3.jetbra.in/', keywords: ['JetBrains', 'IDEA', 'PyCharm', 'WebStorm'] },
    ],
  },
]
