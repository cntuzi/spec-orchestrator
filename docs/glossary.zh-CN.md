[English](glossary.md) | **中文**

# Spec 系统术语表

> 所有核心术语的定义与关系。阅读此文档以理解整个 spec 系统。

---

## 规格层 -- What + Constraint（定义做什么、怎么约束）

### Feature YAML

功能规格文件，位于 `{project}/{version}/features/F{nn}-{name}.yaml`。是功能的**唯一权威定义**，包含 What（做什么）和 Constraint（如何约束）两类字段。

**What 字段**（可自动生成）：

| 字段 | 含义 |
|------|------|
| `id` / `name` / `module` / `epic` | 功能标识与分组 |
| `description` | 功能描述（来源于 PRD） |
| `requirements` | R01-Rnn 需求条目 |
| `acceptance_criteria` | AC01-ACnn 验收标准，按 ui / interaction / data 分类 |
| `figma.pages[]` | 关联的 Figma 设计页面及 node_id |
| `api[]` | 关联的后端接口定义 |
| `analytics[]` | 埋点事件（type / stype / frominfo / trigger） |
| `i18n_ref` | 国际化字符串引用（指向 strings.md） |
| `platform_tasks` | 平台任务映射（ios: T{nn}, android: T{nn}, backend: B{nn}） |
| `dependencies` | 功能间依赖关系 |

**Constraint 字段**（需要人工或半自动补充）：

| 字段 | 含义 |
|------|------|
| `ui_contract` | UI 契约 |
| `delivery_contract` | 交付契约 |
| `state_matrix` | 状态矩阵 |
| `pixel_baseline` | 像素基线 |
| `conflict_resolution` | 冲突决策记录 |
| `verification_evidence` | 验收证据 |

**分工**：`/spec-init` 自动生成 What 字段 + Constraint 骨架（标记 TODO），人工按优先级补充 Constraint。

---

### UI Contract (ui_contract)

定义功能的**视觉约束契约**，写在 Feature YAML 中。

| 子字段 | 含义 | 示例 |
|--------|------|------|
| `source_nodes` | Figma 设计节点 ID，按状态/场景命名 | `empty_state: "100:200"` |
| `required` | 必须包含的结构/组件/交互 | `Custom list cell with checkbox` |
| `forbidden` | 禁止的实现方式 | `System default UITableViewCell` |
| `key_tokens` | 关键视觉参数（尺寸/颜色/圆角） | `cell_height: 64` |
| `visual_blockers` | 阻塞验收的视觉问题 | `List must support pull-to-refresh` |

**核心原则**：视觉是阻塞项——视觉门禁检查不通过，任务状态不得标记为 done。

---

### Delivery Contract (delivery_contract)

定义功能的**技术栈约束**，写在 Feature YAML 中。

| 子字段 | 含义 |
|--------|------|
| `stack_baseline` | 各平台必须使用的技术栈（如 iOS: UIKit + DiffableDataSource） |
| `ui_split` | UI 实现分层：L1-结构 -> L2-视觉 -> L3-交互状态 -> L4-验收证据 |
| `data_contract` | 字段数据来源优先级（如 `source_priority: [server, local_cache]`） |

---

### State Matrix (state_matrix)

穷举功能的**所有关键状态场景**，防止遗漏边界情况。写在 Feature YAML 中。

每条记录包含：

| 字段 | 含义 |
|------|------|
| `id` | 标识符（S01, S02...） |
| `name` | 状态名称 |
| `figma_node` | 对应的 Figma 设计节点 ID |
| `trigger` | 何种操作/条件触发此状态 |
| `expected` | 进入此状态后的预期行为 |

**价值**：每个状态绑定 Figma 节点 -> 开发时定位设计稿 -> 验收时逐项检查。

---

### Pixel Baseline (pixel_baseline)

关键控件的**量化尺寸/间距/点击区域**，拒绝"看着差不多就行"。写在 Feature YAML 中。

```yaml
pixel_baseline:
  nav:
    bar_height: 44
    back_tap_area: "44x44"
  form:
    horizontal_inset: 16
    section_spacing: 8
```

