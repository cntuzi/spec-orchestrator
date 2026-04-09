# Spec-Driven Development -- Beginner Tutorial

> Understanding how to involve AI in the full software development lifecycle, not just code writing.
> For: new team member onboarding / other projects adopting the system.

---

## Chapter 1: The Problem We Solve

### The State of AI Coding

AI tools can write code, but software development is more than writing code.

```
PM delivers PRD -> Developer asks AI to write code -> Does it run? -> Does UI match? -> Does the API work?
                                                        |
                                                   No idea, just hope for the best
```

| Problem | Consequence |
|---------|-------------|
| AI does not know the project's tech stack | Generated code is incompatible with existing architecture |
| AI does not know the design specs | UI output is completely off from Figma |
| AI does not know backend API definitions | Request params are guesses, field names don't match |
| Nobody tracks "what's done, what's left" | Progress tracking is purely verbal |
| Requirements change with no impact analysis | Changed A, but B and C also need changes -- forgotten |

### Core Idea: Add a Layer Between PRD and Code

**Structured "feature specifications" are the shared language between humans and AI.**

```
PRD (natural language for humans)
    | parse & extract
Feature Specs (structured, readable by both humans + AI)        <- this is the core
    | AI reads and executes
Code (for the compiler)
```

A feature spec merges scattered information **into a single file**:

| Traditional Approach | Feature Spec Approach |
|---------------------|----------------------|
| Requirements in PRD page N | Structured requirements list |
| Design in Figma link + verbal confirmation | Design constraints + Figma node references |
| Acceptance criteria scattered everywhere | Explicit pass/fail conditions |
| API in Swagger + chat messages | API endpoint references |
| Event tracking in spreadsheets | Structured analytics definitions |
| i18n in translation spreadsheets | Feature-grouped string tables |
| State scenarios from memory | Exhaustive state scenario matrix |

AI reads this file and gets complete context without repeated explanations.

---

## Chapter 2: System Overview

### Three Phases

```
Phase 1: Generate Specs
    From PRD + Figma + API docs -> auto-generate feature specs + task plans
    (30 minutes to complete what traditionally takes 10+ hours)

Phase 2: Orchestrate Execution
    Analyze task dependencies -> find parallelizable work -> dispatch AI -> monitor progress

Phase 3: Autonomous Development
    AI in isolated environment: read specs -> write code -> compile -> auto-merge -> update progress
```

### How a Version Runs

```
1. Product team delivers PRD + Figma + Swagger

2. Auto-generate spec skeleton
   -> 10 feature spec files, multi-platform task plans, backend deps, i18n strings, analytics defs

3. Create version branch

4. Analyze dependency graph, plan parallel batches
   -> Batch 1: 4 independent tasks start simultaneously
   -> Batch 2: 2 tasks depend on Batch 1 results
   -> Blocked: waiting for backend APIs, auto-unblocks when ready

5. Requirements change mid-development?
   -> Dependency index locates impact scope instantly -> auto-generate rework checklist

6. Real-time dashboard
   -> Who's done, who's blocked, what's the blocking reason
```

### Core Files at a Glance

```
{version}/                           All specs for one version
+-- config.yaml                      Version config (feature list, resource paths, dep index)
+-- features/                        Feature specs (one file per feature)
|   +-- F01-task-list.yaml             What to do + constraints
|   +-- F02-create-task.yaml
|   +-- ...
+-- tasks/                           Task plans
|   +-- ios.md                         iOS tasks + status
|   +-- android.md                     Android tasks + status
|   +-- backend.md                     Backend API dependencies
|   +-- shared.md                      Cross-platform prerequisites
+-- figma-index.md                   Figma design node index
+-- i18n/strings.md                  Internationalization strings
+-- CHANGELOG.md                     Change records
+-- DASHBOARD.md                     Progress dashboard (aggregated from task files)
+-- implementation/                  Implementation designs
|   +-- F01-task-list/
|       +-- design.md                  Shared design (cross-platform)
|       +-- ios.md                     Platform-specific design
+-- _logs/                           Execution logs
```

---

## Chapter 3: Core Concepts

### 3.1 Feature Spec File -- Complete Definition of a Feature

Two categories of fields: **What** + **Constraint**.

**What** -- can be auto-extracted from PRD:

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

**Constraint** -- requires manual or semi-automatic supplement:

