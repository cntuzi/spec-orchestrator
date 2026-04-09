[English](architecture.md) | **中文**

# Spec 系统架构

> 从 PRD 到代码的全自动化流水线：生成、编排、执行。

---

## 1. 概览

```
PRD + Figma + API Docs              <- 用户提供的素材
        |
   /spec-init                       <- 生成层：一次性生成规格骨架
        |
   {project}/{version}/             <- 规格层：Feature YAML + 任务计划 + i18n + ...
        |
   /spec-drive setup                <- 编排层：创建版本分支
   /spec-drive next                 <- 编排层：分析依赖 -> 分派 Worker
        |
   Worker x N (iOS + Android)       <- 执行层：自主 11 步开发循环
        |
   /spec-drive done                 <- 版本完成
```

---

## 2. 三层架构

### 2.1 生成层 -- `/spec-init`

**职责**：从 PRD + 素材一次性生成完整的规格骨架。

```
输入                                处理                              输出
-----------                         ----------------                  --------------
PRD (PDF/MD)           ->  Step 3: PRD 解析              ->  features/F{nn}-*.yaml
Figma (file_key)       ->  Step 4: Figma 索引            ->  figma-index.md
Swagger (JSON)         ->  Step 5: API 解析              ->  tasks/backend.md
i18n seeds             ->  Step 6: 完整生成              ->  config.yaml
                          Step 7: 交叉验证                   tasks/{ios,android}.md
                                                             i18n/strings.md
                                                             CHANGELOG.md
```

**三种模式**：

| 模式 | 命令 | 用途 |
|------|---------|---------|
| generate | `/spec-init 1.0` | 完整生成（版本目录不存在时） |
| refresh | `/spec-init 1.0 refresh` | 增量添加（PRD 变更后新增功能） |
| validate | `/spec-init 1.0 validate` | 仅验证，不修改文件 |

### 2.2 编排层 -- `/spec-drive`

**职责**：任务分析 + 依赖图 + worktree 创建 + Worker 分派 + 状态监控。

```
+------------------------------------------------------------------+
|                     specs repo（编排中枢）                          |
|                                                                  |
|  /spec-init:   PRD + 素材 -> 规格骨架（一次性）                     |
|  /spec-drive:  分析 + 分派 + 监控 + 变更管理                        |
|  /spec-next:   状态查看 + 任务定位                                  |
|                                                                  |
|  +--------------------------------------+                        |
|  |        编排器核心流程                   |                        |
|  |                                      |                        |
|  |  Phase 0: 前置检查 (tmux/branch)      |                        |
|  |  Phase 1: 全局分析 (DAG/wave)         |                        |
|  |  Phase 2: 展示计划 + 确认             |                        |
|  |  Phase 3: 基础设施 (worktree/tmux)    |                        |
|  |  Phase 4: 交还控制权                  |                        |
|  +--------------------------------------+                        |
+----------------+-------------------+---------+-------------------+
                 |                   |         |
      +----------v----------+  +----v---------v--------+
      |  {platform_repo}_ios |  |  {platform_repo}_android |
      |                     |  |                        |
      |  feat/v1.0 <- merge |  |  feat/v1.0 <- merge   |
      |    ^                |  |    ^                   |
      |  wt/T06-xxx <- dev  |  |  wt/T06-xxx <- dev    |
      +---------------------+  +------------------------+
```

**完整子命令集**：

| 子命令 | 频率 | 职责 |
|------------|-----------|----------------|
| `setup` | 每版本一次 | 检查规格完整性 -> 创建版本分支 |
| `next [platform]` | 多次 | 智能分析 -> worktree -> Worker 分派 |
| `T{nn} [platform]` | 按需 | 执行指定任务 |
| `status` | 随时 | 聚合跨平台进度 -> DASHBOARD |
| `reset T{nn}` | 故障恢复 | 将卡住的任务重置为 pending |
| `change <type> <scope> "<desc>"` | 按需 | CR 记录 + 影响分析 |
| `change status` | 随时 | CR 传播仪表盘 |
| `propagate CR-{nnn}` | 按需 | CR 代码返工 |
| `verify` | 版本末尾 | 版本分支编译检查 |
| `done` | 每版本一次 | 版本完成总结 |

### 2.3 执行层 -- `/spec-next` (Worker)

**职责**：在 worktree 中自主完成完整的开发生命周期。

