[English](tutorial.md) | **中文**

# Spec 驱动开发 -- 入门教程

> 理解如何让 AI 参与软件开发全生命周期，而不仅仅是写代码。
> 适用于：新成员入职 / 其他项目引入本系统。

---

## 第一章：我们解决什么问题

### AI 写代码的现状

AI 工具能写代码，但软件开发远不止写代码。

```
PM 交付 PRD -> 开发让 AI 写代码 -> 能跑吗？-> UI 对吗？-> API 通吗？
                                      |
                                 不知道，听天由命
```

| 问题 | 后果 |
|------|------|
| AI 不了解项目技术栈 | 生成的代码与现有架构不兼容 |
| AI 不了解设计稿 | UI 产出和 Figma 完全对不上 |
| AI 不了解后端 API 定义 | 请求参数靠猜，字段名对不上 |
| 没人追踪"做了什么、还剩什么" | 进度管理全靠口头同步 |
| 需求变更没有影响分析 | 改了 A，B 和 C 也要改——忘了 |

### 核心思路：在 PRD 和代码之间加一层

**结构化的"功能规格"是人与 AI 的共同语言。**

```
PRD（给人看的自然语言）
    | 解析 & 提取
Feature Specs（结构化，人和 AI 都能读）        <- 这是核心
    | AI 读取并执行
Code（给编译器的）
```

功能规格把分散的信息**合并到一个文件里**：

| 传统方式 | Feature Spec 方式 |
|----------|------------------|
| 需求在 PRD 第 N 页 | 结构化需求列表 |
| 设计在 Figma 链接 + 口头确认 | 设计约束 + Figma 节点引用 |
| 验收标准散落各处 | 明确的通过/失败条件 |
| API 在 Swagger + 聊天消息里 | API 端点引用 |
| 埋点在 Excel 表格里 | 结构化的埋点定义 |
| 多语言在翻译表格里 | 按功能分组的字符串表 |
| 状态场景全凭记忆 | 穷举的状态场景矩阵 |

AI 读这个文件就能获得完整上下文，无需反复解释。

---

## 第二章：系统概览

### 三个阶段

```
阶段 1：生成规格
    从 PRD + Figma + API 文档 -> 自动生成 Feature Specs + 任务计划
    （30 分钟完成传统方式 10+ 小时的工作）

阶段 2：编排执行
    分析任务依赖 -> 找到可并行的工作 -> 分发给 AI -> 监控进度

阶段 3：自主开发
    AI 在隔离环境中：读取规格 -> 写代码 -> 编译 -> 自动合并 -> 更新进度
```

### 一个版本的运转方式

```
1. 产品团队交付 PRD + Figma + Swagger

2. 自动生成规格骨架
   -> 10 个 Feature Spec 文件、多平台任务计划、后端依赖、i18n 字符串、埋点定义

3. 创建版本分支

4. 分析依赖图，规划并行批次
   -> Batch 1：4 个无依赖任务同时启动
   -> Batch 2：2 个任务依赖 Batch 1 的结果
   -> Blocked：等待后端 API，就绪后自动解除阻塞

5. 开发中途需求变更？
   -> 依赖索引即时定位影响范围 -> 自动生成返工清单

6. 实时看板
   -> 谁完成了、谁被阻塞了、阻塞原因是什么
```

### 核心文件一览

```
{version}/                           一个版本的全部规格
+-- config.yaml                      版本配置（功能列表、资源路径、依赖索引）
+-- features/                        Feature Specs（每个功能一个文件）
|   +-- F01-task-list.yaml             做什么 + 约束条件
|   +-- F02-create-task.yaml
|   +-- ...
+-- tasks/                           任务计划
|   +-- ios.md                         iOS 任务 + 状态
|   +-- android.md                     Android 任务 + 状态
|   +-- backend.md                     后端 API 依赖
|   +-- shared.md                      跨平台前置任务
+-- figma-index.md                   Figma 设计节点索引
+-- i18n/strings.md                  国际化字符串
+-- CHANGELOG.md                     变更记录
+-- DASHBOARD.md                     进度看板（从任务文件自动聚合）
+-- implementation/                  实现设计
|   +-- F01-task-list/
|       +-- design.md                  通用设计（跨平台）
|       +-- ios.md                     平台特有设计
+-- _logs/                           执行日志
```

