# 美食页面接入

入口 `/life/food`，正文为 `content/3.life/5.food.md`。`FoodDirectory.vue` 随正文挂载，在浏览器端匿名读取数据，静态生成时不抓取菜品或用户评论。页面正文集中展示动态目录，状态仍为 draft。

## 展示布局

默认进入南苑食堂，南苑按稳定 ID `canteen-nanyuan` 放在食堂切换首位，其余食堂维持接口顺序。若接口没有南苑，则回退到第一个返回的食堂。

- 菜品目录：先展示店铺，点击后读取店内菜单，再打开菜品详情与评价。借鉴必备 APP 页的左文右图排列，但不调用它的组件。店铺使用 UCard；正文较宽时两列，容器不超过 38rem 时单列。右侧图片约占卡片 46%，横向 4:3；左侧为店名、位置、主营类别、评分。默认保持接口顺序，不按有无图片区别排序或布局；提供楼层筛选、店铺搜索、评分和店名排序。
- 店内菜单：桌面两列、容器不超过 38rem 时单列，左侧名称、评分与价格，右侧 4:3 大图。支持搜索、单价排序、更多菜品及返回店铺目录；无图同样保留图片位置。点击店铺后自动滚动到店名与筛选栏，留出顶部导航空间，并尊重减少动态效果设置。
- 口碑排行：独立纵向有序列表，醒目的连续名次，前三名使用 Wiki 蓝色与浅色背景强调；右侧单独显示平均分、评分人数及评论数。顺序来自服务端综合排序，不按平均分重排，追加页继续计数。
- 最新评价：宽度最多 35rem、在正文居中，使用作者、正文、大图、菜品链接的信息流。单图铺满内容宽度；两图并排；三图为一张主图加两张副图。所有菜品/评论展示图均为 4:3，点击预览保留原图比例；头像保持原有头像形状。
- 店铺、菜品卡片及排行使用 thumbnail 缩略图，详情和评价大图使用 medium 变体，点击放大才请求 displayUrl；所有图片保持懒加载。缺图不补虚构图片。
- 店铺、菜品、排行及评价评分显示金色五星条与数字，小数分数按比例填充；无评分显示灰星和“暂无评分”。保留评分人数或次数，评价标注“当时评分”。

## 复用与适配

- 直接复用：Docus 文档外壳、左右导航，以及 Nuxt UI 的 UButton、UTabs、UInput、USelect、UCard、UBadge、UAvatar、USkeleton、UModal、USeparator；配色来自现有 `--ui-*`，支持深浅色。
- 直接复用：用户食堂项目的无框架匿名 HTTP 客户端，来源和哈希见 `vendor/eat-in-wust/README.md`。
- 必要适配：`app/utils/food-api.ts` 类型接口及图片路径；未将 WXML/WXSS 小程序界面移植到 Wiki。
- 自行实现：餐饮列表装配、筛选和分页状态、详情与评价组合，以及固定上游的公开 GET 代理。

## 接口和数据语义

默认 API base 为 `/api/food`，上游为 `https://api-eat.wustacm.com/api/v1`。目录按食堂读取 `/stalls/feed?canteenId=...`，点击店铺才读取 `/stalls/:id/dishes` 完整店内菜单；不预取每家店的菜单。两级目录均本地搜索和增量展示，每批 12 条。店铺封面使用接口 `derivedCover`，它是后端选取的店内菜品图片，并非保证是门头照片。店铺聚合评分次数标为“次评分”，不当作独立人数。

口碑排行和最新评价使用各自接口的 `nextCursor`，每页 12 条。评分使用 rating / ratingCount；没有评分显示“暂无评分”。不使用兼容字段 reviewCount。评论显示发布时的 ratingSnapshot 和北京时间日期。异步请求以序号校验，快速切换范围时旧结果不会覆盖新结果；离开页面后忽略未完成请求的结果。

图片仅使用后端返回的 `/api/v1/media/:uuid[/thumbnail|/medium]` 路径，改为配置的 API base。图片缺失或失败时保留无图状态。代理保留 `private, no-store`，不缓存已撤回媒体。所有评论和菜名使用 Vue 默认转义。

## 本地运行

`pnpm dev`：Nitro 的 `server/api/food/[...path].get.ts` 提供代理。

`pnpm generate` 后执行 `pnpm preview:static`：预览脚本复用同一个代理模块，同时提供静态页面。使用终端显示的端口进入 `/life/food`。

代理实现位于 `server/utils/food-proxy.mjs`。仅允许页面需要的公开 GET 路径和查询参数；上游域名固定，不接受任意 URL，不传递 Cookie / Authorization，不提供用户或后台写接口。

## 部署边界

本轮仅本地实现，没有修改上游 CORS 或线上服务。实际 GET 已返回数据，但上游没有返回 `Access-Control-Allow-Origin`，所以独立域名浏览器不能直接按默认方式跨域读取。

**仅上传 `.output/public` 不会部署 Nitro 代理。** 静态托管平台需为 `/api/food/*` 配置同源转发，映射到上游 `/api/v1/*`，保留 GET 限制及媒体 no-store；或使用 Node 部署 `pnpm build` 的 Nitro 服务。另一个选项是上游明确配置 CORS 后，在生成前设置 `NUXT_PUBLIC_FOOD_API_BASE=https://api-eat.wustacm.com/api/v1`。静态生成中的 public 配置在构建时确定，修改后必须重新生成。

网页不提供评分/评论发布。现有小程序 wx.login 认证不能当作浏览器登录使用。

## 本轮验证（2026-09-22）

- `pnpm check:content`、`pnpm check:xupt`、`pnpm typecheck` 通过；静态生成 108 条路由。
- `node --test scripts/food-proxy.test.mjs scripts/food-preview.test.mjs`：5 项通过，覆盖路径限制、匿名转发、媒体不缓存、网络错误，以及图片流中断、客户端在上游响应前后取消请求时静态预览仍可继续服务。后一项需要先生成静态产物。
- `scripts/qa-food.cjs` 使用 Playwright + Edge，针对带只读代理的静态预览验证真实接口：店铺默认顺序、按需加载店内菜单、两级搜索、楼层筛选、单价排序、更多店铺、口碑分页、评价分页、详情、真实图片放大、食堂切换；另用明确的测试响应检查失败重试、空列表、过期请求隔离。检查桌面与 390px 手机视口、深浅色、菜单列数、进入店铺自动滚动、五星填充比例、缩略图路径、图片 4:3 及边缘贴合（隔离文章 img 外边距）；截图在被忽略的 `.cache/food-qa/`。
- `scripts/qa-navigation.cjs` 的直接访问、站内跳转和历史前进/后退精确高亮检查通过。
- 不把本地浏览器联调当作线上部署验收；没有修改线上代理、CORS、小程序、数据库或认证。价格和评价为接口内容，未现场核实。
