# Spec System Architecture

> Fully automated pipeline from PRD to code: Generate, Orchestrate, Execute.

---

## 1. Overview

```
PRD + Figma + API Docs              <- User-provided materials
        |
   /spec-init                       <- Generation layer: one-shot spec skeleton
        |
   {project}/{version}/             <- Specification layer: Feature YAML + Task Plan + i18n + ...
        |
   /spec-drive setup                <- Orchestration layer: create version branch
   /spec-drive next                 <- Orchestration layer: analyze deps -> dispatch Worker
        |
   Worker x N (iOS + Android)       <- Execution layer: autonomous 11-step dev loop
        |
   /spec-drive done                 <- Version complete
```

---

## 2. Spec vs Agent vs Worker

### Core Relationship

```
Spec  = WHAT to do     (requirements, constraints, task graph, acceptance criteria)
Agent = HOW to do it   (platform conventions, coding rules, build tools, entry points)
Worker = Runtime instance that reads Spec for context + follows Agent conventions for execution
```

**Spec** is the shared contract between humans and AI. It lives in the spec-orchestrator repo and defines features, tasks, dependencies, and acceptance criteria -- platform-agnostic.

**Agent** is a platform-specific configuration layer. It lives in `agents/{platform}/` and defines how code should be written for that platform -- coding conventions, UI framework rules, build commands, and AI entry points.

**Worker** is an AI agent instance that runs in an isolated worktree. It is created by `spec-drive`, inherits Agent conventions from the platform repo, and reads Spec files to know what to implement.

### Binding Mechanism

```
spec-orchestrator/                      Platform repo (e.g., my-ios-app/)
+-------------------------------+       +-------------------------------+
|                               |       |                               |
| agents/ios/                   |       | .claude/config.yaml           |
|   ai/ios.md          (HOW)   | sync  |   specs_path: ../specs/proj   |
|   ai/ui.md           (HOW)   |------>|   platform: ios               |
|   CLAUDE.md          (HOW)   |       | ai/ios.md              (HOW)  |
|   .claude/config.yaml        |       | ai/ui.md               (HOW)  |
|                               |       | .claude/commands/             |
| {project}/{version}/          |       |   spec-next.md   (PROTOCOL)   |
|   features/F01.yaml  (WHAT)  |<------| specs/ -> ../specs/{project}  |
|   tasks/ios.md       (WHO)   | read  | CLAUDE.md              (HOW)  |
|   config.yaml        (DEPS)  |       |                               |
|   implementation/    (WHY)   |       |                               |
+-------------------------------+       +-------------------------------+
```

1. **Sync**: `agents/sync.sh` deploys agent configuration (shared + platform-specific) into the platform repo.
2. **Link**: Platform repo's `.claude/config.yaml` points to the spec repo via `specs_path`, establishing a symlink.
3. **Dispatch**: `spec-drive` reads spec files for task dependency graph, then creates a worktree in the target platform repo and launches a Worker.
4. **Execute**: Worker inherits agent conventions (`ai/*.md`, `CLAUDE.md`) from the platform repo, and reads spec files (`features/*.yaml`, `tasks/*.md`) for requirements and context.

### Multi-Platform Coordination

`spec-drive` can dispatch Workers to multiple platforms simultaneously:

```
spec-drive next
  |
  +-- Read config.yaml -> dependency graph -> Wave 1 tasks
  |
  +-- iOS Worker (worktree in ios-repo)
  |     Reads: agents/ios conventions + features/F01.yaml + tasks/ios.md
  |     Writes: code in ios-repo + status in tasks/ios.md
  |
  +-- Android Worker (worktree in android-repo)
        Reads: agents/android conventions + features/F01.yaml + tasks/android.md
        Writes: code in android-repo + status in tasks/android.md
```

Each Worker operates independently in its own worktree. They share the same Spec (same Feature YAML, same acceptance criteria) but follow different Agent conventions (different coding rules, build tools, UI frameworks).

---

## 3. Three-Layer Architecture

### 3.1 Generation Layer -- `/spec-init`

**Responsibility**: One-shot generation of the complete spec skeleton from PRD + materials.

