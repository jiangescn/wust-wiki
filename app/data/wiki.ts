// Entry order and navigation adapted from xupt-wiki/xupt-wiki (see THIRD_PARTY_NOTICES.md).
export const homeEntries = [
  { title: '住宿生活', icon: '🏠', description: '宿舍信息、环境配置、缴费', to: '/campus/accommodation' },
  { title: '入学办理', icon: '📝', description: '空调、饮水机、校园网', to: '/campus/enrollment' },
  { title: '防骗指南', icon: '🚨', description: '线上付款要谨慎', to: '/campus/anti-fraud' },
  { title: '手机必备 APP', icon: '📱', description: '课堂学习、组织培训、生活 APP', to: '/campus/apps' },
  { title: '课程安排', icon: '📚', description: '课程表、课表查询', to: '/study/curriculum' },
  { title: '快递与外卖', icon: '📦', description: '收货地址', to: '/life/delivery' },
  { title: '美食推荐', icon: '🍽️', description: '😋', to: '/life/food' },
  { title: '校园墙', icon: '📷', description: '表白墙、校园社区', to: '/life/forum' },
  { title: '武科大俱乐部', icon: '🔬', description: '校园俱乐部、社团与交流群', to: '/coder' },
  { title: '个人博客', icon: '✍️', description: '校友技术博客汇总', to: '/coder/blog' },
  { title: '兴趣群列表', icon: '👥', description: 'QQ 兴趣群汇总，一键加群', to: '/life/groups' },
  { title: '学分绩点', icon: '💯', description: '综合评价、评优保研', to: '/study/gpa' },
  { title: '竞赛与证书', icon: '🏆', description: '竞赛资讯、证书考试', to: '/study/contest' },
  { title: '周边去处', icon: '🗺️', description: '学校周边吃喝玩乐', to: '/life/nearby' },
  { title: '趣闻', icon: '🤣', description: '武科大那些有意思的事', to: '/campus/anecdote' },
]

export const wikiNavigation = [
  { label: 'Coder', children: [{ label: '武科大俱乐部', to: '/coder' }, { label: '校友博客', to: '/coder/blog' }] },
  { label: '校园', children: [{ label: '学校简介', to: '/campus' }, { label: '住宿生活', to: '/campus/accommodation' }, { label: '入学准备', to: '/campus/enrollment' }, { label: '防骗指南', to: '/campus/anti-fraud' }] },
  { label: '学习', children: [{ label: '学习简介', to: '/study' }, { label: '课内学业', to: '/study/grades' }, { label: '实验室·兴趣小组', to: '/study/labs' }, { label: '竞赛与证书', to: '/study/contest' }] },
  { label: '生活', children: [{ label: '生活简介', to: '/life' }, { label: '校园墙·社区', to: '/life/forum' }, { label: '兴趣群展示', to: '/life/groups' }, { label: '美食推荐', to: '/life/food' }, { label: '快递·外卖', to: '/life/delivery' }] },
  { label: '关于', children: [{ label: '全部文章', to: '/articles' }, { label: '友情链接', to: '/links' }, { label: '贡献指南', to: '/contributing' }, { label: '更新日志', to: '/changelog' }, { label: '关于我们', to: '/about' }] },
]