```
+--------------------------------------------------------------+
|                    Worker 会话循环                              |
|                                                              |
|  LOOP:                                                       |
|    Step 1   Config     读取配置                                |
|    Step 2   Status     收集任务状态                             |
|    Step 3   Resolve    定位目标任务                             |
|    Step 4   Context    呈现上下文 (Figma/API/i18n)             |
|    Step 5   Lock       pending->active + git commit           |
|    Step 6   Analyze    design.md + {platform}.md              |
|    Step 7   Execute    API Verify -> Collect -> Code -> Build |
|    Step 8   Review     Code Review（最多 3 轮）                 |
|    Step 9   Merge      merge -> feat/v{version} + 清理        |
|    Step 10  Update     active->done + git commit              |
|    Step 11  Loop       下一个任务或 EXIT                        |
|                                                              |
|  退出条件：                                                    |
|    - 所有任务完成                                               |
|    - 所有任务被阻塞                                             |
|    - 连续 2 次失败                                              |
+--------------------------------------------------------------+
```

---

## 3. 规格层 -- 目录结构

```
{project}/{version}/
|
+-- config.yaml ---------------------- 版本配置
|   +-- version, codename
|   +-- figma.file_key
|   +-- paths（所有文件位置）
|   +-- api.swagger_files
|   +-- features[]（快速索引）
|   +-- dependency_index
|       +-- api_to_features         /api/tasks -> [F01]
|       +-- figma_to_features       "119:370" -> [F02]
|       +-- feature_to_backend      F02 -> [B01]
|
+-- prd/
|   +-- README.md --------------------- 结构化 PRD 索引
|   +-- *.pdf ------------------------- PRD 原始文档
|
+-- features/
|   +-- F01-xxx.yaml ------------------ What + Constraint
|   +-- F02-xxx.yaml                      id, name, module, epic
|   +-- ...                               description, requirements
|   +-- F{nn}-xxx.yaml                    acceptance_criteria
|                                         ui_contract <- Figma 驱动
|                                         delivery_contract <- 技术栈约束
|                                         state_matrix <- 状态场景
|                                         figma.pages[] <- 设计资源
|                                         api[] <- 接口定义
|                                         analytics[] <- 埋点追踪
|                                         i18n_keys[] <- 国际化
|                                         platform_tasks <- T/B 映射
|                                         dependencies <- 功能间依赖
|
+-- tasks/
|   +-- shared.md --------------------- S1-S3 前置条件 + API 模式 + 错误码
|   +-- backend.md -------------------- B01-B{nn} 后端 API 详情
|   +-- ios.md ------------------------ T01-T{nn} 单一事实源（iOS）
|   +-- android.md -------------------- T01-T{nn} 单一事实源（Android）
|
+-- i18n/
|   +-- strings.md -------------------- key | zh | ja | en
|
+-- figma-index.md -------------------- Section -> Page -> Node ID
|
+-- CHANGELOG.md ---------------------- CR 变更日志 + 检查清单
|
+-- DASHBOARD.md ---------------------- 进度仪表盘（聚合）
|
+-- implementation/ ------------------- How + Why
    +-- overview.md                       版本级设计概览
    +-- ios/tech-plan.md                  iOS 平台技术方案
    +-- android/tech-plan.md              Android 平台技术方案
    +-- F{nn}-{name}/
        +-- design.md                     共享设计（跨平台）
        +-- ios.md                        iOS 平台细节
        +-- android.md                    Android 平台细节
```

---

## 4. 数据流

### 4.1 生成时数据流 (spec-init)

```
PRD --+-- Epic/Feature 提取 ----------> features/F{nn}.yaml
      +-- 埋点提取 --------------------> features/F{nn}.yaml -> analytics[]
      +-- 依赖提取 --------------------> tasks/backend.md (B{nn})
      +-- 文案提取 --------------------> i18n/strings.md

Figma --- Section/Page 查询 ----------> figma-index.md
      +-- Page->Feature 映射 ----------> features/F{nn}.yaml -> figma.pages[]

Swagger -- 接口提取 ------------------> features/F{nn}.yaml -> api[]
       +-- 参数/响应提取 ---------------> tasks/backend.md（详情）

以上全部 --- 反向索引 -----------------> config.yaml -> dependency_index
          +-- 任务分发 ----------------> tasks/{ios,android}.md
```

### 4.2 执行时数据流 (spec-drive + spec-next)

```
config.yaml ----------------------> spec-drive: 版本配置
tasks/{platform}.md --------------> spec-drive: 依赖图 + wave 规划
                                 -> spec-next:  任务定位 + 状态读写

features/F{nn}.yaml -------------> Worker Step 4: 上下文收集
                                 -> Worker Step 6: 设计输入
                                 -> Worker Step 7: API Verify 基线

figma-index.md ------------------> Worker Step 7: Figma 截图下载
i18n/strings.md -----------------> Worker Step 7: i18n 文件写入
tasks/backend.md ----------------> Worker Step 7: API Contract Verify

implementation/*.md -------------> Worker Step 6: 读取/生成设计
                                 -> Worker Step 7: 按设计实现
```

