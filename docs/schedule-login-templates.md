# 课表扫码登录实现模板

2026-09-23。本地实验入口 `/previews/schedule-login`，提供学习通、学校微信、武科大助手三个独立适配分支。用户已确认三种方式均能登录。学校方案已在真实扫码后验证教务会话，并根据已登录官网课表结构补上解析；完整课表结果验证见文末。此模板仍仅供本地实验。

学校分支现有独立 HTTPS 后端 API：[schedule.wiki.jianges.com](https://schedule.wiki.jianges.com)。服务器不承载网站；允许正式 Wiki `https://wiki.wustacm.com` 调用。生产接口采用来源绑定的短期会话标识，不依赖跨站 Cookie；本地实验仍沿用原有 HttpOnly Cookie。它使用学校 provider 白名单、来源校验和 IP 限流，未对外开放本地实验 API 的三个分支。部署与维护见 [schedule-deployment.md](schedule-deployment.md)。

## 一条命令启动

```powershell
pnpm dev:login
```

默认绑定 `127.0.0.1:3017`，打开终端实际地址后加 `/previews/schedule-login`。如端口冲突，可先设置 `$env:PORT = '可用端口'`。这是开发服务，支持热更新。

局域网测试运行 `pnpm dev:login:lan`。该命令监听 IPv4 `0.0.0.0`，并将启动时本机私有 IPv4 地址及端口加入接口白名单，终端会打印访问链接。同一局域网设备使用电脑的实际 IP 访问；本机 `127.0.0.1` 仍可用。切换网络或 IP 变化后重新启动。此模式显式允许局域网测试，普通 `dev:login` 仍只监听本机。

启动器仅为子进程设置 `WIKI_LOGIN_TEMPLATES=1`。普通 `pnpm dev` 和默认线上运行都不启用接口；静态构建只包含页面，不包含可工作的认证后端。静态预览不支持此功能。不要把本模板直接配置成公共认证服务。

## 三个方案的实际边界

| 模板 | 已实现 | 尚未实测 / 未实现 |
| --- | --- | --- |
| 学习通 | 从官方登录页取得二维码参数；同一 Cookie jar 生成二维码和轮询；确认后请求 `getMyLessons`，提取课表 UUID、学期与当前周排课；清除登录会话 | 用户已确认登录；账户绑定与二次认证、多学期和多单位选择尚未覆盖 |
| 学校微信 | 官方扫码、CAS 换票、同一 Cookie jar 访问 `xskb/xskb_list.do`；解析当前学期全周排课和备注；清除认证材料 | 多学期选择；更多账号的特殊排课格式。未识别页面返回 `needs_adapter`，不会伪装成空课表 |
| 武科大助手 | 按用户提供客户端的接口创建二维码、轮询，取得 Bearer 后查询本科课表并投影展示字段；清除令牌 | 用户已确认登录；绑定、二次验证、不同接口版本和学期选择尚未覆盖。它是第三方助手后端，不是学校官方接口 |

初版检查确认了三种二维码创建和等待状态；随后用户确认三种方式均可登录。学校真实扫码已抵达 `framework/xsMain.jsp`，其页面外壳不直接包含课表；实际学期课表位于 `xskb/xskb_list.do` iframe。

学校返回字段叫 `passWord`，尚不能证明是原始密码、密文还是短期凭据。实现将其视为敏感认证材料，只在服务端当前请求中传回同一学校认证平台；不要求用户输入，不传回浏览器、不持久化、不输出日志。助手的 token 同样仅用于既定本科课表读取。

## 源码入口与复用分类

- 页面：`app/pages/previews/schedule-login.vue`。直接复用 Wiki 全局外壳、Nuxt UI 的 UCard/UAlert/UButton/UBadge，提供方式切换、生成、倒计时、等待确认、取消、结果展示。
- 接口：`server/api/login-template.post.ts`。同源 POST 动作 `inspect/start/poll/clear`，固定三种 provider；不接受任意上游 URL、service、Cookie 或 Token。
- 会话：`server/utils/login-template-store.mjs`。自行实现状态管理、隔离、轮询限速和清除。
- HTTP：`server/utils/login-template-http.mjs`。使用固定版本 `tough-cookie@6.0.0` 的标准 Cookie jar；自行实现固定上游、逐跳重定向校验、超时、大小限制和中断。
- 三个适配器：`server/utils/login-template-adapters.mjs`。根据第一方网页及用户提供客户端的请求契约自行实现，没有复制反编译客户端业务代码。
- 学校课表：`server/utils/school-schedule.mjs`。使用 `parse5@8.0.1` 解析官网 HTML；只读取固定课表地址，按 `kbtable` 列确定星期，按 `周次(节次)` 确定实际节次，保留间断周次、分组、多门课和未排课备注，忽略 `kbcontent1` 紧凑重复副本。未知结构明确停止。
- 启动器：`scripts/dev-login-templates.mjs`。
- 自动检查：`pnpm check:login-templates`，测试文件 `scripts/login-templates.test.mjs`、`scripts/school-schedule.test.mjs`。后者用符合官网结构的虚构数据，不保存真实个人课表。

## 会话与终止约定

浏览器仅持有 HttpOnly、SameSite=Strict 的本机会话标识。上游 Cookie、助手 Token、扫码 state/enc、学校 passWord/TGT/ticket 不返回页面；二维码本身包含认证能力，只展示给发起用户。

- 默认不开启。Host 与 Origin 必须匹配；局域网模式额外允许启动器记录的本机私有 IPv4 地址与端口。存在 socket 地址时仅接受 loopback，或局域网模式下的私有 IPv4 客户端。Nuxt dev 内部传输可能没有 socket 地址，只有开发构建允许此特例；不信任转发头。此模式供可信局域网测试，未配置公网反向代理或端口映射。
- 每个浏览器会话同时一个流程，切换方式会取消前一流程；不同浏览器会话使用不同 Cookie jar。
- 登录开始由用户点击触发；不自动登录、发短信、重试认证或访问成绩等其他接口。
- 浏览器每 3.5 秒轮询，服务端至少间隔 3 秒并阻止并发轮询。学习通 150 秒到期，另外两个模板最多 180 秒。
- 成功、出错、要求额外操作、取消后释放 Cookie jar，关闭进行中的请求。成功结果仅在内存暂存 5 分钟；页面离开发送清除请求。窗口断网或强制关闭时，以服务端定时清除为兜底。
- 二次验证、绑定等场景直接停止，不擅自处理。官方入口是在浏览器中另开的一次正常登录，与模板后端会话不共享；不能在官方窗口登录后就假定模板会自动完成。
- 没有认证或结果磁盘存储、公开分享、生产部署、账号历史、跨设备同步。课程和 UUID 不预生成到静态产物。
- 清除是销毁本模板持有的会话材料，并不承诺撤销上游已签发会话或远程登出。

学校模板只在识别到完整课表结构后显示“已获取课表”。无课程但结构完整可返回零条；认证跳转、未知页面或存在无法解析的课程不会当作空课表成功。

## 契约来源

学习通：[官方登录页](https://passport2.chaoxing.com/login)、[课表脚本](https://kb.chaoxing.com/res/pc/curriculum/js/schedule.pc.js?v=15)。二维码参数为隐藏字段 `uuid/enc`；创建 `/createqr`；表单 POST `/getauthstatus/v2`；本人课表 `/pc/curriculum/getMyLessons`。含 `containTwoFactorLogin` 时停止。

学校：[当前认证脚本](https://auth.wust.edu.cn/assets/js/app.8ac2ab125e78c30ed179.js)、[vendor](https://auth.wust.edu.cn/assets/js/vendor.167b3acdf49d24548614.js)、[教务实际入口](https://bkjx.wust.edu.cn/jsxsd/)。创建 GET `/lyuapServer/weChat/CreateQRcode?businessType=login&platformType=wx`；JSON POST `/lyuapServer/weChat/wx/CheckScan`；form POST `/lyuapServer/v1/tickets`，固定 service 为 `https://bkjx.wust.edu.cn/jsxsd/`、loginType 为 `3`。学校 `/jsxsd/` 未登录响应实际跳转到携带此 service 的认证页面。当前扫码流程已实测建立教务会话，无需仿制额外加密请求头。课表来源：[用户提供的教务外壳](https://bkjx.wust.edu.cn/jsxsd/framework/xsMain.jsp)及其中实际加载的[学期课表](https://bkjx.wust.edu.cn/jsxsd/xskb/xskb_list.do)。

助手参考目录：`C:/Users/LEGION/OneDrive - Default Directory/文档/ChatGPT/武科大助手/recovery/jadx/sources/com/example/wusthelper/`。依据 `request/NewApiHelper.java`、`request/WustApi.java`、`bean/javabean/data/WechatLoginStartData.java`、`TokenData.java`、`CourseData.java`、`mvp/presenter/LoginPresenter.java`。创建/状态为 `/UnderGraduate/Support/wechatLogin/start`、`/status`，课表为 `/UnderGraduate/Support/getCoursesPage`，固定上游 `https://lyzyy.love:8081`。

此前的可行性和匿名分享方案见 [schedule-feasibility.md](schedule-feasibility.md)。

## 本次验证记录

- `pnpm install --frozen-lockfile`、`pnpm typecheck`、`pnpm check:content`、`pnpm check:xupt` 通过。
- `pnpm check:login-templates`：14 项通过，覆盖会话隔离、Cookie 域范围、恶意重定向、字段投影、固定 CAS service、取消后的迟到响应、到期清除、轮询限速及二次验证停止；新增学校 CAS Cookie 延续、真实课表路径、间断周次、单节课、多课程、隐藏副本、备注、空课表与认证跳转的回归，以及局域网开关、地址白名单和同源限制。
- `pnpm generate` 通过，生成 109 条路由。构建有 vendor 插件路径、拆包和依赖优化等警告，未阻断生成。
- 实际 API 验证：三种上游创建二维码和未扫码轮询通过；默认关闭时 403，启用后本机同源 200，跨源 403，响应为 `private, no-store`。
- 浏览器实际验证：三个入口、真实二维码加载、等待状态、方式切换、取消清除；桌面与 390px 手机视口、深浅色通过，无整页横向溢出，初版检查时无浏览器 error/warn。本轮真实结果页未见 error；有项目现存的 OG Image 未启用提示。
- 用户已确认三种方式均能登录；学校扫码后的真实教务页面和已登录浏览器中的学期课表结构已核对。本轮真实扫码完整读取当前学期 19 条排课、4 条教务备注。与已登录官网逐条对比，19 条排课的星期、节次、周次、教师及地点均一致；本地成功后二维码消失，认证会话已清除。
- 未验证：上游二次验证、更多账号或特殊排课格式、生产部署。扫码与手机确认均由用户完成。

局域网模式验证：从本机使用 WLAN 地址访问页面和学校二维码创建/取消成功；同源接口 200、跨源 403、loopback 200。14 项自动测试、类型检查、静态生成 109 路由通过。未从第二台设备实测 Wi-Fi 连通性。服务启动期间保持电脑开机；没有更改防火墙或配置公网端口映射。
