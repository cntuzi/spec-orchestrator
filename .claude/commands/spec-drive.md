---
description: Central orchestration of multi-platform development from the specs repo -- task analysis + worktree creation + parallel execution
---

# /spec-drive -- Central Multi-Platform Development Orchestration

User request: $ARGUMENTS

## Role

The specs repo is the orchestration center (brain); platform repos are execution targets (hands).
This command handles: task analysis + infrastructure setup (worktree + tmux) + status monitoring.
Actual development is performed autonomously by independent Claude Code sessions in each tmux window.

---

## Step 1: Read Configuration + Resolve Context

```
1. Read .claude/config.yaml:
   - project.name -> project name (e.g. "myapp")
   - version.current -> current version (e.g. "1.2")
   - repos.{ios,android,api-doc}.hint -> repo hint paths
   - platforms.{ios,android}.repo_id -> logical repo identifiers
   - platforms.{ios,android}.build_cmd -> build commands
   - wt_script -> worktree management script path
   - branch.pattern -> branch naming pattern (e.g. "feat/{project}/{version}")

2. Resolve external context:
   a. Check .context-resolved.yaml exists and is fresh (< 1 hour old)
   b. If missing or stale -> run: bash scripts/resolve-context.sh {version}
   c. Read .context-resolved.yaml:
      - repos.ios -> absolute path to iOS repo (works in worktree)
      - repos.android -> absolute path to Android repo
      - repos.api-doc -> absolute path to API docs
      - drift.* -> pin drift status per repo
   d. If any required repo missing -> ERROR with resolution instructions
   e. If drift detected + drift_policy=block -> ERROR "Re-pin with /spec-init refresh"
   f. If drift detected + drift_policy=warn -> WARNING, continue

3. Read {project}/{version}/config.yaml -> version-specific configuration
4. Read {project}/{version}/context.yaml -> context manifest (pins, artifacts)
5. Derive variables:
   - VERSION_BRANCH = branch.pattern with {project} and {version} interpolated
     (e.g. "feat/myapp/1.2")
   - IOS_REPO = .context-resolved.yaml repos.ios (absolute path)
   - ANDROID_REPO = .context-resolved.yaml repos.android (absolute path)

Note: All subsequent steps use IOS_REPO / ANDROID_REPO from resolved context,
NOT relative paths from config. This ensures worktree compatibility.
```

---

## Step 2: Parse Arguments

```
$ARGUMENTS parsing:

  "setup"              -> jump to [Setup Sub-command]
  "status"             -> jump to [Status Sub-command]
  "reset T{nn}"        -> jump to [Reset Sub-command]
  "verify"             -> jump to [Verify Sub-command]
  "done"               -> jump to [Done Sub-command]
  "change ..."         -> jump to [Change Sub-command]
  "change status"      -> jump to [Change Status Sub-command]
  "propagate CR-{nnn}"         -> jump to [Propagate Sub-command]
  "propagate CR-{nnn} ios"     -> jump to [Propagate Sub-command], platform=ios
  "propagate CR-{nnn} android" -> jump to [Propagate Sub-command], platform=android
  "next"               -> target_task=auto, target_platforms=auto
  "next ios"           -> target_task=auto, target_platforms=[ios]
  "next android"       -> target_task=auto, target_platforms=[android]
  "T{nn}"              -> target_task=T{nn}, target_platforms=auto
  "T{nn} ios"          -> target_task=T{nn}, target_platforms=[ios]
  "F{nn}"              -> map Feature to T{nn}, target_platforms=auto
  empty                -> equivalent to "next"

When target_platforms=auto:
  - Check task status on both platforms
  - Only execute on platforms with status "pending" (red)
  - Skip platforms with status "done" (green) or "in-progress" (yellow)
  - Both platforms pending -> execute on both
```

---

## Setup Sub-command