```yaml
# Visual constraints -- what must be done, what is forbidden
ui_contract:
  required:
    - Custom list cell with checkbox, title, and due date
  forbidden:
    - System default UITableViewCell
  key_tokens:
    cell_height: 64
    checkbox_size: 24
    brand_color: "#4A90D9"

# Exhaustive state scenarios -- prevent missing edge cases
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

# Quantified dimensions -- reject "looks close enough"
pixel_baseline:
  cell_height: 64
  horizontal_inset: 16
  section_spacing: 8
```

**Why constraints?** Without them, AI only knows "build a task list" but not which components to use, what colors, what dimensions. The result: build it, find it wrong, rework repeatedly. With constraints: get it right the first time.

**Real data**: in production usage, the only feature with complete constraints had 0 rework cycles. The remaining features without constraints accumulated roughly 20 rework cycles.

### 3.2 Task Files -- Single Source of Truth for Progress

```
A task entry in tasks/ios.md:

| T01 | tasks | Task List | F01 | P0 | done | - |
```

Status flow:

```
pending -> active -> done
                       | requirements changed
                   rework -> active -> done
```

Key rule: **The task file is the single source of truth.** AI reads and writes status here. The progress dashboard is auto-aggregated from this. No manual dashboard maintenance needed.

### 3.3 Change Records -- What Happens When Requirements Change

Not a verbal heads-up, but:

```
1. Record the change (numbered CR-001, CR-002...)

2. Auto-analyze impact scope via dependency index:
   This API changed -> affects Feature F01 -> affects Task T01 (iOS) + T01 (Android)

3. Generate rework checklist, complete and mark each item

4. All complete -> change record marked as done
```

**Value**: no missed updates when requirements change. In production, 5 requirement changes were tracked with full coverage through change records.

### 3.4 Dependency Index -- Reverse Lookup Tables

Three reverse lookup tables maintained in version config:

| Lookup Direction | Purpose |
|-----------------|---------|
| API endpoint -> Feature list | When API changes, instantly locate affected features |
| Figma node -> Feature list | When design changes, instantly locate affected features |
| Feature -> Backend task list | When feature changes, find backend dependencies |

### 3.5 Execution Waves -- Not Sequential, but Dependency-Ordered

Analyze inter-task dependencies to find what can run concurrently:

```
Wave 1: T01, T06, T07, T11  (no dependencies, start simultaneously)
Wave 2: T02, T08             (depend on Wave 1 results)
Wave 3: T03                  (depends on Wave 2)
Blocked: T09                 (waiting for backend API, auto-unblocks when ready)
```

### 3.6 AI Autonomous Development Loop

AI independently completes a task's full lifecycle in an isolated git branch:

```
Read feature spec -> Collect context (design/API/i18n)
-> Lock task (pending->active) -> Design solution -> Write code -> Compile & verify
-> Code review -> Merge to version branch -> Update status (active->done)
-> Next task or exit
```

No manual triggering for each step. AI decides what to do, how to do it, and updates status when done. **The human's role is review and decision-making.**

### 3.7 Execution Logs -- Post-Hoc Traceability

Every AI work session writes a log. Common types:

| Type | When Generated |
|------|---------------|
| Feature development | Completing a task |
| Review fix | Human-initiated code/UI review |
| Screenshot-driven alignment | User sends screenshot, AI compares with Figma and fixes |
| Point fix | Discovering and fixing a bug |
| Doc sync | PRD / API doc updates |
| Change record | Recording a CR |
| Workflow retrospective | Aggregate analysis of multiple log rounds, find improvements |

Log value: answer "**why did this module take 3 rounds to converge**" -- was it missing specs? Skipped gate checks? Or ambiguous design?

---

## Chapter 4: A Walkthrough Example

> Walking through a hypothetical Todo App project. Read-only, no hands-on needed.

### The Version Config

`todo-app/config.yaml` -- 3 features, Figma file key, 1 Swagger file, dependency index. **The entire version's "table of contents."**

### A Feature Spec

`todo-app/features/F01-task-list.yaml` (approx. 100 lines):

- 3 requirements with structured IDs
- 4 acceptance criteria
- Visual constraints: specific colors, dimensions, component rules
- 3 state scenarios, each bound to a Figma node
- 2 API endpoints, i18n references

**All context the AI needs to develop this feature is in this single file.**

### The Task File

`todo-app/tasks/ios.md` -- 3 tasks, tracking status per task. Each completed task has completion time, merge commit, and implementation summary. **This is the iOS progress board.**

### The Change Log

`todo-app/CHANGELOG.md` -- initially empty. As changes occur, each gets a CR number, impact scope, and propagation checklist.

---

## Chapter 5: How to Use in Your Own Project

