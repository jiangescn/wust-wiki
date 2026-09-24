# 社区成绩展示方案调研

日期：2026-09-24。范围：公开项目说明、源码及许可证；未读取个人成绩，未安装或登录这些应用。本轮仅调研，没有修改 Wiki 应用、推送或部署。以下区分上游已核实功能与针对 Wiki 的设计建议。

## 精选案例

| 项目 | 已核实的展示方式 | 对 Wiki 最有价值的部分 | 复用边界 |
| --- | --- | --- | --- |
| 武科大助手 | 历史版本说明包含成绩卡片、点击详情、顶部平均绩点、学期筛选；后续版本提到成绩图表测试与等级制成绩修复 | 同校用户习惯：先看成绩，详情按需打开 | 仅核对产品版本记录，未核实当前安装版或对应源码许可 |
| 福大助手 / 福 uu | 学期页签、学期摘要、单科卡片，成绩大字显示，学分和绩点较小 | 移动端信息主次清晰，学期切换后只显示相关课程 | React Native；LICENSE 为 AGPL-3.0，README 另有非官方应用复用限制，不作为本项目直接复制候选 |
| ZJUCoursetrace | 总览卡、分数分布、主修/全部切换；按学期从新到旧分组，组头显示课程数和学期均绩；单科显示课程名、学分、成绩、绩点及进度条 | 学期分组和紧凑课程条目，帮助快速回看往期成绩 | React Native / Expo，MIT；组件不能直接放入 Vue，需做框架适配；浙大五分制不可沿用 |
| GPA Simulator | 按学期分块、按成绩排序和配色；汇总当期与累计绩点；可以模拟修改成绩、添加课程 | 学期维度的层次与汇总区 | React / CSS，MIT；不是现成 Vue 组件；模拟功能不适合直接混入官方查询结果 |

### 1. 武科大助手：同校产品参照

[App Store 版本记录](https://apps.apple.com/ni/app/%E6%AD%A6%E7%A7%91%E5%A4%A7%E5%8A%A9%E6%89%8B/id1538426487)中的 3.1.0 说明包含卡片点开详情、顶部平均绩点和学期筛选；3.6.0 提及成绩图表测试，3.6.3 提及等级制成绩修复。适合作为产品交互参照，但版本说明不是当前版本的实际交互验证，也不能证明其图表已经稳定可用。本次没有找到并核对与这些版本对应的可移植 Vue 成绩组件。

### 2. 福大助手：学期摘要 + 成绩卡片

源码核对基准：`1955bf1abd01c9c0ca4d43fc77500c68f1c44d8f`。

- [成绩页](https://github.com/west2-online/fzuhelper-app/blob/1955bf1abd01c9c0ca4d43fc77500c68f1c44d8f/app/toolbox/academic/grades.tsx)：本地按学期筛选，按分数降序；列表头放摘要，支持下拉刷新和更新时间。
- [课程卡片](https://github.com/west2-online/fzuhelper-app/blob/1955bf1abd01c9c0ca4d43fc77500c68f1c44d8f/components/academic/GradeCard.tsx)：上方课程名称及考试类型，中间教师与课程类型，下方学分、绩点和醒目的分数。
- [摘要卡片](https://github.com/west2-online/fzuhelper-app/blob/1955bf1abd01c9c0ca4d43fc77500c68f1c44d8f/components/academic/SemesterSummaryCard.tsx)：课程数、应修学分、最高分、学期绩点；明确标注自行计算的学期绩点非教务系统数据。
- [项目说明](https://github.com/west2-online/fzuhelper-app/blob/1955bf1abd01c9c0ca4d43fc77500c68f1c44d8f/README.md)与 [LICENSE](https://github.com/west2-online/fzuhelper-app/blob/1955bf1abd01c9c0ca4d43fc77500c68f1c44d8f/LICENSE)：此次只借鉴信息结构，不复制其源码或素材。

原生移动布局已由源码确认；没有声称其桌面 Web 自适应已验证。其独立“绩点排名”页面依赖学校额外接口，不是仅有单科成绩就能得出的功能。

### 3. ZJUCoursetrace：按学期组织的成绩详情

源码核对基准：`ade7740dbe9ff7bb244253c79e772ab5e6f9b91d`。

[grade-detail.tsx](https://github.com/Jnove/ZJUCoursetrace/blob/ade7740dbe9ff7bb244253c79e772ab5e6f9b91d/app/grade-detail.tsx)实际包含 `groupGradesBySemester`、`CompactGpaCard`、`ScoreDistributionCard`、`GradeItem` 与 `SectionList`。分数分布只纳入可解析的数字成绩；课程条目保留文字成绩，缺失绩点显示占位。概览采用五分制进度，学期均绩按有绩点课程的学分加权。

这是**分布图**，不能称作跨学期趋势折线图。布局依赖 React Native，许可证为 [MIT](https://github.com/Jnove/ZJUCoursetrace/blob/ade7740dbe9ff7bb244253c79e772ab5e6f9b91d/LICENSE)。适合参考分组结构，但不直接搬五分制、颜色阈值、学期命名或缓存策略。

### 4. GPA Simulator：学期分块与绩点回溯

[README](https://github.com/PkuCuipy/gpa-simulator/blob/master/README.md)与 [App.js](https://github.com/PkuCuipy/gpa-simulator/blob/master/src/App.js)说明并实现学期分组、分数排序、成绩着色、当期及累计绩点汇总。它是 PKU Helper 成绩页的复刻增强项目，允许编辑与新增模拟课程；旧版 Token 导入已被项目明确标记失效。

[LICENSE](https://github.com/PkuCuipy/gpa-simulator/blob/master/LICENSE)为 MIT；React JSX 界面需要适配 Vue，README 另注明部分彩虹动画来自旧 PKU Helper，若实际提取该部分仍须追溯原始来源。Wiki 可以参考分组思路，不沿用其北大换算公式、成绩修改操作或满分彩虹动画。这里核对的是汇总表及回溯逻辑，没有把它描述为趋势折线图。

## 针对当前 Wiki 的建议（尚未实现）

当前页面已有查询、学期筛选和课程搜索，继续复用现有 Vue / Nuxt UI 外壳即可。

1. **桌面紧凑表格**：保留课程、成绩、学分、绩点、详情五个主列。课程代码、性质、考核方式、补重修及备注移到展开详情，降低横向阅读负担。
2. **手机成绩卡片**：第一行课程名与醒目的成绩，第二行学分、绩点及必要状态；点开看完整字段。避免把七列表格压进手机屏幕。
3. **全部学期按学期分组**：最新学期在前，保留现有学期筛选与搜索，不让用户在长列表里反复识别每行的学期。
4. **克制使用颜色**：正文保留统一色系，仅对明确异常或状态作辅助标记，同时显示文字；无需给每门成绩卡片分配不同颜色。
5. **汇总与图表稍后确认**：可以先显示课程记录数。平均绩点、已修学分、通过率和趋势要先核对武科大纳入课程、等级制、补考重修及重复记录口径；不把外校算法当作本校官方结果。

当前接口未提供排名、平时分或期末分的独立字段，因此不设计这些栏目。查询与模拟应保持明确区分；本轮不增加成绩编辑、持久缓存或新的数据采集。

## 验证边界

- 已阅读上述公开源码、项目说明及许可；武科大案例依据公开产品版本记录。
- 未在这些项目内登录账号，未核验学校接口可用性，未测试其已发布应用或桌面响应式效果。
- 本文的 Wiki 布局是设计建议，不代表已经实现。原有登录、缓存和部署约定保持现状。