---

## 第三章：核心概念

### 3.1 Feature Spec 文件 -- 一个功能的完整定义

两类字段：**做什么** + **约束**。

**做什么** -- 可从 PRD 自动提取：

```yaml
id: F01
name: Task List
description: |
  Display all tasks with filtering and sorting capabilities.

requirements:
  - id: R01
    desc: Show task list with title, status, and due date
  - id: R02
    desc: Support filtering by status (all/active/completed)

acceptance_criteria:
  - id: AC01
    type: ui
    desc: Task list displays in a scrollable list with pull-to-refresh
  - id: AC02
    type: interaction
    desc: Tapping a task navigates to task detail view
```

**约束** -- 需要人工或半自动补充：

```yaml
# 视觉约束 -- 必须做什么、禁止做什么
ui_contract:
  required:
    - Custom list cell with checkbox, title, and due date
  forbidden:
    - System default UITableViewCell
  key_tokens:
    cell_height: 64
    checkbox_size: 24
    brand_color: "#4A90D9"

# 穷举状态场景 -- 防止遗漏边界情况
state_matrix:
  - id: S01
    name: Empty state
    figma_node: "100:200"
    trigger: No tasks exist
    expected: Empty state illustration with "Add your first task" prompt
  - id: S02
    name: Loading state
    trigger: Initial data fetch
    expected: Skeleton loading placeholder
  - id: S03
    name: Error state
    trigger: Network request fails
    expected: Error view with retry button

# 量化尺寸 -- 拒绝"差不多就行"
pixel_baseline:
  cell_height: 64
  horizontal_inset: 16
  section_spacing: 8
```

**为什么要约束？** 没有约束，AI 只知道"做一个任务列表"，不知道用哪些组件、什么颜色、什么尺寸。结果就是：做完发现不对，反复返工。有了约束：一次到位。

**实际数据**：生产环境中，唯一一个约束写全的功能返工次数为 0。其余缺少约束的功能累计返工约 20 次。

### 3.2 任务文件 -- 进度的唯一事实来源

```
tasks/ios.md 中的一条任务：

| T01 | tasks | Task List | F01 | P0 | done | - |
```

状态流转：

```
pending -> active -> done
                       | 需求变更
                   rework -> active -> done
```

核心规则：**任务文件是唯一事实来源。** AI 在这里读写状态。进度看板从任务文件自动聚合。无需手动维护看板。

### 3.3 变更记录 -- 需求变更时怎么办

不是口头通知，而是：

```
1. 记录变更（编号 CR-001、CR-002...）

2. 通过依赖索引自动分析影响范围：
   这个 API 变了 -> 影响 Feature F01 -> 影响 Task T01 (iOS) + T01 (Android)

3. 生成返工清单，逐项完成并打勾

4. 全部完成 -> 变更记录标记为 done
```

**价值**：需求变更时不会遗漏更新。生产环境中 5 次需求变更通过变更记录全部做到了完整覆盖。

### 3.4 依赖索引 -- 反向查找表

版本配置中维护三张反向查找表：

| 查找方向 | 用途 |
|----------|------|
| API 端点 -> 功能列表 | API 变更时，立即定位受影响的功能 |
| Figma 节点 -> 功能列表 | 设计变更时，立即定位受影响的功能 |
| 功能 -> 后端任务列表 | 功能变更时，找到后端依赖 |

### 3.5 执行波次 -- 不是顺序执行，而是按依赖排序

分析任务间依赖关系，找出可并发执行的任务：

```
Wave 1: T01, T06, T07, T11  （无依赖，同时启动）
Wave 2: T02, T08             （依赖 Wave 1 的结果）
Wave 3: T03                  （依赖 Wave 2）
Blocked: T09                 （等待后端 API，就绪后自动解除阻塞）
```

### 3.6 AI 自主开发循环