```
/spec-drive setup

0. Check spec completeness:
   a. {project}/{version}/ directory exists?
   b. {project}/{version}/config.yaml exists?
   c. {project}/{version}/context.yaml exists? (warn if missing, not blocking)
   d. {project}/{version}/features/ has at least 1 .yaml file?
   e. {project}/{version}/tasks/ios.md exists?
   f. {project}/{version}/tasks/android.md exists?
   If not satisfied -> "Please run /spec-init {version} first to generate the spec skeleton"

Prerequisite: Context resolved (Step 1 completed, IOS_REPO / ANDROID_REPO available)

1. For each platform (ios, android):
   a. repo = IOS_REPO or ANDROID_REPO (from .context-resolved.yaml, absolute path)
   b. Check {repo} directory exists (should always pass if resolve succeeded)
   c. Check if VERSION_BRANCH already exists:
      git -C {repo} branch --list {VERSION_BRANCH}
   d. If it does not exist:
      git -C {repo} fetch origin
      git -C {repo} checkout master  (or main)
      git -C {repo} pull
      git -C {repo} checkout -b {VERSION_BRANCH}
   e. If it already exists:
      Output "OK {platform}: {VERSION_BRANCH} already exists"

2. Create version worktree (one per platform):
   For each platform:
   a. Check if worktree already exists:
      git -C {repo} worktree list | grep {version}
   b. If it does not exist:
      cd {repo} && bash {wt_script} new {version} {VERSION_BRANCH}
      -> Path: wt/{repo_basename}/{version}/
      -> Branch: {VERSION_BRANCH}
      -> Automatically creates tmux window
   c. If it already exists:
      Output "OK {platform}: worktree {version} already exists"

3. Resolve context in worktrees:
   For each platform worktree:
   a. Copy resolve-context.sh to worktree (or ensure it's accessible)
   b. Run resolve-context.sh inside worktree:
      cd {wt_path} && bash {specs_repo}/scripts/resolve-context.sh {version}
   c. This generates {wt_path}/.context-resolved.yaml with:
      - repos.specs -> absolute path to specs repo (auto-discovered via git worktree)
      - repos.api-doc -> absolute path to API docs
      - drift status for all pinned repos
   d. Workers will read this file instead of relying on symlinks

4. Validate:
   - Confirm version worktree is accessible
   - Confirm .context-resolved.yaml exists in worktree
   - Confirm resolved specs path is accessible
   - (Legacy compatibility) If specs symlink exists, verify it points correctly

5. Output:
   OK iOS: {wt_path_ios} (branch: {VERSION_BRANCH})
   OK Android: {wt_path_android} (branch: {VERSION_BRANCH})
   Context: .context-resolved.yaml generated in both worktrees
   -> Main repo stays on master; all development happens in worktrees
   -> Ready to execute: /spec-drive next
```

---

## Reset Sub-command

```
/spec-drive reset T{nn} [platform]

Used to recover tasks stuck in "in-progress" state (worker crash, worktree cleaned, etc.).

1. Check current task status:
   - If "done" (green) -> prompt that it is already complete, confirm whether to force reset
   - If "pending" (red) -> prompt that it is already pending, no reset needed
   - If "in-progress" (yellow) -> continue

2. Check for active worktree:
   git -C {repo} worktree list --porcelain | grep T{nn}
   - If found -> prompt "Found active worktree: {path}"
     - Suggest: enter worktree to continue, or clean with wt.sh -f rm first then reset
     - Require user confirmation to continue

3. Execute reset on target platform:
   - Edit {project}/{version}/tasks/{platform}.md:
     - Overview table: in-progress -> pending + update stats row
     - Details: status line in-progress -> pending (remove blocking reason)
   - git add + commit: "chore: reset T{nn} to pending ({platform})"

4. Output:
   OK T{nn} ({platform}) has been reset to pending
   -> Use /spec-drive T{nn} to re-execute
```

---

## Status Sub-command

```
/spec-drive status

1. Read task status from both platforms + backend API + worktree:
   - {project}/{version}/tasks/ios.md -> each task's status
   - {project}/{version}/tasks/android.md -> each task's status
   - {project}/{version}/tasks/backend.md -> backend API status

2. Real-time aggregated DASHBOARD (does not rely on DASHBOARD.md file):
   - Parse each T{nn} status from ios.md + android.md overview tables
   - Derive feature completion via T{nn} -> F{nn} mapping:
     - F{nn} is "done" on a platform = all related T{nn} on that platform are "done"
     - Backend column: corresponding B{nn} status (no backend API -> N/A)
   - If aggregated result differs from DASHBOARD.md -> auto-update DASHBOARD.md + git commit

3. Additional output:
   - Version branch status:
     - iOS {VERSION_BRANCH}: exists yes/no, ahead of master by N commits
     - Android {VERSION_BRANCH}: exists yes/no, ahead of master by N commits
   - Active worktree list (associated with task IDs)
```

