export interface NavigationLink {
  title: string
  icon: string
  description: string
  url: string
  keywords?: string[]
  source?: string
  note?: string
}

export interface NavigationCategory {
  id: string
  title: string
  icon?: string
  links: NavigationLink[]
}

// Official link sources and access-check boundaries: docs/navigation-sources.md.
// Keep credentials and session-specific URLs out of this public directory.
export const navigationCategories: NavigationCategory[] = [
  {
    id: 'study',
    title: '教务学习',
    links: [
      {
        title: '本科教务系统',
        icon: 'lucide:clipboard-list',
        description: '课表、选课与成绩查询',
        url: 'https://bkjx.wust.edu.cn/jsxsd/sso.jsp',
        keywords: ['教务管理', '课表', '选课', '成绩', '学籍'],
        source: 'https://www.wust.edu.cn/',
        note: '学校首页公布的教务系统入口；需登录，校外访问以学校实际开放范围为准。',
      },
      {
        title: '本科生院',
        icon: 'lucide:university',
        description: '教学通知与教务办事指南',
        url: 'https://jwc.wust.edu.cn/',
        keywords: ['教务处', '本科', '考试', '通知'],
        source: 'https://www.wust.edu.cn/jyjx.htm',
      },
      {
        title: '教学校历',
        icon: 'lucide:calendar-days',
        description: '教学周与校区作息安排',
        url: 'https://jwc.wust.edu.cn/xl/xiaoli.html',
        keywords: ['校历', '日历', '上课时间', '作息'],
        source: 'https://jwc.wust.edu.cn/',
        note: '本科生院首页内嵌的校历；具体教学及放假安排以学校最新通知为准。',
      },
      {
        title: '图书馆',
        icon: 'lucide:library-big',
        description: '馆藏、借阅与读者服务',
        url: 'https://tsg.wust.edu.cn/',
        keywords: ['借书', '续借', '馆藏', '图书'],
        source: 'https://tsg.wust.edu.cn/',
      },
      {
        title: '电子资源',
        icon: 'lucide:database',
        description: '学术数据库与访问指南',
        url: 'https://tsg.wust.edu.cn/info/1691/4471.htm',
        keywords: ['论文', '文献', '知网', 'CNKI', '数据库', '校外访问'],
        source: 'https://tsg.wust.edu.cn/dzzn/dzzyfwzn.htm',
        note: '从图书馆官方页面进入资源平台，按指南使用学校统一身份认证登录。',
      },
      {
        title: '座位预约',
        icon: 'lucide:armchair',
        description: '图书馆选座与预约规则',
        url: 'https://ic.lib.wust.edu.cn/clientweb/xcus/ic2/Default.aspx',
        keywords: ['图书馆', '自习', '选座', '空间'],
        source: 'https://tsg.wust.edu.cn/dzzn/zwyy.htm',
        note: '需学工号登录；使用与签到规则见图书馆座位预约指南。',
      },
      {
        title: '云课程中心',
        icon: 'lucide:monitor-play',
        description: '武科大智慧树课程入口',
        url: 'https://wust.zhihuishu.com/',
        keywords: ['智慧树', '知到', '网课', '在线课程'],
        source: 'https://jwc.wust.edu.cn/',
        note: '本科生院公布的课程平台；具体课程与登录方式以任课教师要求为准。',
      },
    ],
  },
  {
    id: 'campus',
    title: '校园服务',
    links: [
      {
        title: '学校官网',
        icon: 'lucide:school',
        description: '学校新闻、通知与机构',
        url: 'https://www.wust.edu.cn/',
        keywords: ['武汉科技大学', '武科大', 'WUST', '学校主页'],
        source: 'https://www.wust.edu.cn/',
      },
      {
        title: '信息门户',
        icon: 'lucide:panels-top-left',
        description: '师生校园应用统一入口',
        url: 'https://portal.wust.edu.cn/',
        keywords: ['学生', '教工', '统一身份认证', '智慧校园'],
        source: 'https://www.wust.edu.cn/',
        note: '从学校首页“学生 / 教工”进入；需学校统一身份认证。',
      },
      {
        title: '办事大厅',
        icon: 'lucide:clipboard-pen-line',
        description: '校内事务申请与办理',
        url: 'https://ehall.wust.edu.cn/taskcenter/workflow/index',
        keywords: ['一网通办', '网上办事', '审批', '申请'],
        source: 'https://www.wust.edu.cn/',
        note: '学校首页公布的办事大厅入口；需登录，事项权限以个人身份为准。',
      },
      {
        title: '学校邮箱',
        icon: 'lucide:mail',
        description: '登录武科大校园邮箱',
        url: 'https://mail.wust.edu.cn/',
        keywords: ['邮件', 'email', 'mail'],
        source: 'https://www.wust.edu.cn/',
        note: '需已开通的学校邮箱账号。',
      },
      {
        title: '网络信息中心',
        icon: 'lucide:network',
        description: '校园网与一卡通服务指南',
        url: 'https://its.wust.edu.cn/',
        keywords: ['校园网', '一卡通', '网络', '企业微信', '报修'],
        source: 'https://its.wust.edu.cn/',
      },
      {
        title: '账号登录帮助',
        icon: 'lucide:key-round',
        description: '密码重置与手机号换绑',
        url: 'https://its.wust.edu.cn/info/1201/4282.htm',
        keywords: ['忘记密码', '统一身份认证', '密码重置', '手机号'],
        source: 'https://its.wust.edu.cn/',
        note: '网络信息中心发布的认证平台帮助；详细步骤见页面 PDF 附件。',
      },
    ],
  },
  {
    id: 'future',
    title: '升学就业',
    links: [
      {
        title: '本科招生网',
        icon: 'lucide:book-open-check',
        description: '招生简章与本科报考信息',
        url: 'https://zs.wust.edu.cn/',
        keywords: ['高考', '招生计划', '录取', '本科'],
        source: 'https://www.wust.edu.cn/zsjy.htm',
      },
      {
        title: '研究生院',
        icon: 'lucide:graduation-cap',
        description: '研究生招生、培养与学位',
        url: 'https://ysxy.wust.edu.cn/',
        keywords: ['考研', '保研', '推免', '硕士', '博士'],
        source: 'https://www.wust.edu.cn/jyjx.htm',
      },
      {
        title: '本科就业信息网',
        icon: 'lucide:briefcase-business',
        description: '招聘信息与本科就业服务',
        url: 'https://wust.91wllm.cn/',
        keywords: ['招聘', '宣讲会', '实习', '本科毕业'],
        source: 'https://www.wust.edu.cn/zsjy.htm',
        note: '学校官网“本科就业”链接指向的就业平台；个人业务需登录。',
      },
      {
        title: '研究生就业网',
        icon: 'lucide:briefcase',
        description: '研究生招聘与就业服务',
        url: 'https://wustyjs.91wllm.cn/',
        keywords: ['研究生就业', '招聘', '宣讲会', '硕士', '博士'],
        source: 'https://www.wust.edu.cn/zsjy.htm',
        note: '学校官网“研究生就业”链接指向的就业平台；个人业务需登录。',
      },
      {
        title: '学信网',
        icon: 'lucide:badge-check',
        description: '学籍、学历与学位查询',
        url: 'https://www.chsi.com.cn/',
        keywords: ['学历认证', '学籍', '学位', '考研'],
        source: 'https://jwc.wust.edu.cn/',
        note: '本科生院快捷服务所列入口；个人查询需学信网账号。',
      },
    ],
  },
]