AI 在隔离的 git 分支中独立完成一个任务的完整生命周期：

```
读取 Feature Spec -> 收集上下文（设计/API/i18n）
-> 锁定任务 (pending->active) -> 设计方案 -> 写代码 -> 编译 & 验证
-> 代码审查 -> 合并到版本分支 -> 更新状态 (active->done)
-> 下一个任务或退出
```

每个步骤不需要人工触发。AI 自行决定做什么、怎么做，完成后更新状态。**人的角色是审查和决策。**

### 3.7 执行日志 -- 事后可追溯

每次 AI 工作会话都会写一份日志。常见类型：

| 类型 | 何时产生 |
|------|----------|
| 功能开发 | 完成一个任务 |
| Review 修复 | 人工发起代码/UI 审查 |
| 截图驱动对齐 | 用户发送截图，AI 与 Figma 对比并修复 |
| 点修复 | 发现并修复一个 bug |
| 文档同步 | PRD / API 文档更新 |
| 变更记录 | 记录一个 CR |
| 流程复盘 | 聚合分析多轮日志，发现改进点 |

日志的价值：回答"**这个模块为什么经过 3 轮才收敛**"——是规格缺失？跳过了门禁检查？还是设计不明确？

---

## 第四章：一个完整示例

> 以假想的 Todo App 项目为例走一遍。只看不动手。

### 版本配置

`todo-app/config.yaml` -- 3 个功能、Figma 文件 key、1 个 Swagger 文件、依赖索引。**整个版本的"目录"。**

### 一个 Feature Spec

`todo-app/features/F01-task-list.yaml`（约 100 行）：

- 3 条需求，带结构化 ID
- 4 条验收标准
- 视觉约束：指定颜色、尺寸、组件规则
- 3 个状态场景，每个绑定到 Figma 节点
- 2 个 API 端点、i18n 引用

**AI 开发这个功能所需的全部上下文，都在这一个文件里。**

### 任务文件

`todo-app/tasks/ios.md` -- 3 个任务，逐任务跟踪状态。每个完成的任务有完成时间、合并 commit、实现摘要。**这就是 iOS 的进度板。**

### 变更日志

`todo-app/CHANGELOG.md` -- 初始为空。当变更发生时，每条变更有 CR 编号、影响范围和传播清单。

---

## 第五章：如何在自己的项目中使用

### 最小启动（10 分钟）

不需要全套上马。先从最高价值的部分开始。

#### 阶段 1：只写 Feature Spec 文件

创建目录，每个功能写一个 YAML：

```yaml
id: F01
name: User Login
description: Support phone number + verification code login

requirements:
  - id: R01
    desc: Enter phone number, tap send verification code
  - id: R02
    desc: Enter verification code, tap login

acceptance_criteria:
  - id: AC01
    type: interaction
    desc: Verification code 60-second countdown, button disabled during countdown

state_matrix:
  - id: S01
    name: No input
    trigger: Open login page
    expected: Phone number input focused, login button grayed out
  - id: S02
    name: Phone entered
    trigger: Enter 11-digit phone number
    expected: Send verification code button becomes active
  - id: S03
    name: Countdown active
    trigger: Tap send verification code
    expected: Button shows "Resend in Ns", not tappable
```

仅这一步就能给 AI 工具提供完整上下文。**不需要安装任何东西，不需要学任何命令。**

#### 阶段 2：加上任务文件

创建 Markdown 表格追踪进度：

```markdown
| ID | Task | Feature | Status | Deps |
|----|------|---------|--------|------|
| T01 | Login page UI | F01 | pending | - |
| T02 | Verification code flow | F01 | pending | T01 |
| T03 | Home list | F02 | pending | - |
```

完成一个任务，把 `pending` 改成 `done`。就这么简单。

#### 阶段 3：为复杂 UI 加上约束（可选）

只在 UI 密集的功能上投入；简单功能不需要：

```yaml
ui_contract:
  required:
    - Custom input field component
  forbidden:
    - System default TextField styling
  key_tokens:
    input_height: 48
    corner_radius: 8
    brand_color: "#FF6B00"
```

### 完整集成

