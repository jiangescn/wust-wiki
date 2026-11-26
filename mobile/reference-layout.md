# 武科大助手 5.3.1.150 页面拆包记录

检查对象为本次上传的 `base.apk`，共 20,407,039 字节，SHA-256 为 `3D48DFEAD9ABE0448CDB1C88AE8A098088B01454A4B9A058E3DE4D5603A7D50D`。以下结论对应这一份安装包。包名为 `com.linghang.wusthelper`，versionCode 为 1794641503，最低 Android API 27，目标 API 36。启动入口为 `LaunchActivity`。

## 检查方法和证据范围

使用 Android SDK 的 `aapt dump badging` 核对版本，通过 `aapt list` 枚举文件，用 `aapt dump resources` 解析资源 ID，再用 `aapt dump xmltree` 读取导航菜单和编译后的布局树。APK 内有 18 个 DEX、1,446 个 res 目录条目、五个 assets 文件。按 XML 文件名前缀统计有 75 个 activity 布局、9 个 fragment 布局、58 个 item 布局、32 个 dialog 布局和 11 个 widget 布局。这些数字描述资源文件，一个界面可能由多个文件共同组成。

在全新、只读的 Android 模拟器正常启动原版，首屏显示“温馨提示”、协议与隐私政策以及两个选择。运行观察止于该页。以下登录后的层次来自布局 XML、字符串表及用户提供的实际课表截图。某个控件在 XML 中存在，不能证明每个账号都会看到它；截图中的课程、XML 的文字样例均未当作实课导入。

## 原版的页面结构

| 区域 | 直接证据 | 页面职责与控件 |
| --- | --- | --- |
| 主框架 | `layout/activity_main.xml`、`menu/navigation.xml` | NoScrollViewPager 承载栏目，BottomNavigationView 依次为主页、志愿者、课表、校园、个人。菜单项与五个独立图标一一对应。 |
| 登录 | `layout/activity_login.xml`、`dialog_login_error.xml` | 独立页面有标题、SwitchView、学号、教务处密码、登录和找回密码。Wiki 客户端沿用现有学校微信授权，个人页承载授权与退出。原版的表单和 Wiki 的认证协议分别处理。 |
| 主页 | `fragment_home.xml`、`item_home_tool_card.xml`、`activity_home_tool_edit.xml` | 顶部标题、轮播和通知；下方依次是热门功能、校园社区、小工具。热门功能包含成绩、倒计时、图书馆、培养方案、教室查询等。小工具区有独立容器和编辑按钮。 |
| 志愿者 | `fragment_volunteer.xml` | 个人信息与工时汇总、六位工时码、扫码、活动/日志两个列表及加载或重试状态。 |
| 课表 | `fragment_course_new.xml` | SwipeWeekLayout、周选择区、周次 RecyclerView、日期 RecyclerView，以及左侧节次和课程内容网格。周次的切换属于当前页内操作。包内另有 `fragment_course.xml`，含七个星期容器和按早中晚排列的今日课表。 |
| 课程单元及详情 | `item_coursepage_course.xml`、`item_coursepage_date.xml`、`item_course_detail.xml` | 课程名与教室分别居中，日期头分星期和日期两行。课程单元资源默认高 120dp、内边距 1dp，多课指示图标为 6dp。详情按课程名、教师、教室、校区、周数、星期、节次分列。灰色与角标的含义采用用户对截图的说明。 |
| 校园 | `fragment_consult.xml`、`activity_campus_article.xml` | 校园栏目有标题和资讯容器，文章详情有独立布局。Wiki 版在此提供本地文章目录和文章正文。 |
| 个人 | `fragment_mine.xml` | 上方头像与用户信息，下方为注销、反馈、用户群、关于、更新、设置与分享等独立行。Wiki 版在此统一显示登录状态和登录、退出控件。 |

## Wiki 客户端的导航

| 栏目 | 留在本栏完成 | 会打开详情的项目 |
| --- | --- | --- |
| 首页 | 阅读今日课程摘要 | 学业服务的成绩查询和培养方案；校园工具的查宿舍、上课时间、绩点计算、竞赛查询 |
| 课表 | 选周、左右换周、切换作息、同步与查看缓存状态 | 点击课程卡片显示该时段详情 |
| 校园 | 按分类筛选文章 | 选中具体文章、周边地图或武科大导航 |
| 个人 | 微信登录、回到 App 后确认状态、退出 | 用户主动选择授权时打开微信 |

首页摘要和栏目标题都没有跳转动作。按教务成绩计算绩点与手工录入归在同一个绩点工具内。校园目录省去已有专用页面对应的文章入口。正文引用课表、主页或全部文章时回到已有栏目。已核实的学校服务继续调用 Wiki 接口。参考 APK 的二进制、图标、学生信息和服务端协议均未打进 Wiki 安装包。

## 周课表的布局和操作

本次复核了同一份 5.3.1.150 安装包的课表布局资源及换周相关客户端逻辑。原版日期栏约 40dp，星期和日期分两行显示。时间轴把两小节合为一组，上下分别列起止时间，中间用短竖线连接。课程格的参考高度为 120dp，约 1dp 留白，课程名与教室各自居中，右下角另留 6dp 多课标识。点顶部周次会展开周列表，各周有排课缩略预览和本周标记。主表的左右换周和周列表的横向滚动各自处理。

Wiki 安卓版沿用这套层次，详情和网格从同一份实际排课生成。参考截图中的课程仅用于核对布局；回归截图采用合成课程。时间轴随校区使用 Wiki 的已核实作息，超过已知节次时保留节次编号。

## 工具二级页

| Wiki 工具 | 武科大助手 APK 资源 | 布局适配 |
| --- | --- | --- |
| 成绩查询 | `activity_grade.xml`、`item_grade_activity.xml` | 页首搜索，课程卡并列显示成绩、学分和绩点。沿用 Wiki 的学期筛选与课程详情展开。 |
| 主修进度 | `activity_graduation_audit.xml`、`GraduationAuditActivity` | 首屏显示已修学分和四项概览指标。课程统计、毕业学分完成情况、通识选修类别和培养方案课程明细分项查看，课程明细按学期分组。Wiki 从现有教务查询装配这些视图。 |
| 学校通知 | `activity_notice_list.xml`、`item_notice.xml` | 列表突出标题、发布日期和详情箭头。通知来源和分页继续使用 Wiki 服务。 |
| 校车 | `activity_school_bus.xml`、`item_school_bus_time.xml` | 方向标题下按班次显示时间。每班的日期与路线由 Wiki 使用当前服务结果展示。 |
| 考试倒计时 | `activity_countdown.xml`、`item_countdown.xml`、`dialog_countdown_add.xml` | 沿用日期与待考数、科目和时间居左、剩余时间居右、科目／时间／备注编辑的层次。Flutter 使用 Wiki 配色与本机存储。 |
| 图书馆 | `activity_library.xml`、`item_book_borrow.xml` | 首屏使用借阅类别切换和可扫读的书名、应还日期列表，账户附属功能放在菜单。 |

0.6.4 首页沿用助手「热门功能」和工具分类的层次，用 Wiki 组件实现常用卡片和分组入口。二级页参考 [Material 3 列表](https://m3.material.io/components/lists/overview) 的标题、支持信息和整行操作，以及 [Material 加载指示](https://github.com/material-components/material-components-android/blob/master/docs/components/LoadingIndicator.md) 的未知时长状态。短选项直接点选，长选项保留选择器。 [Apple 选择器指南](https://developer.apple.com/design/human-interface-guidelines/pickers)