---

### Conflict Resolution (conflict_resolution)

PRD、Figma、API 三方出现矛盾时的**决策记录**。写在 Feature YAML 中。

```yaml
conflict_resolution:
  - key: "Button height"
    figma: "48pt"
    prd: "44pt"
    decided_source: figma
    owner: design
    decision_date: "2026-03-20"
```

---

### Acceptance Criteria (acceptance_criteria)

AC01-ACnn 验收条目，分三种类型：

| 类型 | 含义 |
|------|------|
| `ui` | 视觉验收（对照 Figma） |
| `interaction` | 交互验收（操作流程） |
| `data` | 数据验收（API/存储） |

---

### config.yaml

版本配置中枢，位于 `{project}/{version}/config.yaml`。

核心区块：

| 区块 | 含义 |
|------|------|
| `version` / `codename` | 版本标识 |
| `figma.file_key` | Figma 设计文件 key |
| `paths` | 版本内所有资源的路径映射 |
| `api.swagger_files` | 后端 Swagger 文件列表 |
| `features[]` | 功能快速索引（id / name / module / priority） |
| `dependency_index` | 反向索引（见下文） |

---

### Dependency Index (dependency_index)

config.yaml 中的**反向查找表**，用于变更影响分析。

| 子索引 | 方向 | 用途 |
|--------|------|------|
| `api_to_features` | API 端点 -> 功能列表 | API 变更时定位受影响的功能 |
| `figma_to_features` | Figma 节点 -> 功能列表 | 设计变更时定位受影响的功能 |
| `feature_to_backend` | 功能 -> 后端任务列表 | 功能变更时定位后端依赖 |

---

## 任务层 -- Who + Sequence（定义谁来做、什么顺序）

### Task (T{nn})

平台开发任务，写在 `tasks/ios.md` 或 `tasks/android.md` 中。**单一事实来源**——任务当前状态只在此处读写。

与 Feature 的关系：F{nn} 与 T{nn} 编号对齐（一对一）。每个 Feature 在每个平台有一个 Task。

### Backend (B{nn})

后端 API 任务，写在 `tasks/backend.md` 中。独立编号（不与 F/T 绑定）。作为前端任务的前置依赖。

### Shared (S1-S3)

跨平台前置条件，写在 `tasks/shared.md` 中：

| ID | 条目 |
|----|------|
| S1 | PRD 已确认 |
| S2 | 设计已评审 |
| S3 | API 已定义 |

### 状态生命周期

```
pending --Lock--> active --Pass--> done
                    |                 |
                    | Fail            | CR change
                    v                 v
                  blocked         rework --Propagate--> active -> done
```

| 状态 | 含义 |
|------|------|
| pending | 未开始 |
| active | 进行中 / 已阻塞 |
| done | 已完成 |
| rework | 需返工（CR 变更后） |
| n/a | 不适用 |

### Wave

根据任务依赖列构建 DAG，规划**并行执行批次**：

- Wave 1：无依赖的任务，可并行执行
- Wave 2：依赖 Wave 1 的任务
- Blocked：等待后端 API 的任务

### DASHBOARD

进度看板，位于 `{project}/{version}/DASHBOARD.md`。从 `tasks/*.md` **聚合生成**；Worker 不直接修改。

---

## 编排层 -- Pipeline（定义流水线）

### spec-init

生成层命令。从 PRD + Figma + Swagger **一次性生成完整的 spec 骨架**。

三种模式：

| 模式 | 命令 | 用途 |
|------|------|------|
| generate | `/spec-init 1.0` | 全量生成 |
| refresh | `/spec-init 1.0 refresh` | 增量追加 |
| validate | `/spec-init 1.0 validate` | 仅校验 |

### spec-drive

编排层命令。任务分析 + 依赖图 + worktree 创建 + Worker 派发 + 状态监控。

| 子命令 | 用途 |
|--------|------|
| `setup` | 检查 spec 完整性 -> 创建版本分支 |
| `next` | 智能分析 -> worktree -> Worker 派发 |
| `status` | 聚合跨平台进度 -> 更新 DASHBOARD |
| `change` | 记录 CR + 影响分析 |
| `propagate` | CR 代码返工 |
| `reset` | 重置卡住的任务 |
| `verify` | 版本分支编译检查 |
| `done` | 版本完成总结 |