```
Input                               Processing                        Output
-----------                         ----------------                  --------------
PRD (PDF/MD)           ->  Step 3: PRD parsing           ->  features/F{nn}-*.yaml
Figma (file_key)       ->  Step 4: Figma indexing        ->  figma-index.md
Swagger (JSON)         ->  Step 5: API parsing           ->  tasks/backend.md
i18n seeds             ->  Step 6: Full generation       ->  config.yaml
                          Step 7: Cross-validation           tasks/{ios,android}.md
                                                             i18n/strings.md
                                                             CHANGELOG.md
```

**Three modes**:

| Mode | Command | Purpose |
|------|---------|---------|
| generate | `/spec-init 1.0` | Full generation (when version dir does not exist) |
| refresh | `/spec-init 1.0 refresh` | Incremental additions (after PRD changes add features) |
| validate | `/spec-init 1.0 validate` | Validate only, no file modifications |

### 3.2 Orchestration Layer -- `/spec-drive`

**Responsibility**: Task analysis + dependency graph + worktree creation + Worker dispatch + status monitoring.

```
+------------------------------------------------------------------+
|                     specs repo (orchestration hub)                |
|                                                                  |
|  /spec-init:   PRD + materials -> spec skeleton (one-shot)       |
|  /spec-drive:  analyze + dispatch + monitor + change management  |
|  /spec-next:   status view + task location                       |
|                                                                  |
|  +--------------------------------------+                        |
|  |        Orchestrator Core Flow        |                        |
|  |                                      |                        |
|  |  Phase 0: Pre-checks (tmux/branch)   |                        |
|  |  Phase 1: Global analysis (DAG/wave) |                        |
|  |  Phase 2: Show plan + confirm        |                        |
|  |  Phase 3: Infra (worktree/tmux)      |                        |
|  |  Phase 4: Return control             |                        |
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

**Full subcommand set**:

| Subcommand | Frequency | Responsibility |
|------------|-----------|----------------|
| `setup` | Once per version | Check spec completeness -> create version branch |
| `next [platform]` | Multiple times | Smart analysis -> worktree -> Worker dispatch |
| `T{nn} [platform]` | On demand | Execute a specific task |
| `status` | Anytime | Aggregate cross-platform progress -> DASHBOARD |
| `reset T{nn}` | Fault recovery | Reset stuck task back to pending |
| `change <type> <scope> "<desc>"` | On demand | CR record + impact analysis |
| `change status` | Anytime | CR propagation dashboard |
| `propagate CR-{nnn}` | On demand | CR code rework |
| `verify` | End of version | Version branch compilation check |
| `done` | Once per version | Version completion summary |

### 3.3 Execution Layer -- `/spec-next` (Worker)

**Responsibility**: Autonomously complete the full development lifecycle within a worktree.

```
+--------------------------------------------------------------+
|                    Worker Session Loop                        |
|                                                              |
|  LOOP:                                                       |
|    Step 1   Config     Read configuration                    |
|    Step 2   Status     Collect task statuses                 |
|    Step 3   Resolve    Locate target task                    |
|    Step 4   Context    Present context (Figma/API/i18n)      |
|    Step 5   Lock       pending->active + git commit          |
|    Step 6   Analyze    design.md + {platform}.md             |
|    Step 7   Execute    API Verify -> Collect -> Code -> Build|
|    Step 8   Review     Code Review (max 3 rounds)            |
|    Step 9   Merge      merge -> feat/v{version} + cleanup    |
|    Step 10  Update     active->done + git commit             |
|    Step 11  Loop       Next task or EXIT                     |
|                                                              |
|  Exit conditions:                                            |
|    - All tasks complete                                      |
|    - All tasks blocked                                       |
|    - 2 consecutive failures                                  |
+--------------------------------------------------------------+
```

---

## 4. Specification Layer -- Directory Structure

```
{project}/{version}/
|
+-- config.yaml ---------------------- Version configuration
|   +-- version, codename
|   +-- figma.file_key
|   +-- paths (all file locations)
|   +-- api.swagger_files
|   +-- features[] (quick index)
|   +-- dependency_index
|       +-- api_to_features         /api/tasks -> [F01]
|       +-- figma_to_features       "119:370" -> [F02]
|       +-- feature_to_backend      F02 -> [B01]
|
+-- prd/
|   +-- README.md --------------------- Structured PRD index
|   +-- *.pdf ------------------------- PRD source documents
|
+-- features/
|   +-- F01-xxx.yaml ------------------ What + Constraint
|   +-- F02-xxx.yaml                      id, name, module, epic
|   +-- ...                               description, requirements
|   +-- F{nn}-xxx.yaml                    acceptance_criteria
|                                         ui_contract <- Figma-driven
|                                         delivery_contract <- tech stack constraints
|                                         state_matrix <- state scenarios
|                                         figma.pages[] <- design resources
|                                         api[] <- endpoint definitions
|                                         analytics[] <- event tracking (capability)
|                                         i18n_keys[] <- internationalization (capability)
|                                         capabilities[] <- enabled capability list
|                                         platform_tasks <- T/B mapping
|                                         dependencies <- inter-feature deps
|
+-- tasks/
|   +-- shared.md --------------------- S1-S3 prerequisites + API patterns + error codes
|   +-- backend.md -------------------- B01-B{nn} backend API details
|   +-- ios.md ------------------------ T01-T{nn} single source of truth (iOS)
|   +-- android.md -------------------- T01-T{nn} single source of truth (Android)
|
+-- i18n/                                 (capability: i18n)
|   +-- strings.md -------------------- key | zh | ja | en
|
+-- figma-index.md -------------------- Section -> Page -> Node ID
|
+-- CHANGELOG.md ---------------------- CR change log + checklist
|
+-- DASHBOARD.md ---------------------- Progress dashboard (aggregated)
|
+-- implementation/ ------------------- How + Why
    +-- overview.md                       Version-wide design overview
    +-- ios/tech-plan.md                  iOS platform technical plan
    +-- android/tech-plan.md              Android platform technical plan
    +-- F{nn}-{name}/
        +-- design.md                     Shared design (cross-platform)
        +-- ios.md                        iOS platform specifics
        +-- android.md                    Android platform specifics