实现完整自动化能力（自动生成、任务调度、并行开发）：

```
1. 按照本仓库的目录结构搭建项目
2. 配置版本信息（Figma key、Swagger 路径）
3. 使用生成工具从 PRD + Figma + API 自动生成规格骨架
4. 人工审查 + 补充复杂功能的视觉约束
5. 启动任务调度 -> AI 自主开发
```

具体的自动化命令和编排协议请参考仓库中的 `.claude/commands/` 目录。

### 裁剪指南 -- 哪些可以省略

| 组件 | 什么时候可以省略 |
|------|-----------------|
| 视觉约束 / pixel_baseline | 非 UI 功能、原型阶段 |
| Figma 集成 | 没有 Figma 的项目 |
| 多平台并行 | 单平台项目 |
| 变更记录追踪 | 需求稳定的小项目 |
| 执行日志 | 不需要事后分析 |
| 自动聚合看板 | 任务少于 10 个 |
| Git 分支隔离 | 一个人开发 |

**唯二不可省略的组件：Feature Spec 文件 + 任务文件。** 其余都是按需叠加。

---

## 第六章：常见问题

### Q：这和 Jira / Linear 有什么区别？

Jira 管的是"谁做什么"。Feature Spec 管的是"做什么 + 怎么约束 + AI 怎么执行"。

Jira 工单没有 Figma 节点绑定、没有穷举状态场景、没有视觉护栏。AI 读 Jira 只知道"做一个登录页"，不知道用哪些组件、什么颜色、哪些状态。

**两者互补，不冲突。**

### Q：需要会 YAML 吗？

不需要精通。YAML 就是缩进的键值对。看一个示例就能照着写。

大部分内容可以从 PRD 自动生成，人工只需要确认和补充少量字段。

### Q：绑定某种编程语言吗？

不绑定。Feature Spec 描述的是"做什么"，不是"用什么语言做"。

Swift、Kotlin、React、Flutter、Go 都行。唯一需要适配的是技术栈约束字段和构建命令。

### Q：一个人开发值得用吗？

只用 Feature Spec 文件 + 任务文件，10 分钟搭完。价值不在于"管理团队"，而在于**给 AI 结构化的上下文**。一个人开发时，AI 就是你的搭档，搭档需要理解你的需求。

### Q：这和 .cursorrules / copilot-instructions.md 是什么关系？

那些是"AI 编码风格配置"——告诉 AI 写代码时用什么语法。

Feature Spec 是"AI 工作上下文"——告诉 AI 做哪个功能、做到什么标准、有哪些约束。

```
.cursorrules       -> "使用 Swift 5，MVVM 架构，SnapKit 布局"
Feature Specs      -> "做一个登录页，3 种状态，这些颜色，禁用系统 Alert"
任务调度            -> "先做 T01，再做 T02，T03 等后端 API"
```

不同层级，配合使用。

### Q：规格写太细会不会浪费时间？

取决于功能复杂度。我们用 `ui_weight` 分三档：

| 档位 | 范围 | 约束力度 |
|------|------|----------|
| heavy UI | 弹窗、面板、新页面 | 视觉约束 + pixel_baseline + 状态场景 |
| light UI | 列表项、文案改动 | 状态场景就够了 |
| logic only | 埋点、API 对接 | 不需要约束 |

**返工频率高的地方投入约束，返工少的地方省略。** 不搞一刀切。

---

## 附录：延伸阅读

理解本教程后，按需查阅详细文档：

| 想了解 | 阅读 |
|--------|------|
| 所有术语的精确定义 | `docs/glossary.md` |
| 架构设计与数据流 | `docs/architecture.md` |
| 规格生成流程 | `docs/spec-generation.md` |
| 任务执行协议 | `docs/exec-protocol.md` |
| 视觉约束规则 | `workflows/ui-contract.md` |
| 生成协议 | `.claude/commands/spec-init.md` |
| 编排协议 | `.claude/commands/spec-drive.md` |
| AI 自主执行循环 | `.claude/commands/spec-next.md` |
| 一个完整示例项目 | `examples/todo-app/` |