### spec-next

执行层命令（Worker 视角）。查看所有平台任务状态，定位下一个可执行任务。

### Worker

在 worktree 中**自主开发**的 AI 代理，遵循 11 步循环：

```
Config -> Status -> Resolve -> Context -> Lock -> Analyze -> Execute -> Review -> Merge -> Update -> Loop
```

退出条件：所有任务完成 / 所有任务阻塞 / 连续 2 次失败。

### Worktree

用于隔离开发的 Git worktree。每个任务一个 worktree，合并后清理。

分支命名：`feat/{project}/{MMDD}/T{nn}-{name}`

---

## 变更管理 -- Change（定义怎么改）

### CR (Change Record)

变更记录，编号 CR-001、CR-002...，记录在 `CHANGELOG.md` 中。

每条 CR 包含：变更来源、影响范围、传播检查清单。

### Propagate

CR 传播流程：

```
CR 记录 -> 创建 worktree -> 仅应用变更 -> 构建 -> 评审 -> 合并 -> 检查清单全部 [x] -> CR 完成
```

---

## 执行可观测性 -- Observability（定义怎么记录）

### 工作类型

| 类型 | 定义 |
|------|------|
| **task** | 功能开发（T{nn}） |
| **sync** | 外部文档同步（PRD/API/Figma） |
| **change** | 需求变更记录（CR-{nnn}） |
| **review** | 代码/UI 评审 |
| **visual-qa** | 截图驱动的 UI 收敛 |
| **fix** | 点状缺陷修复 |
| **retro** | 工作流复盘 |

### 执行日志 (_logs/)

位于 `{project}/{version}/_logs/{date}-{type}-{scope}.md`。每次 AI 工作会话必须写一份。

### Chain

同一模块**多轮迭代的关联机制**。

| 字段 | 含义 |
|------|------|
| `chain_id` | 格式 `{feature}-{scope}`，如 `f01-list-ui` |
| `iteration` | 当前轮次（从 1 开始） |
| `prev` | 上一轮的日志文件名 |

用途：度量"这个模块经过了多少轮才收敛"。

### 门禁检查

门禁检查状态记录，UI 相关工作必填：

- Feature YAML：pass/fail
- ui_contract：pass/warning/fail/n-a
- pixel_baseline：pass/fail/n-a
- data_contract：pass/fail/n-a
- Figma 基线截图：pass/fail

### Outcome

日志收尾。每份日志结尾必填：

- 用户验收：pass/fail/pending
- 后续 chain：下一轮文件名 / closed
- 收敛轮次：仅在 closed 时填写

---

## 实现层 -- How + Why（定义怎么实现）

### implementation/

位于 `{project}/{version}/implementation/`。Feature YAML 定义 What；implementation 定义 **How**。

| 文件 | 含义 | 生成者 |
|------|------|--------|
| `overview.md` | 版本级设计概览 | 首个 Worker |
| `{platform}/tech-plan.md` | 平台级技术方案 | 首个 Worker |
| `F{nn}-{name}/design.md` | 共享设计（跨平台） | Worker Step 6 |
| `F{nn}-{name}/{platform}.md` | 平台特定设计 | Worker Step 6 |

---

## 外部资源

### figma-index.md

Figma 设计文件的**页面索引**。按 Section 分组，每个 Page 记录 node_id 和用途。

位于 `{project}/{version}/figma-index.md`，由 `/spec-init` 通过 Figma MCP 自动生成。

### i18n/strings.md

国际化字符串的**唯一权威来源**。按 Feature 分组，每行一个 key + 多语言翻译。

Feature YAML 和 Task 仅引用此文件，不内联 key。

### prd/README.md

PRD 的**结构化索引**。功能列表 + 埋点需求 + 关键依赖。

PRD 源优先从专用 PRD git 仓库读取 Markdown，PDF 作为兜底方案。
