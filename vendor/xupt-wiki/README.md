# 西邮 Coder 原版组件迁移

## APP 列表模板补充（2026-09-13）

同一上游提交的 `docs/.vitepress/components/unique/LinkList.vue` 已迁入运行副本和源码快照，清单增加该组件（共14个）。仅替换类型导入路径并显式导入现有原版 Link，template/style 保持原样。以下 Coder 13组件的历史范围不包含此新增模板。

`app/components/content/AppDirectory.vue` 为薄包装，`app/data/campus-apps.ts` 保存当前 WUST 页已有的9个条目；`content/1.campus/6.apps.md` 按组调用。可填写 text、desc、icon、link，未核实的图标和链接暂不填写，原表格保存在折叠区。没有导入西邮应用名单，也没有新增官方验证声明。卡片组件依照原版无链接时渲染为文本，填写已核实 link 后才可跳转。

来源：[xupt-wiki/xupt-wiki](https://github.com/xupt-wiki/xupt-wiki)，提交 `f1ba156d8f91374422921df51a9bc26703c298ab`。
对应原页面：[/coder/](https://wiki.cooo.site/coder/)、[/coder/blog](https://wiki.cooo.site/coder/blog)。

## 原版复用范围

`components/` 保存上游 12 个 Vue 组件，运行副本在 `app/xupt/components/`：

- 页面组件：LabList、LabItem、BlogList、BlogCard、CoderGuild。
- 依赖组件：BlurCard、Link、Dropdown、Qrcode、Tip、TextEllipsis、SearchExcerpt。
- Badge 直接取自原项目依赖 VitePress `2.0.0-alpha.19` 的 VPBadge，源码、变量和许可在 `vitepress/`。

全部 13 个组件的 style 块保留原样，包括实验室悬停 `rotateY` 翻面（0.3s）、TransitionGroup 排序位移（0.3s）、博客头像/访问箭头/标签/链接的透明度过渡（0.2s）。没有另写一套动画。

`app/components/content/CoderDirectory.vue` 负责选择页面装配。`/coder/` 从 2026-09-15 起由 `app/components/content/WustLabList.vue` 读取武科大数据，卡片继续直接复用原版 LabItem、BlurCard、Link 和 QQ 群头像工具；`/coder/blog` 同日起由 `WustBlogList.vue` 读取武科大数据，继续直接复用原版 BlogCard。`app/pages/coder/index.vue` 和 `blog.vue` 使用原页面宽布局，保留 Wiki 顶部导航、底部和原路由。

## 必要适配

本地图片适配：原版 Link 只识别 http 图标图片，运行副本现同时识别以 `/` 开头的站内图片路径（例如 `/images/app/today.jpg`）。Iconify 名称仍走 Icon 组件；原有样式和动画不变。`public/` 不写入资源 URL。原版卡片将图片作为右侧低透明度背景展示，这是其原有样式。

1. 将上游 `@/components`、`@/utils` 改为本库相对路径；名单继续读取 `app/data/coder/`，保留可维护位置。
2. 上游主题全局注册的 Icon、Link、BlurCard、Badge、Qrcode 改为组件内显式导入，避免覆盖 Nuxt 与博客组件的同名组件。Icon 仍为 `@iconify/vue`；Tooltip/v-tip 共用现有同库同配置插件。
3. BlogList 挂载回调改用 `onNuxtReady`，防止 Nuxt hydration 恢复 URL 前丢失 `?shuffle=false`。实验室仍与原版一致，在挂载时随机排序，不额外提供固定排序参数。
4. 原 Link 的相对培养计划链接通过 `app/utils/coder.ts` 指向西邮站，避免误跳到不存在的 WUST 页面。
5. 原 VitePress 变量接入 `app/assets/xupt-variables.css`，限定 `.xupt-coder` 作用范围；`xupt-coder.css` 接入上游页面边距、图标、链接、Badge 与浮层规则。原站全局主题没有替换 Wiki 外壳。
6. 原图标的 14 个 SVG 数据静态打包在 `app/xupt/icons.json`，由 `app/plugins/xupt-icons.ts` 注册，避免动画控件依赖图标 API。数据来自已安装的 `@iconify-json/ri` 和 `@iconify-json/ph`。新增图标时补充对应数据。

`utils/`、`data/`、`pages/`、`theme/` 为本次使用的上游快照。成员工具保留其原始辅助函数与 members 数据，当前卡片主要使用 getAvatar。头像仍由原站使用的 GitHub 代理和 QQ 服务提供。

## 行为与数据边界

- 武科大 Coder 条目使用原版 LabItem 和 hover 翻面；触屏浏览器继续依赖原版轻触 hover 行为，未新增自定义触摸状态机。
- 博客保留原版悬停透明度、访问箭头、GitHub/RSS 槽位和排序动画；首批武科大数据未提供 GitHub 与 RSS，因此相应入口不显示。运行适配为 Blog 类型补充可选 `avatar` 字段，当前图片取自各博客主页声明或实际引用的资源，不经过第三方图标服务。
- 原频道入口通过悬停展示原 Qrcode 动态生成的二维码，保留访问链接。
- `/coder/` 与 `/coder/blog` 名单均已替换为用户提供的首批武科大静态条目；未提供的学院、地点、官网、招新、年级、标签、GitHub 和 RSS 信息保持为空。两者均未接入实时同步。

## 检查

```powershell
pnpm check:xupt
pnpm check:content
pnpm typecheck
pnpm generate
```

`migration-manifest.json` 记录原始与运行副本 SHA-256；`check:xupt` 检查快照、运行副本以及全部原样 style 块。修改适配代码后复核差异并更新清单，不要为通过检查盲目刷新哈希。

可选浏览器检查 `scripts/qa-xupt.cjs` 需要环境可解析 Playwright 且安装 Edge；先启动服务，再设置 `WIKI_QA_URL` 并运行 `node scripts/qa-xupt.cjs`。该脚本不属于生产依赖，未将个人电脑的 Playwright 路径固化进项目。

2026-09-13 验证：13 个组件源码与原样 style 校验通过，类型检查通过，静态生成 108 条路由；内容检查为 31 篇文档、15 个入口、43 个内部链接。生产静态预览中验证了 20 个实验室、35 个博客、3D 翻面、两个列表的实际 v-move 过渡、博客透明度过渡、群号/RSS 复制、二维码浮层、相对外链、深色模式和 390px 无整页溢出；触屏模拟轻触翻面、首页入口跳转和普通正文检查通过。未捕获运行时或 hydration/组件解析警告。完整博客组件示例回归通过；外部媒体实际播放不在本次验证范围。

## 许可

上游代码 MIT，见本目录 LICENSE；VitePress MIT 见 `vitepress/LICENSE`。名单、参考内容及素材沿用上游相应声明，详见项目 `THIRD_PARTY_NOTICES.md`；头像权利归各自权利人。
