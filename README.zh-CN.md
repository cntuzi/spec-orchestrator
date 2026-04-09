[English](README.md) | **中文**

# Spec Orchestrator

> AI 驱动的产品规格定义与跨平台开发编排。

将 PRD + Figma + API 文档转化为结构化的 Feature Spec，然后让 AI Agent 自主开发你的 iOS/Android/Web 应用 -- 内置依赖追踪、并行执行和变更管理。

## 问题

AI 工具能写代码，但软件开发不只是写代码：

| 问题 | 后果 |
|------|------|
| AI 不了解你的技术栈 | 生成的代码与现有架构不兼容 |
| AI 不了解设计稿 | UI 与 Figma 不一致 -- 反复返工 |
| AI 不了解 API 契约 | 请求参数靠猜，字段名对不上 |
| 没人跟踪哪些做完了、哪些还没做 | 进度全靠口头同步 |
| 需求在迭代中途变更 | 改了 A，但 B 和 C 也需要更新 -- 忘了 |

## 解决方案

在 PRD 和代码之间加一层结构化的 **Feature Spec** -- 人类和 AI 共用的语言。

```
PRD（人类可读的自然语言）
    ↓  /spec-init
Feature Specs（结构化，人类 + AI 均可读）    ← 这是核心
    ↓  /spec-drive → AI Workers
代码（给编译器的）
```

一个 Feature Spec 文件整合了：需求、Figma 引用、API 契约、状态场景、i18n 字符串、埋点事件和验收标准。AI 读取这个文件就能获得完整上下文 -- 无需反复解释。

## 架构

三层流水线：**生成 → 编排 → 执行**。

```
/spec-init          从 PRD + Figma + Swagger 生成 spec 骨架
    ↓
/spec-drive setup   创建版本分支 + worktree
/spec-drive next    分析依赖 → 分派并行 AI Workers
    ↓
Worker × N          自主开发循环：检查 → 收集 → 编码 → 构建 → 更新
    ↓
/spec-drive done    版本汇总 + 清理
```

### 命令

| 命令 | 用途 |
|------|------|
| `/spec-init` | 从 PRD + Figma + API 生成完整 spec |
| `/spec-drive setup` | 初始化版本分支 |
| `/spec-drive next` | 带依赖分析的智能任务分派 |
| `/spec-drive status` | 跨平台实时进度 |
| `/spec-drive change` | 需求变更追踪 + 影响分析 |
| `/spec-drive propagate` | 变更请求自动返工 |
| `/spec-drive verify` | 版本分支构建验证 |
| `/spec-next` | 查看任务状态，定位下一个可执行任务 |
| `/retro` | 汇总执行日志，提炼改进洞察 |

## 快速开始（5 分钟）

### 1. 克隆与初始化

```bash
git clone https://github.com/anthropics/spec-orchestrator.git  # 替换为你的仓库
cd spec-orchestrator
./scripts/init.sh my-app
```

生成以下结构：

```
my-app/1.0/
├── config.yaml
├── prd/README.md         ← 把你的 PRD 放这里
├── features/             ← 由 /spec-init 自动生成
├── tasks/
│   ├── shared.md
│   ├── backend.md
│   ├── ios.md
│   └── android.md
├── i18n/strings.md
├── figma-index.md
├── CHANGELOG.md
└── implementation/
```

### 2. 添加你的 PRD

将你的 PRD（Markdown 或 PDF）放到 `my-app/1.0/prd/` 目录下。

### 3. 生成 Spec

```
/spec-init 1.0
```

该命令会读取你的 PRD + Figma + Swagger 并生成：
- 每个功能的 Feature YAML（包含需求、API 引用、埋点、i18n）
- 各平台任务计划（iOS + Android）
- 后端 API 依赖追踪
- Figma 页面索引
- i18n 字符串表

### 4. 开始开发

```
/spec-drive setup    # 创建版本分支
/spec-drive next     # 分析 → 分派 → 并行开发
```

## 最小化接入（无需任何工具）

不需要完整的自动化也能受益。先从 Feature YAML 文件开始：

```yaml
id: F01
name: User Login
description: Phone number + verification code login

requirements:
  - id: R01
    desc: Enter phone number, tap send verification code
  - id: R02
    desc: Enter code, tap login

state_matrix:
  - id: S01
    name: Empty
    trigger: Open login page
    expected: Phone input focused, login button disabled
  - id: S02
    name: Phone entered
    trigger: Enter 11-digit phone number
    expected: Send code button enabled
```

仅凭这些，AI 工具就能获得该功能的完整上下文。无需安装，无需命令。

然后逐步添加：
- 任务追踪（Markdown 表格 + 状态 emoji）
- UI 约束（用于复杂 UI 功能）
- 完整自动化（spec-init → spec-drive → AI Workers）

## 目录结构