---

## Execution Flow (next / T{nn})

### Phase 0: Pre-flight Checks

```
1. Environment check:
   - Check if $TMUX environment variable exists
   - If not in tmux -> ERROR: "spec-drive requires a tmux session; workers depend on tmux windows"
   - Exit

2. Version branch check:
   For each target_platform:
   - git -C {repo} branch --list {VERSION_BRANCH}
   - If branch does not exist -> ERROR: "Version branch {VERSION_BRANCH} not found, run /spec-drive setup first"
   - Exit

3. Repo state check:
   For each target_platform:
   - git -C {repo} status --porcelain
   - If there are uncommitted changes -> WARNING: "{platform} repo has uncommitted changes"
   - List changed files, confirm whether to continue
```

### Phase 1: Global Execution Plan Analysis

```
1. Parallel reads:
   - {project}/{version}/tasks/ios.md -> iOS task status + dependencies
   - {project}/{version}/tasks/android.md -> Android task status + dependencies
   - {project}/{version}/tasks/backend.md -> backend API status
   - {project}/{version}/tasks/shared.md -> shared dependency status
   - {project}/{version}/CHANGELOG.md -> in-progress/pending CR unpropagated code changes

2. Check active worktrees:
   git -C {ios_repo} worktree list --porcelain -> extract [TF]\d{2}
   git -C {android_repo} worktree list --porcelain -> extract [TF]\d{2}

3. Build dependency graph + execution plan:

   a. Classify all tasks:
      - Done (green): skip
      - In-progress (yellow): mark, do not re-dispatch
      - Ready to execute: pending + all dependencies met + no worktree + backend ready
      - Waiting on dependency: pending but prerequisites not done
      - Waiting on backend: pending + prerequisites met but B{nn} not ready
      - Blocked: in-progress + explicit blocking reason
      - CR rework (blue): needs rework + no worktree

   b. Plan execution waves:
      Wave 1: all immediately executable tasks with no mutual dependencies (parallelizable)
      Wave 2: tasks unlocked after Wave 1 completes
      Wave 3: ...
      Blocked: tasks waiting for backend APIs
      CR rework: blue-status tasks (parallel with Wave 1, lower priority than new tasks)

   c. Cross-platform alignment:
      - Same task (e.g. T06) needed on both platforms -> same Wave, parallel execution
      - One platform already done -> execute only on the other

4. If target_task=T{nn}:
   Locate that task in the execution plan, check executability on target_platforms

5. Check technical designs (prerequisite):
   design_dir = {project}/{version}/designs/
   For each task's Feature in exec_list:
     a. designs/F{nn}-{name}.md exists?
        - Yes → ok, Worker will follow this design
        - No → WARNING "No technical design for F{nn}. Run /spec-init {version} design first."
                Non-blocking but strongly recommended.
                Without design: Worker makes its own decisions (higher risk of cross-platform misalignment)
     b. If design exists, check Section 2 (API 契约):
        - All endpoints have request/response defined → ok
        - Any TBD → warn "API contract incomplete for F{nn}"

6. Determine this execution's task list:
   - "next": take Wave 1's first batch + CR rework tasks
   - "T{nn}": take the specified task
   exec_list = [(task, platform, mode), ...]
   mode = "new" (normal pending->done) | "cr_propagate" (CR rework, uses Propagate flow)
```

### Phase 2: Display Execution Plan + Confirm

