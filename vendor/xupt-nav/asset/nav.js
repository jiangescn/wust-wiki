const nav = {
  name: "CO导航",
  description: "",
  list: [],
  ele: document.querySelectorAll(".navlist"),
}

nav.list[0] = [{
  name: "线上课时", icon: "fa-solid fa-chalkboard-user", item: [
    { text: "学习通", icon: "iconfont icon-chaoxing", link: "https://i.chaoxing.com/" },
    { text: "U校园", icon: "fa-solid fa-u", link: "https://u.unipus.cn/user/student" },
    { text: "iWrite", icon: "fa-solid fa-pen-nib", link: "https://iwrite.unipus.cn/student" },
    { text: "中国大学MOOC", icon: "fa-solid fa-book-open", link: "https://icourse163.org/home.htm" },
    { text: "云班课", icon: "fa-solid fa-cloud", link: "https://www.mosoteach.cn/web/" },
    { text: "学堂在线", icon: "fa-solid fa-school-circle-check", link: "https://www.xuetangx.com/my-courses/current" },
    { text: "蓝桥云课", icon: "iconfont icon-lanqiao", link: "https://www.lanqiao.cn/user/?tab=2#:~:text=%E6%88%91%E7%9A%84%E8%AF%BE%E7%A8%8B" },
    { text: "PTA", icon: "fa-solid fa-laptop-code", link: "https://pintia.cn/problem-sets/active" },
    { text: "希冀", icon: "fa-solid fa-infinity", link: "https://course.educg.net/" },
  ]
}, {
  name: "西邮生活", icon: "fa-solid fa-school", item: [
    { text: "教务系统", desc: "“校务行”查分更快", icon: "fa-regular fa-calendar-days", link: "https://zfjw.xupt.edu.cn/sso/xiyoulogin" },
    { text: "奖学金/退费", desc: "支付宝扫码领取", icon: "fa-solid fa-wallet", js: "dialog.showMsg('西邮财务处')" },
    { text: "缴费大厅", desc: "电费充值", icon: "fa-solid fa-sack-dollar", js: "dialog.showMsg(this.textContent)" },
    { text: "i西邮", desc: "网页版登录", icon: "fa-solid fa-location-dot", js: "dialog.showMsg(this.textContent)" },
    { text: "青年大学习", desc: "需要微信打开", icon: "fa-solid fa-medal", js: "dialog.showMsg(this.textContent)" },
    { text: "第二课堂", desc: "学分申报", icon: "fa-solid fa-book-bookmark", js: "dialog.showMsg(this.textContent)" },
    { text: "取快递", desc: "淘宝身份码", icon: "iconfont icon-taobao", js: "dialog.showMsg(this.textContent)" },
    { text: "一网通办", desc: "新版个人中心", icon: "fa-solid fa-street-view", link: "https://i.xupt.edu.cn/" },
    { text: "知网", desc: "校内认证", icon: "iconfont icon-zhiwang", link: "https://fsso.cnki.net/Shibboleth.sso/Login?entityID=https://idp.xupt.edu.cn/idp/shibboleth&target=https://fsso.cnki.net/secure/default.aspx" },
    { text: "毕业设计", desc: "论文管理系统", icon: "fa-solid fa-building-lock", link: "https://co2.cnki.net/Main.html?dp=xiyou" },
    { text: "内网资源", desc: "WebVPN聚合平台", icon: "fa-solid fa-building-lock", link: "https://sec.xupt.edu.cn/" },
    { text: "CARSI", desc: "跨校资源认证", icon: "iconfont icon-carsi", link: "https://idp.xupt.edu.cn/idp/" },
    { text: "电子教材", desc: "西邮图书馆", icon: "fa-solid fa-book", link: "https://xyoujc.mh.chaoxing.com/engine2/general-rest/4072742/proxy-more-url?wfwfid=22861" },
    { text: "教育邮箱", desc: "页面右上角能申请", icon: "fa-solid fa-envelope", link: "http://webmail.xupt.edu.cn/" },
    { text: "企业微信", desc: "关注/加入指南", icon: "fa-brands fa-weixin", link: "https://xxzx.xupt.edu.cn/info/1005/2693.htm" },
    { text: "西邮官网", icon: "fa-solid fa-globe", link: "https://www.xupt.edu.cn/" },
    { text: "常用服务导航", icon: "fa-solid fa-taxi", link: "https://www.xupt.edu.cn/xxfw/cyfw1.htm" },
    { text: "办事大厅", icon: "fa-solid fa-building-columns", link: "http://one.xupt.edu.cn/EIP" },
    { text: "信息直通车", icon: "fa-solid fa-train-subway", link: "https://ztc.sec.xupt.edu.cn/" },
    // { text: "正版软件", icon: "fa-solid fa-cubes", link: "http://ms.xupt.edu.cn/" },
    { text: "智邮园", desc: "AI对话咨询", icon: "fa-solid fa-robot", link: "https://agent.xupt.edu.cn/h5/portal/xupt/intelligentAgent" },
  ]
}, {
  name: "考试学习", icon: "fa-solid fa-pen-ruler", item: [
    { text: "西邮试卷", desc: "欢迎commit", icon: "fa-brands fa-github", link: "https://github.com/JiaHuann/XUPT-Exam-Collection" },
    { text: "试卷打印", desc: "打印店资源", icon: "fa-solid fa-print", js: "dialog.showMsg(this.textContent)" },
    // { text: "船长的网课", desc: "挂了先用右边的", icon: "fa-solid fa-hard-drive", link: "https://pan.sehcz.ltd/%E6%88%91%E7%9A%84%E7%BD%91%E7%9B%98/%E6%9C%9F%E6%9C%AB%E4%BF%9D%E5%91%BD" },
    { text: "名来的网课", desc: "期末保命复习视频", icon: "fa-solid fa-hard-drive", link: "https://drive.mzdyl.xyz/%E5%AD%A6%E4%B9%A0%E8%B5%84%E6%96%99" },
    { text: "安娜的档案", desc: "世界最大互联网图书馆", icon: "fa-solid fa-book-atlas", link: "https://zh.annas-archive.org/" },
    { text: "zlibrary", desc: "免费电子书下载", icon: "fa-solid fa-book-atlas", link: "https://zh.z-library.sk/" },
    { text: "力扣", icon: "fa-solid fa-code", link: "https://leetcode.cn/" },
    { text: "学信档案", icon: "fa-solid fa-address-card", link: "https://my.chsi.com.cn/archive/index.action" },
    { text: "四六级报名", icon: "fa-solid fa-scroll", link: "https://cet-bm.neea.edu.cn/" },
  ]
}, {
  name: "西邮周边", icon: "fa-solid fa-circle-nodes", item: [
    { text: "📘西邮Wiki", desc: "校园生活指南", link: "https://wiki.cooo.site/" },
    { text: "🔥实验室", desc: "火热纳新 就等你来", link: "https://wiki.cooo.site/coder" },
    { text: "各兴趣群", desc: "游戏娱乐 小众爱好", icon: "fa-solid fa-gamepad", link: "https://docs.qq.com/sheet/DSkFiRmpzcVJHSklM?tab=ov58e9" },
    // { text: "校园网", link: "https://github.com/drcoms/drcom-generic/wiki/可用学校列表" },
    { text: "西邮码农", desc: "实验室学习/就业交流", icon: "fa-solid fa-keyboard", js: "dialog.showMsg(this.textContent)" },
    { text: "逸夫楼地图", desc: "手机访问才正常", icon: "fa-solid fa-map-location-dot", js: "dialog.showMsg(this.textContent)" },
    { text: "东区教室导航", desc: "微信“隔壁小O”", icon: "fa-solid fa-route", link: "https://mp.weixin.qq.com/s/CZR_d2SmltiZyl-oCz3zhA" },
    { text: "邮立方", desc: "校园MC交流", icon: "iconfont icon-minecraft", link: "https://cop.cooo.site" },
    { text: "飞跃手册", desc: "毕业经验分享", link: "https://xuptflying.github.io/xupt-flying.github.io/#/" },
    { text: "校园墙", icon: "fa-brands fa-weixin", link: "https://wiki.cooo.site/life/forum#校园墙" },
    { text: "西柚oi", desc: "校园交流群", icon: "iconfont icon-xiaohongshu", js: "dialog.showMsg(this.textContent)" },
  ]
},]