```
spec-orchestrator/
├── .claude/commands/           # 核心编排命令
│   ├── spec-init.md            # 从 PRD + Figma + API 生成 spec
│   ├── spec-drive.md           # 编排跨平台开发
│   ├── spec-next.md            # 任务状态与导航
│   └── retro.md                # 工作流复盘
├── templates/                  # spec 生成的文件模板
│   ├── feature.template.yaml   # Feature Spec 模板
│   ├── task-plan.template.md   # 平台任务计划格式
│   ├── config.template.yaml    # 平台项目配置
│   └── ...
├── workflows/                  # 执行协议
│   ├── spec-protocol.md        # 工作类型、阶段、质量门禁
│   └── execution-log.template.md
├── docs/                       # 文档
│   ├── tutorial.md             # 入门指南
│   ├── architecture.md         # 系统架构
│   ├── glossary.md             # 术语定义
│   └── ...
├── scripts/                    # 工具脚本
│   ├── init.sh                 # 项目初始化
│   └── lint-i18n-refs.sh       # i18n 校验
├── examples/                   # 示例项目
│   └── todo-app/               # 包含所有 spec 类型的完整示例
└── README.md
```

## Feature YAML -- 核心

每个功能对应一个 YAML 文件，包含两类字段：

**What（从 PRD 自动生成）：**
- `requirements` -- R01-Rnn 需求列表
- `acceptance_criteria` -- AC01-ACnn，含类型（ui/interaction/data）
- `figma.pages[]` -- 设计页面引用及 node ID
- `api[]` -- 后端接口定义，含参数/响应
- `analytics[]` -- 埋点事件定义
- `i18n_ref` -- 国际化字符串引用
- `state_matrix` -- 穷举式状态场景枚举

**Constraint（复杂 UI 由人工填写）：**
- `ui_contract` -- 必选/禁用组件，关键视觉 token
- `delivery_contract` -- 技术栈基线，数据字段优先级
- `pixel_baseline` -- 量化尺寸（杜绝"看起来差不多"）

功能按 `ui_weight` 分类：
- **heavy** -- 弹窗、面板、新页面 → 需要完整约束
- **light** -- 列表项、文本变更 → 只需 state_matrix
- **logic-only** -- 纯后端/埋点 → 不需要约束

## 变更管理

迭代中途需求变更时：

```
/spec-drive change api /api/endpoint "New field added"
```

自动执行：
1. 通过依赖索引追踪影响（API → Features → Tasks）
2. 创建 Change Record (CR) 及传播清单
3. 将受影响的已完成任务标记为需要返工

然后传播变更：
```
/spec-drive propagate CR-001
```

AI Worker 仅应用 CR 相关的变更，构建验证，并更新清单。

## 任务生命周期

```
🔴 Pending → 🟡 In Progress → 🟢 Completed
                                    ↓ CR 变更需求
                                🔵 Rework Needed → 🟡 → 🟢
```

任务文件（`tasks/ios.md`、`tasks/android.md`）是状态的**唯一事实来源**。DASHBOARD 由系统自动聚合，无需手动维护。

## 前置条件

- [Claude Code](https://claude.ai/code) 或任何支持自定义命令的 AI 编码工具
- Git（用于基于 worktree 的并行开发）
- tmux（可选，用于多平台并行编排）
- Figma MCP server（可选，用于设计稿集成）

## 文档

| 文档 | 用途 |
|------|------|
| [Tutorial](docs/tutorial.md) | 从这里开始 -- 从零了解整个系统 |
| [Glossary](docs/glossary.md) | 所有术语定义 |
| [Architecture](docs/architecture.md) | 三层架构设计 + 数据流 |
| [Spec Generation](docs/spec-generation.md) | 完整的生成协议 |
| [Execution Protocol](docs/exec-protocol.md) | Worker 7 步循环 |
| [Example: Todo App](examples/todo-app/) | 完整的可运行示例 |

## 常见问题

**Q: 这会把我绑定到 Claude Code 上吗？**
不会。Spec 文件（YAML + Markdown）与工具无关。任何 AI 工具都能读取。`/spec-*` 命令是 Claude Code 专用的，但数据格式在任何地方都通用。

**Q: 只能用于移动端吗？**
不是。系统支持任意平台组合 -- iOS、Android、Web、后端。在 `.claude/config.yaml` 中配置你的平台即可。

**Q: 必须用 Figma 吗？**
不是。Figma 集成是可选的。核心价值是结构化的 Feature Spec + 任务追踪。Figma 提供的是设计稿引用链接。

**Q: 这和 Jira/Linear 有什么区别？**
它们追踪的是"谁做什么"。这个系统追踪的是"要构建什么 + 如何约束 + AI 需要什么上下文"。两者互补。

## 贡献

欢迎贡献。重大变更请先开 issue 讨论。

## 许可证

[MIT](LICENSE)