```
Output:
## v{version} Execution Plan

### Dependency Graph
T01 --+-> T02 --> (waiting B01)
      +-> T03 --> (waiting B02)
      +-> T04 --> (waiting B03)
      +-> T05
T06 (independent)
T07 (independent)
T08 -> T09 -> T10

### Execution Waves
| Wave | Task | iOS | Android | Blocked |
|------|------|-----|---------|---------|
| 1 | T06 Self-Setting | Ready | Ready | - |
| 1 | T07 Role-Setting | Ready | Ready | - |
| 2 | T08 Edit Entry | Ready | Ready | - |
| 2 | T02 AI Rewrite | Wait | Wait | B01 in-progress |
| 3 | T09 Edit Page | Wait | Wait | T08 |
| 3 | T03 Restart | Wait | Wait | B02 in-progress |
| 4 | T10 Review | Wait | Wait | T09 |
| 4 | T04 Rollback | Wait | Wait | B03 in-progress |

### CR Rework (auto-propagate)
| Platform | Task | CR | Action |
|----------|------|----|--------|
| iOS  | T06 Self-Setting | CR-003 | Apply CR changes in version worktree |
| Android | T06 Self-Setting | CR-003 | Apply CR changes in version worktree |

> Only output this section when CR rework tasks exist.

### This Launch
| Platform | Task | Backend API | Action |
|----------|------|-------------|--------|
| iOS  | T06 Self-Setting | B04 done | Use version worktree |
| Android | T06 Self-Setting | B04 done | Use version worktree |

### Implementation Documents
| Document | Status |
|----------|--------|
| overview.md | Exists / Will be generated by first worker |
| ios/tech-plan.md | Exists / Will be generated by first worker |
| android/tech-plan.md | Exists / Will be generated by first worker |
| F06/design.md | Exists / Will be generated by worker |

> Only output documents relevant to this execution's Features.

Worker session will auto-loop:
T06 done -> T07 -> T08 -> ... until all done or blocked

Confirm launch?
```

### Phase 3: Infrastructure Setup

Version worktree was created during the setup phase; reuse it here.

```
1. Confirm version worktree exists:
   For each target_platform:
   a. wt_path = wt/{platforms.<platform>.repo}/{version}/
   b. Check: git -C {repo} worktree list | grep {version}
   c. If does not exist -> create: cd {repo} && bash {wt_script} new {version} {VERSION_BRANCH}
   d. If exists but no tmux window -> recreate tmux window

2. Lock tasks (in specs):
   For each (task, platform) in exec_list:
   Edit {project}/{version}/tasks/{platform}.md:
   - Overview table: T{nn} pending -> in-progress + stats row
   - Details: status line pending -> in-progress
   git add + commit: "chore: mark T{nn} as in-progress ({platform})"

3. Create execution log:
   For each (task, platform) in exec_list:
   log_file = {project}/{version}/_logs/{date}-task-T{nn}-{platform}.md
   Write frontmatter (date/type=task/scope=T{nn}-{platform}/executor=TBD) +
   Parse phase record (input=user instruction, output=exec_list) +
   Check phase record (input=dependency graph, output=executable)
   git add log_file (committed with next commit)

4. Launch AI CLI in version worktree's tmux window:

   Read ai_cli from .claude/config.yaml:
     ai_cli:
       tool: "claude-code"          # claude-code | codex | aider
       command: "claude"             # CLI command to invoke
       flags: ""                     # Auto-approval flags

   IMPORTANT — Execution modes and required flags:

     Interactive (tmux window):
       claude                        # user confirms each tool call
       → Best for: first task, debugging, complex UI work

     Autonomous (tmux or -p mode):
       claude -p --dangerously-skip-permissions "..."
       → Required: --dangerously-skip-permissions for file write access
       → Without it: Worker analyzes code but CANNOT write changes
       → Best for: batch execution, CI, unattended workers

     Codex:
       codex --full-auto "..."
       → Autonomous by default, no extra flags needed

   Tool dispatch rules:
     - claude-code: full capabilities (MCP Figma, screenshots, interactive)
       → For autonomous mode: MUST use --dangerously-skip-permissions
     - codex: autonomous code execution (no images, no MCP, no user interaction)
       → Pre-fill Trigger + chain in execution log before launch
       → Post-fill Outcome after Codex completes
     - aider: similar to codex constraints

   Prompt construction (tool-agnostic):
     TASK_PROMPT = "Execute spec-next for T{nn}.
       Read .claude/commands/spec-next.md for the full execution protocol.
       Step 6 requirements:
       - Read specs/{project}/{version}/implementation/overview.md (understand the big picture)
       - Read specs/{project}/{version}/implementation/{platform}/tech-plan.md (understand platform approach)
       - Read specs/{project}/{version}/implementation/F{nn}-{name}/design.md
         If missing -> generate from Feature YAML + template, git commit to specs
       - Generate specs/{project}/{version}/implementation/F{nn}-{name}/{platform}.md
         If exists -> check if update is needed
       - overview.md / tech-plan.md missing -> generate from project state + template
       Execution log: specs/{project}/{version}/_logs/{date}-task-T{nn}-{platform}.md
       After completing each phase (Collect/Execute/Verify), append phase record to log.
       At task end, append friction-point summary + workflow observations.
       Log format: see specs/workflows/execution-log.template.md.
       After completion, automatically continue to the next task until all done or blocked"

   win_name = {platform}-{version_short}  (e.g. "android-v120")
   tmux send-keys -t "{win_name}.1" \
     "{ai_cli.command} {ai_cli.flags} '{TASK_PROMPT}'" Enter

   Key point: Workers operate in the same version worktree continuously.
   All task code changes are committed directly to the version branch.
   After completing the current task, the worker session will automatically:
   a. Commit code to the version branch
   b. Update specs task status (in-progress -> done)
   c. Run /spec-next (no arguments) to find the next task
   d. Continue executing in the same worktree
   e. Until no available tasks remain

=== CR Rework Tasks (mode = "cr_propagate") ===

   CR rework also runs in the version worktree; no separate worktree needed.
   Launch AI CLI in the version worktree's tmux window (single-shot mode):
   tmux send-keys -t "{win_name}.1" \
     "{AI_CLI_COMMAND} 'Apply CR-{nnn} changes to T{nn}:
       Change summary: {CR change field}
       Change points: {lines marked [CR-{nnn}] in Feature YAML}
       Task notes: {warning notes in task file}
       Implementation updates:
       - Read specs/{project}/{version}/implementation/F{nn}-{name}/design.md
       - Update CR change highlights section (Section 6)
       - Update specs/{project}/{version}/implementation/F{nn}-{name}/{platform}.md
       - Fill CR rework section (Section 6): what to change, what NOT to change
       Rule: apply ONLY CR-{nnn} changes; do not modify other code.
       After completion: build verification + code review -> commit to version branch -> update CHANGELOG checklist'" Enter

   Worker completion:
   a. Commit changes to the version branch
   b. Update CHANGELOG checklist: [ ] -> [x]
   c. If all CR checklist items complete -> status -> done
   d. git add + commit: "docs: CR-{nnn} propagated to {platform} T{nn}"
```

