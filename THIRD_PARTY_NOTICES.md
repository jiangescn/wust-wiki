# 第三方来源

## 正文组件：blog-v3

来源：https://github.com/L33Z22L11/blog-v3

核查版本：`f6ea97d745517feb52f0c100e89acb36f0adc12f`。

`LinkCard.vue`、`WikiCallout.vue`、`Folding.vue` 分别改编自上游 `LinkCard.vue`、`Alert.vue`、`Folding.vue`。
移除了博客专属配置、工具与状态管理依赖，改用 NuxtLink、Nuxt UI 图标和当前主题配色，样式位于 `app/app.css`。
这三个历史适配组件仍保留；本次完整原版迁移另见下节。下列 MIT 许可适用于代码。

MIT License

Copyright (c) 2024 Zhilu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## blog-v3 原版示例组件

`vendor/blog-v3/components/` 保存同一提交全部 27 个正文组件的原始快照，`app/clarity/` 为运行副本，另含 BlogHeader、图片工具、按钮和灯箱依赖；原许可证见 `vendor/blog-v3/LICENSE`。运行副本中 25 个正文组件与上游逐字节一致，FeedCard/FeedGroup 仅调整类型导入路径；其他必要适配详见 `vendor/blog-v3/README.md`。

组合函数、工具、Tippy 插件、Markdown 插件、Shiki 配置及相关 SCSS 也取自该提交。`patches/plain-shiki.patch` 直接沿用上游补丁。样式只引入所需的变量与运行规则，不引入原站全局布局重置。

`vendor/blog-v3/example.md` 是上游 `content/previews/example.md` 的原始快照，页面自身声明通过 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/deed.zh-hans) 贡献至公共领域。`content/blog-components.md` 保留其正文，仅替换页面元数据并补充友链组件实例。此声明不适用于作者其他文章。

`public/fonts/AlimamaFangYuanTi.woff2` 为上游提供的阿里妈妈方圆体子集，字体权利归原作者，来源链接保留在示例正文。远程图片、音色和视频仍由对应站点提供，不被视为 MIT 代码素材。

## 栏目与首页入口：西邮 Wiki

来源：https://github.com/xupt-wiki/xupt-wiki

参考版本：`f1ba156d8f91374422921df51a9bc26703c298ab`。

保留 `docs/index.md` 的入口顺序、标题和简短描述，并按 WUST 修改学校名称；导航参考 `docs/.vitepress/config.mts`。
Coder 目录使用同一参考版本的 `docs/.vitepress/data/labs.json`（20 项）和 `blog.json`（35 项）作为明确标注的西邮参考数据，保留原始事实字段与来源，不代表 WUST 的实验室或校友。未迁入校徽。
Coder 已由自行实现替换为原版迁移：`vendor/xupt-wiki/` 保存上游 12 个组件和工具、页面、数据、样式快照，`app/xupt/` 为运行副本。保留原组件全部动画 style 块，仅调整导入、Nuxt 生命周期与相对链接，详见该目录 README 和迁移清单。VitePress `2.0.0-alpha.19` 的 VPBadge 与主题变量一并复用，MIT 许可见 `vendor/xupt-wiki/vitepress/LICENSE`。参考目录数据沿用上游内容的 CC BY-NC-SA 4.0 署名与共享说明；头像由上游使用的 GitHub 代理和 QQ 服务加载，权利归各自权利人。静态图标来自 Iconify 的 Remix Icon 和 Phosphor 集合，保留安装包所附许可。
对参考首页的文字保留 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) 署名及相同方式共享说明；上游代码许可证另见 `licenses/xupt-wiki-MIT.txt`。

## 文档框架：Docus

来源：https://github.com/nuxt-content/docus ，使用版本 5.13.0。

通过 Nuxt layer 使用其文档布局、内容导航和搜索。`patches/docus@5.13.0.patch` 是类型兼容补丁，许可证见 `licenses/docus-MIT.txt`。