### Minimal Start (10 minutes)

No need to go all-in. Start with the highest-value parts.

#### Stage 1: Just Write Feature Spec Files

Create a directory, write one YAML per feature:

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

This single step gives AI tools complete context. **No installation required, no commands to learn.**

#### Stage 2: Add Task Files

Create a Markdown table to track progress:

```markdown
| ID | Task | Feature | Status | Deps |
|----|------|---------|--------|------|
| T01 | Login page UI | F01 | pending | - |
| T02 | Verification code flow | F01 | pending | T01 |
| T03 | Home list | F02 | pending | - |
```

Complete a task, change `pending` to `done`. Simple.

#### Stage 3: Add Constraints for Complex UI (optional)

Invest only in UI-heavy features; simple features don't need it:

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

### Full Integration

For complete automation capabilities (auto-generation, task scheduling, parallel development):

```
1. Set up directory structure following this repository's layout
2. Configure version info (Figma key, Swagger paths)
3. Use generation tools to auto-generate spec skeleton from PRD + Figma + API
4. Manual review + supplement complex feature visual constraints
5. Start task scheduling -> AI autonomous development
```

See the `.claude/commands/` directory in the repository for specific automation commands and orchestration protocols.

### Trimming Guide -- What Can Be Omitted

| Component | When It Can Be Omitted |
|-----------|----------------------|
| Visual constraints / pixel baseline | Non-UI features, prototype stage |
| Figma integration | Projects without Figma |
| Multi-platform parallel | Single-platform projects |
| Change record tracking | Small projects with stable requirements |
| Execution logs | When post-hoc analysis is not needed |
| Auto-aggregated dashboard | Fewer than 10 tasks |
| Git branch isolation | Solo development |

**The only two non-negotiable components: feature spec files + task files.** Everything else is additive.

---

## Chapter 6: FAQ

### Q: How is this different from Jira / Linear?

Jira manages "who does what." Feature specs manage "what to do + how to constrain it + how AI executes."

A Jira ticket has no Figma node binding, no exhaustive state scenarios, no visual guardrails. AI reading Jira only knows "build a login page," not which components, colors, or states to use.

**They complement each other; they don't conflict.**

### Q: Do I need to know YAML?

Not deeply. YAML is just indented key-value pairs. Look at one example and you can replicate it.

Most content can be auto-generated from PRD anyway; humans only need to confirm and supplement a few fields.

### Q: Is it tied to a specific programming language?

No. Feature specs describe "what to do," not "what language to use."

Swift, Kotlin, React, Flutter, Go -- all work. The only adaptation needed is tech stack constraint fields and build commands.

### Q: Is it worth it for a solo developer?

Use just feature specs + task files, 10-minute setup. The value is not "managing a team" but **giving AI structured context**. When developing solo, AI is your partner, and your partner needs to understand your requirements.

### Q: How does this relate to .cursorrules / copilot-instructions.md?

Those are "AI coding style configs" -- telling AI what syntax to use when writing code.

Feature specs are "AI work context" -- telling AI what feature to build, to what standard, with what constraints.

```
.cursorrules       -> "Use Swift 5, MVVM architecture, SnapKit layout"
Feature specs      -> "Build a login page, 3 states, these colors, no system Alert"
Task scheduling    -> "Do T01 first, then T02, T03 waits for backend API"
```

Different layers, used together.

### Q: Will overly detailed specs waste time?

Depends on feature complexity. We use `ui_weight` with three tiers:

| Tier | Scope | How Much Constraint |
|------|-------|-------------------|
| heavy UI | Modals, panels, new pages | Visual constraints + pixel baseline + state scenarios |
| light UI | List items, copy changes | State scenarios are enough |
| logic only | Analytics, API integration | No constraints needed |

**Invest constraints where rework frequency is high; skip them where rework is rare.** Not one-size-fits-all.

---

## Appendix: Further Reading

After understanding this tutorial, consult detailed documentation as needed:

| Want to Learn About | Read |
|--------------------|------|
| Precise definitions of all terms | `docs/glossary.md` |
| Architecture design and data flow | `docs/architecture.md` |
| Spec generation workflow | `docs/spec-generation.md` |
| Task execution protocol | `docs/exec-protocol.md` |
| Visual constraint rules | `workflows/ui-contract.md` |
| Generation protocol | `.claude/commands/spec-init.md` |
| Orchestration protocol | `.claude/commands/spec-drive.md` |
| AI autonomous execution loop | `.claude/commands/spec-next.md` |
| A complete example project | `examples/todo-app/` |