### Phase 4: Return Control

```
Output:
## Execution Launched

| Platform | First Task | Tmux Window | Worktree |
|----------|-----------|-------------|----------|
| iOS  | T06 Self-Setting | {version} | wt/{platforms.ios.repo}/{version} |
| Android | T06 Self-Setting | {version} | wt/{platforms.android.repo}/{version} |

### Execution Expectations
Each session auto-loops through available tasks in the version worktree:
iOS:     T06 -> T07 -> T08 -> T09 -> T10 -> (waiting B01-B03) -> pause
Android: T06 -> T07 -> T08 -> T09 -> T10 -> (waiting B01-B03) -> pause

### Monitoring
- /spec-drive status -> view real-time progress on both platforms
- Switch to the corresponding tmux window -> view execution details
- When a task is blocked, the session outputs a blocking report and stops

### Worker Single-Task Flow
Check -> Collect -> Analyze+Design -> Execute -> Verify -> Review -> Commit -> Update -> [Loop: find next]
```

---

## Change Sub-command

```
/spec-drive change <type> <scope> "<description>"

type: API / PRD / Figma / i18n / Feature / Requirement / Workflow
scope: API endpoint path (e.g. /post/get_story_detail)
     | Figma node ID (e.g. 152:75)
     | Feature ID (e.g. F06)
     | Free text (for PRD/Requirement/Workflow types)

Execution flow:

1. Read {project}/{version}/CHANGELOG.md:
   - Parse existing CR numbers -> max value N
   - New number = CR-{N+1}, zero-padded to 3 digits (e.g. CR-003)

2. Read {project}/{version}/config.yaml dependency_index:
   - type=API -> api_to_features[scope] -> affected Features
   - type=Figma -> figma_to_features[scope] -> affected Features
   - type=Feature -> use scope directly
   - Other types -> require manual specification, or scan all Feature YAMLs for references

3. Expand impact scope:
   For each affected Feature:
   - Find Feature -> Task mapping: iOS T{nn}, Android T{nn}
   - Find Feature -> Backend: feature_to_backend[F{nn}] -> B{nn}
   - Aggregate: all affected Tasks + Backend entries

4. Generate CR entry:
   ## [CR-{nnn}] {date} -- {description}

   - **Type**: {type}
   - **Source**: (leave blank to fill)
   - **Change**: {description}
   - **Impact**: {Features} -> {Tasks} + {Backends}
   - **Actions**:
     - [ ] {generate checklist from impact scope}
   - **Status**: Pending propagation

5. Append to CHANGELOG.md (insert before the first existing ## entry)

6. Output impact report:
   === CR-{nnn} Impact Analysis ===
   Type: {type}
   Change: {description}
   Impact scope:
     Features: F08, F09, F10
     iOS Tasks: T08, T09, T10
     Android Tasks: T08, T09, T10
     Backend: B06, B07
   Generated checklist: {N} items

7. After confirmation, git add + commit: "docs: CR-{nnn} {description}"
```

