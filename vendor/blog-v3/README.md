# blog-v3 完整组件迁移

源项目：https://github.com/L33Z22L11/blog-v3

固定提交：`f6ea97d745517feb52f0c100e89acb36f0adc12f`。

原示例：https://blog.zhilu.site/previews/example

## 文件位置

- 本目录 `components/`、`util/`、`blog/`、`popover/`、`partial/`、`example.md`：原始源码快照。
- `app/clarity/`：运行副本，包含全部 27 个正文组件，以及 BlogHeader、图片/链接工具、灯箱和按钮依赖。
- `app/composables/useShiki.ts`、`useCopy.ts`，`app/utils/{anim,img,icon,link,str,time}.ts`：原博客的组合函数与工具。
- `content/blog-components.md`：完整原示例正文，仅替换页面元数据并补入 FeedGroup 实例；原页面只介绍这两个友链组件，没有实际实例。
- `app/pages/blog-components.vue`：Docus 布局适配，正文使用原组件映射，原插件提取的侧栏与许可插槽在相应位置渲染。
- `migration-manifest.json`：逐组件来源和是否保持原样的清单。

访问 `/blog-components` 或 `/previews/example`。全部原正文组件以 `Blog` 前缀注册，其他文档可使用 `::blog-pic`、`::blog-tab` 等；原示例页通过映射保留 `::pic`、`::tab` 的原始写法。

## 必要适配

1. FeedCard、FeedGroup 只将类型导入 `~/types/feed` 改为库内相对导入。
2. BlogHeader 只将 `useAppConfig` 替换为 `useBlogComponentConfig`，避免其 header 字段和 Docus 配置冲突。
3. `BlogInlineCodeBridge` 把 Content 3.15 的行内代码插槽转换为原 ProseCode 所需的 code 属性。
4. time.ts 的 DateTimeUnit 替换为当前 Temporal 包的等价类型联合；运行逻辑不变。
5. 原 SCSS 色彩、字体变量、动画、文章和可复用样式接入 Wiki；article/reusable 文件补充 Sass 变量导入，main.scss 仅提取相关变量与运行样式，避免全局重置 Wiki 布局。
6. Shiki CDN 导入通过 Nuxt alias 指向已安装的同版本 Shiki，避免代码高亮依赖远程 JS；plain-shiki 补丁直接沿用上游。
7. 文章与复用样式通过 `:where(.blog-components)` 限定范围，不能改回普通 `.blog-components` 前缀：后者会抬高选择器优先级，覆盖 Badge 图片高度与 ProsePre 行号留白。
8. KaTeX CSS 与 `rehype-katex@7.0.1` 实际使用的渲染器统一为 `0.16.47`。升级时同时核对 HTML 结构与 CSS，不能只升级直接依赖，否则分数等布局会重叠。

示例侧栏在 1024px 及以下转为正文上方布局，600px 及以下单列；卡片保留内边距。顶部搜索通过 UContentSearchButton 的 trailing 插槽使用原版 BlogKey，搜索打开逻辑仍由原框架负责，不另写快捷键系统。

除上述接口、类型与样式作用范围差异外，保留原逻辑。图片灯箱、乐谱、Mermaid、浮层和代码高亮均使用原项目依赖包，不提供另写的替代实现。

原组件仍有自身约束：外部图片、音色和视频由对应站点提供；乐谱只有检测到音色服务器可达才展示播放能力；Blur 沿用 hover 行为。

## 验证记录（2026-09-13）

生产静态生成通过（108 条路由），Nuxt 类型检查通过，内容检查通过（31 篇文档、15 个首页入口、44 个内部链接）。Edge 浏览器验证了两个示例路径、标签切换、代码展开/复制、可编辑命令及撤销、图片灯箱、友链浮层、按键反馈、表格换行、Mermaid 渲染/缩放/深色切换、两份乐谱及播放控件；390px 手机视口没有整页横向溢出，未捕获运行时异常或组件解析警告。原 Coder 两页交互回归检查通过。

灯箱自动检查使用本地图像响应替代随机图片服务；外链图片可用性、外部视频播放与乐谱实际出声未作为已验证结果。

后续样式修复增加 `scripts/qa-blog-layout.cjs`：检查已加载的徽章图片尺寸、代码块行号留白、KaTeX strut 布局、390/768/900/1024px 侧栏与整页溢出，以及搜索按键组件的点击和 Ctrl+K。随机图片使用固定 100px SVG 响应，避免图片尚未加载造成尺寸检查假通过。构建、类型检查与原组件核心交互回归通过。

## 许可

代码 MIT，见 LICENSE。example.md 自身声明 CC0 1.0；保留原作者与来源。阿里妈妈方圆体子集来自上游 public/fonts，权利归字体作者；其他文章和素材不因此视为 MIT。详见项目 THIRD_PARTY_NOTICES.md。