### 4.3 变更时数据流 (spec-drive change + propagate)

```
发生变更
  |
  v
/spec-drive change api /path "desc"
  |
  +-- config.yaml dependency_index --> 影响范围（Features -> Tasks）
  +-- CHANGELOG.md --> 新建 CR-{nnn} + 检查清单
  +-- features/F{nn}.yaml --> revisions[] 记录
  |
  v
手动更新规格文件（YAML + Task）
  |
  v
/spec-drive propagate CR-{nnn}
  |
  +-- 创建 worktree (CR{nnn}-T{nn}-xxx)
  +-- Worker: 仅应用 CR 变更 -> build -> review
  +-- merge -> feat/v{version}
  +-- CHANGELOG 检查清单 [x] -> 全部完成 -> complete
```

---

## 5. Feature YAML 与 implementation/ 的分工

```
Feature YAML = What + Constraint         implementation/ = How + Why
（做什么、UI 契约、数据契约、              （怎么做、为什么、模块
 状态矩阵）                               交互）

+-------------------------+              +--------------------------+
| F01-task-list.yaml      |              | F01-task-list/           |
|                         |              |                          |
| description: Task list  |  --gen-->    | design.md                |
| requirements: R01-R04   |              |   影响分析、数据流、       |
| acceptance_criteria     |              |   API 策略、关键决策       |
| ui_contract             |              |                          |
| delivery_contract       |  --refine--> |                          |
| state_matrix            |              | ios.md                   |
| api[]                   |              |   现有代码分析             |
| i18n_keys[]             |              |   文件变更清单             |
| analytics[]             |              |   平台技术选型             |
+-------------------------+              |                          |
                                         | android.md               |
 spec-init 生成                          |   （同上，Android 视角）    |
 + 手动补充                               +--------------------------+
                                          Worker Step 6 生成
```

**生成时机**：

| 文档 | 生成时间 | 生成者 |
|----------|---------------|--------------|
| Feature YAML | `/spec-init` | spec-init + 手动补充 |
| overview.md | 版本首次执行时 | 首个 Worker |
| {platform}/tech-plan.md | 版本首次执行时 | 首个 Worker |
| F{nn}/design.md | Feature 的首个任务 | Worker（跨平台共享） |
| F{nn}/{platform}.md | 每个 Worker | Worker（平台特定） |

---

## 6. 状态生命周期

```
pending（未开始）
    |
    |  Worker Step 5: Lock
    v
active（进行中）
    |
    +-- build + review 通过 ---------> done（完成）
    |                                |
    |                                +-- CR 变更 -> rework_needed
    |                                                  |
    |                                                  | propagate
    |                                                  v
    |                                                active -> done
    |
    +-- 失败/阻塞
         |
         +-- blocked（worktree 保留）
              |
              +-- /spec-drive reset -> pending -> 重新执行
```

| 符号 | 含义 | 位置 |
|--------|---------|----------|
| pending | 未开始 | tasks/{platform}.md |
| active | 进行中 | tasks/{platform}.md（Lock 之后） |
| rework | 需返工 | tasks/{platform}.md（CR 变更后） |
| done | 已完成 | tasks/{platform}.md（验证通过后） |
| n/a | 不适用 | DASHBOARD.md（无后端依赖时） |

**单一事实源**：`tasks/{platform}.md` -- Worker 在此读写，DASHBOARD 由 `status` 命令聚合生成。

---

## 7. 分支与 Worktree 策略

```
master (or main)
  |
  +-- feat/v1.0  <- 版本集成分支（所有任务的合并目标）
       |
       +-- feat/{platform_repo}_ios/0306/T01-task-list          <- 任务分支
       +-- feat/{platform_repo}_ios/0306/T02-create-task
       +-- feat/{platform_repo}_android/0306/T01-task-list
       +-- feat/{platform_repo}_android/0306/T02-create-task
```

**Worktree 生命周期**：

```
创建 -> wt.sh new T01-xxx feat/v1.0
       -> wt/{project}/{MMDD}/T01-xxx/ + tmux window + symlinks

使用 -> Worker 在 worktree 中开发（Step 6-8）

合并 -> git merge --no-ff -> feat/v{version}

清理 -> wt.sh -f rm T01-xxx -> 删除 worktree + branch + tmux window
```