---

## Change Status Sub-command

```
/spec-drive change status

1. Read {project}/{version}/CHANGELOG.md
2. Parse all CR entries:
   - Extract checklist: [x] and [ ] counts
   - Calculate completion: done/total
3. Output propagation status board:

   ## Change Propagation Status

   | CR | Date | Description | Completion | Status |
   |----|------|-------------|------------|--------|
   | CR-001 | 2026-03-02 | IM say -> HTTP POST | 4/4 | Done |
   | CR-003 | 2026-03-06 | Add creator_id | 2/4 | In-progress |

   Incomplete items:
   - CR-003: [ ] iOS T08 remove fallback
   - CR-003: [ ] Android T08 remove fallback
```

---

## Propagate Sub-command

```
/spec-drive propagate CR-{nnn} [platform]

platform = ios | android | auto (default auto = both platforms)

Drives CR change rework on already-completed tasks. Fully automated, no intermediate confirmation.
Quality is validated through build + code review at the end.

Execution flow:

1. Parse arguments:
   - cr_id = CR-{nnn}
   - platform = ios | android | auto (default auto = both platforms)

2. Read CHANGELOG.md:
   - Find CR-{nnn} entry
   - Parse **Impact** -> extract Feature and Task lists
   - Parse **Actions** -> extract checklist
   - If status is Done -> output "CR-{nnn} fully propagated, no action needed", exit

3. Filter tasks requiring code changes:
   - From checklist, filter [ ] items related to "iOS T{nn}" / "Android T{nn}"
   - Exclude "backend confirmation" / "Figma confirmation" and other non-code items (these require manual completion)
   - If no code items -> output "Remaining items require manual confirmation, no auto-executable code changes", exit

4. Read Feature YAML:
   - Get CR's revisions entry -> change summary
   - Get change-related specific fields (lines marked [CR-{nnn}])

5. Output propagation plan (log only, no confirmation wait):

   ## CR-{nnn} Code Propagation -- Auto-execute

   Change: {CR description}

   | Platform | Task | Current Status | Action |
   |----------|------|---------------|--------|
   | iOS  | T06  | Done | Apply changes in version worktree |
   | Android | T06 | Done | Apply changes in version worktree |

   Change details:
   - (extracted from CR's **Change** field)

   Non-code items (require manual action):
   - B04 backend API confirmation
   - Figma confirmation

6. Execute directly in version worktree, for each (task, platform):
   a. Confirm version worktree exists: wt/{platforms.<platform>.repo}/{version}/
      If missing -> create: cd {repo} && bash {wt_script} new {version} {VERSION_BRANCH}
   b. Launch AI CLI session in the version worktree's tmux window, prompt includes:
      - CR change summary
      - All change points marked [CR-{nnn}] in Feature YAML
      - Warning notes from the task file
      - Instruction: "Apply ONLY CR-{nnn} changes; do not modify other code"
      - Instruction: "After completion, run build verification + code review"

7. Worker completion (build passed + review passed):
   a. Commit changes to the version branch
   b. Update CHANGELOG checklist: [ ] -> [x] (for the corresponding code items)
   c. If all CR checklist items complete -> update status to Done
   d. git add + commit: "docs: CR-{nnn} propagated to {platform} T{nn}"

8. Output result report:
   ## CR-{nnn} Propagation Results

   | Platform | Task | Result |
   |----------|------|--------|
   | iOS  | T06  | Done, merged |
   | Android | T06 | Done, merged |

   CHANGELOG updated: CR-{nnn} checklist {done}/{total}
   Status: In-progress -> Done (if all complete)
```