```

---

## 5. Data Flow

### 5.1 Generation-Time Data Flow (spec-init)

```
PRD --+-- Epic/Feature extraction -----> features/F{nn}.yaml
      +-- Analytics extraction ---------> features/F{nn}.yaml -> analytics[]
      +-- Dependency extraction --------> tasks/backend.md (B{nn})
      +-- Copy extraction --------------> i18n/strings.md (if i18n capability enabled)

Figma --- Section/Page query ----------> figma-index.md
      +-- Page->Feature mapping --------> features/F{nn}.yaml -> figma.pages[]

Swagger -- Endpoint extraction --------> features/F{nn}.yaml -> api[]
       +-- Param/response extraction ---> tasks/backend.md (details)

All above --- Reverse index ------------> config.yaml -> dependency_index
          +-- Task scatter -------------> tasks/{ios,android}.md
```

### 5.2 Execution-Time Data Flow (spec-drive + spec-next)

```
config.yaml ----------------------> spec-drive: version config
tasks/{platform}.md --------------> spec-drive: dependency graph + wave planning
                                 -> spec-next:  task location + status read/write

features/F{nn}.yaml -------------> Worker Step 4: context collection
                                 -> Worker Step 6: design input
                                 -> Worker Step 7: API Verify baseline

figma-index.md ------------------> Worker Step 7: Figma screenshot download
i18n/strings.md -----------------> Worker Step 7: i18n file writing (if i18n capability enabled)
tasks/backend.md ----------------> Worker Step 7: API Contract Verify