---

## 8. 智能分析 -- 执行波次

根据 tasks/{platform}.md 中的依赖列构建依赖图，规划并行执行批次：

```
示例：

T01 -+-> T02 --> (wait B01)
     +-> T03 --> (wait B02)
     +-> T04
     +-> T05

T06 (independent) --> (wait B03)
T07 (independent)

T08 -> T09 --> (wait B04)
        +-> T10

T11 (independent)

Wave 1: T01, T06, T07, T08, T11        <- 无依赖，可并行执行
Wave 2: T04, T05, T09                   <- 依赖 Wave 1
Wave 3: T10                             <- 依赖 T09
Blocked: T02, T03                       <- 等待后端 B01-B02
```

---

## 9. 变更管理

```
CHANGELOG.md              dependency_index            Feature YAML
（变更记录）                （影响分析）                  （变更追踪）
     |                        |                           |
     |  /spec-drive change    |                           |
     |  ----------------->    |                           |
     |  自动生成 CR-{nnn}      |  api_to_features         | revisions[]
     |  + 检查清单             |  figma_to_features       | [CR-{nnn}] 标注
     |                        |  feature_to_backend      |
     v                        v                           v
  CR-003                   F01 -> T01 iOS              F01.yaml
  待传播                    F01 -> T01 Android          + [CR-003] 行
  检查清单: 6 项            F01 -> B01                  + revisions 记录
     |
     |  /spec-drive propagate CR-003
     |  --------------------------->
     |
     v
  Worker: worktree -> 仅应用变更 -> build -> review -> merge
  CHANGELOG: [ ] -> [x]
  全部 [x] -> CR-003 完成
```

---

## 10. 权威文件索引

| 文件 | 角色 | 写入者 | 读取者 |
|------|------|------------|---------|
| `.claude/commands/spec-init.md` | 生成协议 | - | spec-init |
| `.claude/commands/spec-drive.md` | 编排协议 | - | spec-drive |
| `{platform}/.claude/commands/spec-next.md` | 执行协议 | - | Worker |
| `{project}/{version}/config.yaml` | 版本配置 | spec-init | 全部 |
| `{project}/{version}/features/*.yaml` | 需求规格 | spec-init + 手动 | Worker |
| `{project}/{version}/tasks/{platform}.md` | **单一事实源** | Worker + spec-drive | 全部 |
| `{project}/{version}/tasks/backend.md` | 后端 API | spec-init + 手动 | Worker |
| `{project}/{version}/implementation/*.md` | 实现设计 | Worker | Worker |
| `{project}/{version}/CHANGELOG.md` | 变更追踪 | spec-drive change | propagate |
| `{project}/{version}/DASHBOARD.md` | 进度仪表盘 | spec-drive status | 人工查看 |
| `{project}/{version}/figma-index.md` | Figma 索引 | spec-init | Worker |
| `{project}/{version}/i18n/strings.md` | 国际化 | spec-init | Worker |
| `_scripts/SPEC-DRIVE-GUIDE.md` | 运维指南 | - | 人工参考 |
| `_scripts/SPEC-ARCHITECTURE.md` | 架构文档 | - | 人工参考 |
| `_templates/*.yaml\|md` | 文件模板 | - | spec-init |

---

## 11. 典型工作流

### 新版本完整开发

```bash
# 1. 准备素材
#    将 PRD 放入 {project}/1.0/prd/

# 2. 生成规格
/spec-init 1.0                    # PRD + Figma + API -> 完整规格

# 3. 补充手动字段（可选，不阻塞执行）
#    ui_contract, delivery_contract, state_matrix.figma_node

# 4. 初始化
/spec-drive setup                 # 检查规格完整性 -> 创建版本分支

# 5. 执行
/spec-drive next                  # 自动分析 -> 多平台并行启动
#    iOS:     T01 -> T04 -> T05 -> ... -> 暂停（等待后端）
#    Android: T01 -> T04 -> T05 -> ... -> 暂停（等待后端）

# 6. 监控
/spec-drive status                # 实时跨平台进度

# 7. 处理变更
/spec-drive change api /path "added new field"
/spec-drive propagate CR-001      # 自动返工

# 8. 完成
/spec-drive verify                # 编译检查
/spec-drive done                  # 版本总结
```

### PRD 变更后增量更新

```bash
/spec-init 1.0 refresh            # 新增功能，不覆盖已有内容
/spec-drive next                  # 自动检测新任务
```

### 仅验证

```bash
/spec-init 1.0 validate           # 输出 pass/fail/warning 报告
```