---

## Verify Sub-command

```
/spec-drive verify

Run final build verification on the version integration branch:

1. For each platform:
   a. Confirm current branch: git -C {repo} branch --show-current == {VERSION_BRANCH}
   b. If not on the version branch:
      git -C {repo} checkout {VERSION_BRANCH}
   c. Execute build:
      cd {repo} && {build_cmd}
   d. Record result

2. Output:
   ## {VERSION_BRANCH} Integration Verification

   | Platform | Build Result | Duration |
   |----------|-------------|----------|
   | iOS  | BUILD SUCCEEDED | 45s |
   | Android | BUILD SUCCESSFUL | 60s |

   Or report build error details
```

---

## Done Sub-command

```
/spec-drive done

Version summary + cleanup:

1. Aggregate feature completion from {project}/{version}/tasks/ios.md + android.md
2. Read {project}/{version}/tasks/backend.md -> backend status
3. Check for incomplete tasks or blocking items
4. Output:

   ## v{version} Completion Summary

   ### Feature Progress
   | Feature | iOS | Android | Backend |
   |---------|-----|---------|---------|
   | F01 Message Long-press Menu | Done | Done | N/A |
   ...

   ### Statistics
   - iOS: 10/10 complete
   - Android: 10/10 complete
   - Total: 20/20 tasks complete

   ### Next Steps
   - /spec-drive verify -> final build verification
   - Merge version branch -> master -> submit for QA
   - Clean up version worktrees: wt rm {version} (both platforms)
```

---

## Key Conventions

### Version Branch
- Naming: derived from branch.pattern in config.yaml (e.g. `feat/{project}/{version}`)
- Main repo stays on master (stable); no direct development in the main directory
- All development happens in version worktrees; code commits go directly to the version branch

### Version Worktree (one worktree per version)
- Path: `wt/{platforms.<platform>.repo}/{version}/`
- Branch: derived from branch.pattern in config.yaml
- Created during the setup phase; reused throughout the entire version lifecycle
- All tasks (T01~T12) are developed in the same worktree
- Cleaned up after version completion: `wt rm {version}`

### Task ID -> Commit Mapping
Tasks no longer correspond to individual worktrees/branches; instead they are commit(s) on the version branch:
- T01 Message Menu -> commit: `feat(chat): add message longpress menu (T01)`
- T06 Self-Setting -> commit: `feat(settings): implement self-setting page (T06)`
- T09 Story Edit Page -> commit: `feat(story): add story edit page (T09)`

### Worker Session Autonomy Protocol (with loop)
Each tmux window's Claude Code session operates autonomously in the version worktree:

```
LOOP:
  1. If a task is specified -> execute that task
     If none specified -> /spec-next (auto-find next available)
  2. If no available tasks -> output completion report, EXIT
  3. Worker stays in the version worktree at all times (no worktree creation/switching)
  4. Execute: Check -> Collect -> Analyze+Design -> Execute -> Verify -> Review
  5. If failed -> mark blocked, GOTO LOOP (skip that task)
  6. If successful:
     a. Commit code to version branch (git add + commit)
     b. Update specs status (in-progress -> done)
  7. GOTO LOOP
```

Loop termination conditions:
- All tasks done -> output "All tasks complete"
- All remaining tasks blocked (backend API / prerequisite dependency) -> output blocking report
- 2 consecutive task failures -> pause, suggest manual intervention

### Specs Change Conflict Handling
Two workers updating specs simultaneously:
- ios.md and android.md are separate files -> no conflict
- Workers do not write DASHBOARD.md directly -> eliminates the primary conflict source
- Before each specs commit, run `git pull --rebase` -> auto-merge
- In rare rebase conflicts -> worker reports, waits for manual resolution