implementation/*.md -------------> Worker Step 6: read/generate design
                                 -> Worker Step 7: implement per design
```

### 5.3 Change-Time Data Flow (spec-drive change + propagate)

```
Change occurs
  |
  v
/spec-drive change api /path "desc"
  |
  +-- config.yaml dependency_index --> Impact scope (Features -> Tasks)
  +-- CHANGELOG.md --> New CR-{nnn} + checklist
  +-- features/F{nn}.yaml --> revisions[] record
  |
  v
Manual spec file updates (YAML + Task)
  |
  v
/spec-drive propagate CR-{nnn}
  |
  +-- Create worktree (CR{nnn}-T{nn}-xxx)
  +-- Worker: apply only CR changes -> build -> review
  +-- merge -> feat/v{version}
  +-- CHANGELOG checklist [x] -> all done -> complete
```

---

## 6. Feature YAML vs implementation/ Division

```
Feature YAML = What + Constraint         implementation/ = How + Why
(what to do, UI contract, data           (how to do it, why, module
 contract, state matrix)                  interactions)

+-------------------------+              +--------------------------+
| F01-task-list.yaml      |              | F01-task-list/           |
|                         |              |                          |
| description: Task list  |  --gen-->    | design.md                |
| requirements: R01-R04   |              |   impact analysis, data  |
| acceptance_criteria     |              |   flow, API strategy,    |
| ui_contract             |              |   key decisions          |
| delivery_contract       |  --refine--> |                          |
| state_matrix            |              | ios.md                   |
| api[]                   |              |   existing code analysis |
| i18n_keys[]             |              |   file change manifest   |
| analytics[]             |              |   platform tech choices  |
+-------------------------+              |                          |
                                         | android.md               |
 spec-init generates                     |   (same, Android view)   |
 + manual supplement                     +--------------------------+
                                          Worker Step 6 generates
```

**Generation timing**:

| Document | When Generated | Generated By |
|----------|---------------|--------------|
| Feature YAML | `/spec-init` | spec-init + manual supplement |
| overview.md | First execution of version | First Worker |
| {platform}/tech-plan.md | First execution of version | First Worker |
| F{nn}/design.md | First task of a Feature | Worker (shared cross-platform) |
| F{nn}/{platform}.md | Each Worker | Worker (platform-specific) |

---

## 7. Status Lifecycle

```
pending (not started)
    |
    |  Worker Step 5: Lock
    v
active (in progress)
    |
    +-- build + review pass ------> done (complete)
    |                                |
    |                                +-- CR change -> rework_needed
    |                                                  |
    |                                                  | propagate
    |                                                  v
    |                                                active -> done
    |
    +-- failure/blocked
         |
         +-- blocked (worktree preserved)
              |
              +-- /spec-drive reset -> pending -> re-execute
```

| Symbol | Meaning | Location |
|--------|---------|----------|
| pending | Not started | tasks/{platform}.md |
| active | In progress | tasks/{platform}.md (after Lock) |
| rework | Needs rework | tasks/{platform}.md (after CR change) |
| done | Complete | tasks/{platform}.md (after verification) |
| n/a | Not applicable | DASHBOARD.md (no backend dependency) |

**Single source of truth**: `tasks/{platform}.md` -- Worker reads/writes here, DASHBOARD is aggregated by `status` command.

---

## 8. Branch and Worktree Strategy

```
master (or main)
  |
  +-- feat/v1.0  <- version integration branch (merge target for all tasks)
       |
       +-- feat/{platform_repo}_ios/0306/T01-task-list          <- task branch
       +-- feat/{platform_repo}_ios/0306/T02-create-task
       +-- feat/{platform_repo}_android/0306/T01-task-list
       +-- feat/{platform_repo}_android/0306/T02-create-task
```

**Worktree lifecycle**:

```
Create -> wt.sh new T01-xxx feat/v1.0
       -> wt/{project}/{MMDD}/T01-xxx/ + tmux window + symlinks

Use    -> Worker develops in worktree (Step 6-8)

Merge  -> git merge --no-ff -> feat/v{version}

Clean  -> wt.sh -f rm T01-xxx -> delete worktree + branch + tmux window
```

---

## 9. Smart Analysis -- Execution Waves

Build a dependency graph from the dependency column in tasks/{platform}.md to plan parallel execution batches:

```
Example:

T01 -+-> T02 --> (wait B01)
     +-> T03 --> (wait B02)
     +-> T04
     +-> T05

T06 (independent) --> (wait B03)
T07 (independent)

T08 -> T09 --> (wait B04)
        +-> T10

T11 (independent)

Wave 1: T01, T06, T07, T08, T11        <- No dependencies, can run in parallel
Wave 2: T04, T05, T09                   <- Depend on Wave 1
Wave 3: T10                             <- Depends on T09
Blocked: T02, T03                       <- Waiting for backend B01-B02
```

---

## 10. Change Management

```
CHANGELOG.md              dependency_index            Feature YAML
(change records)          (impact analysis)            (change tracking)
     |                        |                           |
     |  /spec-drive change    |                           |
     |  ----------------->    |                           |
     |  Auto-generate CR-{nnn}|  api_to_features         | revisions[]
     |  + checklist           |  figma_to_features       | [CR-{nnn}] annotations
     |                        |  feature_to_backend      |
     v                        v                           v
  CR-003                   F01 -> T01 iOS              F01.yaml
  pending propagation      F01 -> T01 Android          + [CR-003] line
  checklist: 6 items       F01 -> B01                  + revisions record
     |
     |  /spec-drive propagate CR-003
     |  --------------------------->
     |
     v
  Worker: worktree -> apply changes only -> build -> review -> merge
  CHANGELOG: [ ] -> [x]
  All [x] -> CR-003 complete
```

---

## 11. Authoritative File Index

| File | Role | Written By | Read By |
|------|------|------------|---------|
| `.claude/commands/spec-init.md` | Generation protocol | - | spec-init |
| `.claude/commands/spec-drive.md` | Orchestration protocol | - | spec-drive |
| `{platform}/.claude/commands/spec-next.md` | Execution protocol | - | Worker |
| `{project}/{version}/config.yaml` | Version config | spec-init | All |
| `{project}/{version}/features/*.yaml` | Requirement specs | spec-init + manual | Worker |
| `{project}/{version}/tasks/{platform}.md` | **Single source of truth** | Worker + spec-drive | All |
| `{project}/{version}/tasks/backend.md` | Backend API | spec-init + manual | Worker |
| `{project}/{version}/implementation/*.md` | Implementation design | Worker | Worker |
| `{project}/{version}/CHANGELOG.md` | Change tracking | spec-drive change | propagate |
| `{project}/{version}/DASHBOARD.md` | Progress dashboard | spec-drive status | Manual viewing |
| `{project}/{version}/figma-index.md` | Figma index | spec-init | Worker |
| `{project}/{version}/i18n/strings.md` | Internationalization (capability) | spec-init | Worker |
| `_scripts/SPEC-DRIVE-GUIDE.md` | Operations guide | - | Manual reference |
| `_scripts/SPEC-ARCHITECTURE.md` | Architecture doc | - | Manual reference |
| `_templates/*.yaml\|md` | File templates | - | spec-init |

---

## 12. Typical Workflow

### New Version Full Development

```bash
# 1. Prepare materials
#    Place PRD in {project}/1.0/prd/

# 2. Generate specs
/spec-init 1.0                    # PRD + Figma + API -> complete spec

# 3. Supplement manual fields (optional, does not block execution)
#    ui_contract, delivery_contract, state_matrix.figma_node

# 4. Initialize
/spec-drive setup                 # Check spec completeness -> create version branch

# 5. Execute
/spec-drive next                  # Auto-analyze -> multi-platform parallel launch
#    iOS:     T01 -> T04 -> T05 -> ... -> pause (waiting for backend)
#    Android: T01 -> T04 -> T05 -> ... -> pause (waiting for backend)

# 6. Monitor
/spec-drive status                # Real-time cross-platform progress

# 7. Handle changes
/spec-drive change api /path "added new field"
/spec-drive propagate CR-001      # Automatic rework

# 8. Complete
/spec-drive verify                # Compilation check
/spec-drive done                  # Version summary
```

### Incremental Update After PRD Changes

```bash
/spec-init 1.0 refresh            # Add new features without overwriting existing ones
/spec-drive next                  # Auto-detect new tasks
```

### Validate Only

```bash
/spec-init 1.0 validate           # Output pass/fail/warning report
```