nav.list[1] = [{
  name: "第三方导航", icon: "fa-solid fa-signs-post", item: [
    // { text: "夸克搜索", desc: "免下载", icon: "fa-solid fa-magnifying-glass", js: "dialog.showMsg(this.textContent)" },
    { text: "半岛导航", desc: "西邮 学习", link: "https://www.bandao.ltd/guidance/" },
    { text: "掘金酱", desc: "开发者", link: "https://e.juejin.cn/" },
    { text: "AI工具集", link: "https://ai-bot.cn/" },
    { text: "别摸鱼", desc: "AI 新媒体", link: "https://biemoyu.com/" },
    { text: "下次一定", desc: "影视 工具 装机", link: "https://www.iiice.cn/" },
    { text: "蜗牛导航", desc: "开发 设计", link: "https://s.eallion.com/" },
  ]
}, {
  name: "AI工具", icon: "fa-solid fa-robot",
  item: [
    { text: "豆包", desc: "字节", link: "https://www.doubao.com/chat/" },
    { text: "DeepSeek", link: "https://chat.deepseek.com/" },
    { text: "Kimi.ai", desc: "月之暗面", link: "https://kimi.moonshot.cn/" },
    { text: "秘塔", desc: "搜索 学术", link: "https://metaso.cn/" },
    { text: "元宝", desc: "腾讯", link: "https://yuanbao.tencent.com/" },
    { text: "SCNet", desc: "DeepSeek", link: "https://chat.scnet.cn/ui/chatbot/" },
    { text: "纳米AI", desc: "360(聚合)", link: "https://bot.n.cn/" },
    { text: "通义千问", desc: "阿里", link: "https://tongyi.aliyun.com/qianwen/" },
    { text: "文心一言", desc: "百度", link: "https://yiyan.baidu.com/" },
    { text: "智谱清言", desc: "", link: "https://chatglm.cn/" },
    { text: "星火", desc: "讯飞", link: "https://xinghuo.xfyun.cn/desk" },
    { text: "天工", desc: "昆仑", link: "https://search.tiangong.cn/" },
    { text: "商量", desc: "商汤", link: "https://chat.sensetime.com/" },
    { text: "ChatGPT", desc: "OpenAI", link: "https://chatgpt.com/" },
    { text: "ChatGPT", desc: "国内镜像", link: "https://www.ycl.cool/tool/ai/" },
    { text: "Gemini", desc: "Google", link: "https://gemini.google.com/" },
    { text: "Copilot", desc: "Microsoft", link: "https://copilot.microsoft.com/" },
    { text: "Poe", desc: "Quora", link: "https://poe.com/" },
    { text: "Perplexity", link: "https://www.perplexity.ai/" },
  ]
}, {
  name: "校友推荐", icon: "fa-solid fa-inbox",
  desc: `<a onclick="dialog.showMsg('联系方式')"><i class="fa-solid fa-pen-to-square"></i> 我要投稿</a>`,
  item: [
    { text: "打字背单词", desc: "Qwerty Learner", link: "https://qwerty.kaiyi.cool/" },
    { text: "公众号编辑", desc: "Doocs Markdown", icon: "fa-brands fa-markdown", link: "https://md.doocs.org/" },
    { text: "电脑入门", desc: "你缺失的那门计算机课", icon: "fa-solid fa-book-bookmark", link: "https://www.criwits.top/missing/" },
    { text: "电脑帮助", desc: "南大IT侠手册", link: "https://www.yuque.com/itxia" },
    { text: "芯片榜", desc: "极客湾SoCPK", link: "https://www.socpk.com/" },
    { text: "Yesicon", desc: "前端图标库", link: "https://yesicon.app/" },
    { text: "开发速查", desc: "Quick Reference", icon: "fa-solid fa-swatchbook", link: "https://quickref.cn/" },
  ]
}, {
  name: "在线工具", icon: "fa-solid fa-toolbox", item: [
    { text: "菜鸟工具", desc: "运行代码", link: "https://c.runoob.com/" },
    { text: "在线PS", desc: "稿定设计", link: "https://ps.gaoding.com/" },
    { text: "帮小忙", desc: "QQ浏览器", link: "https://tool.browser.qq.com/" },
    { text: "IT Tools", desc: "程序员工具", link: "https://sharevb-it-tools.vercel.app/" },
    { text: "MikuTools", desc: "小工具集合", link: "https://tools.miku.ac/" },
    { text: "测网速", desc: "中科大测速", link: "https://test.ustc.edu.cn/" },
    { text: "USTC反代", desc: "教育网出口测试", link: "http://revproxy.ustc.edu.cn:8000/" },
    { text: "IP检查", desc: "Sukka", link: "https://ip.skk.moe/" },
    { text: "MyIP", desc: "IP工具箱", link: "https://ipcheck.ing/" },
    { text: "画流程图", desc: "Draw.io", link: "https://draw.io/" },
    { text: "电路仿真", desc: "CircuitJS1", link: "https://www.falstad.com/circuit/circuitjs.html" },
    { text: "在线DOS", desc: "MASM汇编", link: "https://dosasm.github.io/dosrun/" },
    { text: "HDL仿真", desc: "EDA playground", link: "https://edaplayground.com/" },
    { text: "RISC-V仿真", desc: "emulsiV", link: "https://eseo-tech.github.io/emulsiV/" },
    { text: "汇编转换", desc: "Compiler Explorer", link: "https://godbolt.org/" },
  ]
}, {
  name: "软件下载", icon: "fa-solid fa-cube", item: [
    { text: "Win软件", desc: "联想应用商店", icon: "fa-brands fa-microsoft", link: "https://lestore.lenovo.com/" },
    { text: "应用推荐", desc: "果核剥壳", link: "https://www.ghxi.com/" },
    { text: "微软商店解析", desc: "Generation Project", icon: "fa-solid fa-bag-shopping", link: "https://store.rg-adguard.net/" },
    { text: "Win镜像", desc: "UUPDump", icon: "fa-brands fa-windows", link: "https://www.uupdump.cn/" },
    { text: "开源镜像", desc: "NJU Mirror", link: "https://mirror.nju.edu.cn/" },
    { text: "Mac软件", desc: "Digit77破解", icon: "fa-brands fa-apple", link: "https://www.digit77.com/" },
    { text: "JB激活", desc: "JetBra.in", icon: "iconfont icon-apple-mask-icon", link: "https://3.jetbra.in/" },
  ]
}, {
  name: "友链", icon: "fa-solid fa-link",
  desc: `<a onclick="dialog.showMsg('联系方式')"><i class="fa-solid fa-user-plus"></i> 添加友链</a>`,
  item: [
    { text: "纸鹿摸鱼处", desc: "个人博客", link: "https://blog.zhilu.site/" },
    { text: "西邮 Linux 兴趣小组", link: "https://www.xiyoulinux.com/" },
    { text: "西邮Wiki", link: "https://wiki.cooo.site/" },
    { text: "邮立方", link: "https://cop.cooo.site/" },
    { text: "智邮普创", link: "https://zypc.xupt.edu.cn/" },
    // { text: "半岛的小屋", link: "https://www.bandao.ltd/" },
    // { text: "plus studio", link: "https://studyinglover.com/" },
    { text: "科成星球", desc: "Fork下游", link: "https://www.cduestc.fun/" },
    { text: "成中医导航", desc: "Fork下游", link: "https://nav.henry.city/" },
  ]
},]

nav.list.forEach((list, i) => {
  nav.ele[i].innerHTML = list.map(group => `
    <div class="card">
    <div class="between">
    <h4><i class="${group.icon}"></i><span>${group.name}</span></h4>
    ${group.desc ? `<p class="dim">${group.desc}</p>` : ``}
    </div>
    <div class="list">
    ${group.item.map(item => `
      <a data-sub="${item.desc || ""}"
      ${item.js ? `onclick="${item.js}"` : `href="${item.link}"`}
    >${item.icon ? `<i class="${item.icon}"></i>` : ``}<span>${item.text}</span></a>
    `).join(`\n`)}
    </div>
    </div>`).join(`\n`)
})
