---
description: View all platform task status, locate next available task
---

# /spec-next — Spec Task Status & Navigation

User request: $ARGUMENTS

## Description

The specs repo is a specification-only repo — no platform code. It only supports **status viewing** and **task navigation**, not development execution.

**For development execution, use `/spec-drive`**:
- `/spec-drive setup` — Initialize version branches
- `/spec-drive next` — Auto-analyze + create worktree + launch dual-platform dev
- `/spec-drive T06` — Execute specific task
- `/spec-drive verify` — Version branch build verification

## Execution Flow

### Step 1: Determine Version

Read `{project}/` directory for latest version number (sort by dir name, take max).

### Step 2: Collect Cross-Platform Status

Read in parallel:

1. **iOS Tasks**: `{project}/{version}/tasks/ios.md` → parse task overview table
2. **Android Tasks**: `{project}/{version}/tasks/android.md` → parse task overview table
3. **Backend API**: `{project}/{version}/tasks/backend.md` → parse API readiness timeline
4. **Shared Dependencies**: `{project}/{version}/tasks/shared.md` → parse shared prerequisite status
5. **Active Worktrees**:
   - iOS: `cd {platforms.ios.repo} && git worktree list --porcelain` → extract `[TF]\d{2}` from branch names
   - Android: `cd {platforms.android.repo} && git worktree list --porcelain` → extract `[TF]\d{2}` from branch names
6. **CR Changes**: `{project}/{version}/CHANGELOG.md` → parse all CRs with 🟡/🔴 status
   - Extract affected task list (from **Impact** field, parse T{nn})
   - Extract incomplete checklist items ([ ] lines)

### Step 3: Execute Based on Arguments

#### Empty or `status` → Output full cross-platform status overview

```
## v{version} Task Status Overview

### Shared Dependencies
| ID | Item | Status |
|----|------|--------|
| S1 | PRD Confirmed | 🟢 |
...

### Backend API Readiness
| ID | API | Blocking Feature | Status |
|----|-----|-----------------|--------|
| B01 | Endpoint | F02 | 🟡 |
...

### iOS Tasks
| ID | Task | Status | Dependencies | Backend | Worktree | Available |
|----|------|--------|-------------|---------|----------|-----------|
| T01 | Feature Name | 🔴 | - | ✅ | - | ✅ |
...

Next available: T01

### Android Tasks
| ID | Task | Status | Dependencies | Backend | Worktree | Available |
|----|------|--------|-------------|---------|----------|-----------|
...

Next available: T01

### CR Change Alerts

> Only output when 🟡/🔴 CRs exist that affect completed (🟢) tasks.

| CR | Description | Affected Tasks | Pending | Status |
|----|------------|----------------|---------|--------|
| CR-003 | Field rule change | T06 | Backend confirm | 🟡 |

⚠️ Above CRs affect completed tasks with un-propagated code changes.
`/spec-drive next` auto-includes CR rework tasks, or use `/spec-drive propagate CR-{nnn}` manually.

### Progress
- iOS: 🟢 0/10 | 🟡 0/10 | 🔴 10/10
- Android: 🟢 0/10 | 🟡 0/10 | 🔴 10/10
- Backend API: 🟢 2/7 | 🟡 5/7
```

#### Task ID argument (e.g. `T06`, `F02`) → Output task detail

Read task detail section from platform task file, output:
- Task ID + name + requirement description
- Dependency status (prerequisite tasks + backend API)
- Figma page list
- API endpoint list
- i18n string key list
- Acceptance criteria
- Cross-platform status comparison (iOS vs Android)

If task is affected by un-propagated CR (CHANGELOG has 🟡/🔴 CR with this task in **Impact**), append:

```
#### ⚠️ Pending CR Changes
- **CR-003**: Description of changes
  Pending: Backend confirm + Figma confirm
```

#### Platform argument (e.g. `ios`, `android`) → Output only that platform's status

### Task Availability Check

A task is "available" when ALL conditions are met:
1. ✅ Status is 🔴 (pending) or 🔵 (rework needed)
2. ✅ All prerequisite tasks are 🟢 or 🔵 (completed/rework)
3. ✅ No active worktree (branch name doesn't contain this task ID)
4. ✅ Backend API ready (corresponding B{nn} is 🟢, or no backend dependency)

**Status definitions**:
- 🔴 Pending — never started
- 🟡 In Progress — actively being developed
- 🔵 Rework Needed — completed but CR changed requirements, code needs targeted update
- 🟢 Completed — development done, no action needed

**Backend API dependency mapping** (derived from backend.md "Blocking Feature" column):
- Task's Feature → corresponding B{nn} → check status
- Pure client-side tasks (no API calls) → no backend dependency, directly available

Sort by task overview table order (T01→T{nn}), recommend first available task.

### CR Attention Logic

```
For each 🟡/🔴 CR in CHANGELOG:
  1. Parse **Impact** field → extract T{nn} list
  2. Parse **Actions** field → extract [ ] (incomplete) items
  3. Cross-reference with current task status:
     Completed (🟢) + has incomplete checklist = needs attention
  4. Status overview: aggregate all CRs needing attention → CR alerts table
  5. Task detail: if task is in attention list → append ⚠️ Pending CR Changes
```
