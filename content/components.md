---
title: 正文组件
description: Markdown 与 MDC 组件用法
status: published
navigation: false
---

## 链接卡片

[查看直接复用的原博客组件示例](/blog-components)。本页为此前适配版本。

::link-card{title="住宿生活" description="宿舍信息、环境配置、缴费" link="/campus/accommodation" icon="i-lucide-house"}
::

```mdc
::link-card{title="住宿生活" description="宿舍信息、环境配置、缴费" link="/campus/accommodation" icon="i-lucide-house"}
::
```

## 提示框

::wiki-callout{type="warning" title="适用范围"}
办理流程请按所在校区的最新通知核对。
::

```mdc
::wiki-callout{type="warning" title="适用范围"}
办理流程请按所在校区的最新通知核对。
::
```

`type` 支持 `tip`、`info`、`warning`。

## 折叠块

::folding{title="展开查看补充说明"}
这里支持 **Markdown**、列表和链接。

- 补充信息
- [入学办理](/campus/enrollment)
::

```mdc
::folding{title="补充说明"}
这里支持 **Markdown**。
::
```

## 表格

| 校区 | 内容 | 核实日期 |
| --- | --- | --- |
| 待填 | 待填 | 待核实 |
