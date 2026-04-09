---
description: Autonomous task execution loop within a platform repo worktree
---

# /spec-next -- Worker-Side Task Execution

User request: $ARGUMENTS

## Tool Compatibility

This protocol works with **any AI CLI tool** that can read files and run shell commands. The `.claude/` directory name is a convention inherited from Claude Code -- all tools can and should read files in this directory.

### Tool-Specific Notes

| Tool | Discovery | Figma | Notes |
|------|-----------|-------|-------|
| **Claude Code** | Auto-discovers as `/spec-next` slash command | MCP Figma access (live download) | Full interactive capability; handles visual-qa, review, user confirmation gates |
| **Codex CLI** | Invoked via prompt (e.g., "read `.claude/commands/spec-next.md` and execute T01") | No MCP; reads cached screenshots from `.claude/cache/` | Autonomous execution; no mid-task user interaction |
| **Aider / other** | Invoked via prompt, same as Codex | No MCP; reads cached screenshots | Any tool that can read files + run shell commands can follow this protocol |

### Configuration Access

- `.claude/config.yaml` is read by ALL tools despite the directory name -- it contains project-level config (version, platform, specs path) that every tool needs
- `.claude/commands/` contains execution protocols readable by any tool
- `.claude/workflows/` contains workflow definitions readable by any tool
- `.claude/cache/` contains cached Figma screenshots and other resources accessible to all tools

### Executor Identification

When creating execution logs, set the `executor:` frontmatter field to identify which tool ran the task:
- `claude-code` -- executed by Claude Code
- `codex` -- executed by Codex CLI
- `human` -- executed manually
- `aider` -- executed by Aider (or other tool name as appropriate)

---

## Overview

This command runs inside a **platform repository** (iOS/Android/Web) worktree.
It autonomously locates, executes, and completes development tasks in a loop.

Unlike the specs-repo `/spec-next` (status view only), this is the **execution engine**.

---

## Step 1: Read Configuration + Resolve Context

```
1. Read .claude/config.yaml:
   - version.current -> {version}
   - project.platform -> {platform} (ios / android / web)
   - project.name -> {project}
   - repos.specs.hint -> hint path for specs repo
   - repos.api-doc.hint -> hint path for API docs

2. Resolve external context:
   a. Check .context-resolved.yaml exists in current directory
   b. If exists -> read resolved paths:
      - repos.specs -> absolute path to specs repo
      - repos.api-doc -> absolute path to API docs
      - drift.* -> pin drift warnings
   c. If missing -> run resolve-context.sh:
      - If scripts/resolve-context.sh exists locally -> use it
      - Else if {specs}/scripts/resolve-context.sh exists -> use it
      - Else -> fall back to legacy resolution (symlink + hint paths)
   d. After resolution, log any drift warnings

3. Derive paths (using resolved absolute paths):
   SPECS = .context-resolved.yaml repos.specs (or fallback: specs.path from config)
   API_DOC = .context-resolved.yaml repos.api-doc (or fallback: api_doc.path from config)
   PROJECT_DIR = {SPECS}/{project}
   VERSION_DIR = {PROJECT_DIR}/{version}
   TASKS_FILE = {VERSION_DIR}/tasks/{platform}.md
   BACKEND_FILE = {VERSION_DIR}/tasks/backend.md
   SHARED_FILE = {VERSION_DIR}/tasks/shared.md
   CONFIG_FILE = {VERSION_DIR}/config.yaml
   CONTEXT_FILE = {VERSION_DIR}/context.yaml
   CHANGELOG = {VERSION_DIR}/CHANGELOG.md
   LOG_DIR = {VERSION_DIR}/_logs

Note: SPECS and API_DOC are absolute paths from .context-resolved.yaml.
This ensures correct resolution in both main repos and worktrees.
Legacy symlink-based resolution still works as fallback if .context-resolved.yaml
is not present.
```

---

## Step 2: Collect Status

Read in parallel:

```
1. Platform tasks:
   Read TASKS_FILE -> parse task overview table
   Extract: task ID, name, feature, status, dependencies

2. Backend API readiness:
   Read BACKEND_FILE -> parse API readiness timeline
   Extract: B{nn} ID, endpoint, blocking feature, status

3. Shared dependencies:
   Read SHARED_FILE -> parse S1-S3 status
   Extract: dependency ID, name, status

4. Active worktrees (optional, for conflict detection):
   git worktree list --porcelain -> extract task IDs from branch names ([TF]\d{2})

5. CR changes:
   Read CHANGELOG -> parse all CRs with active/pending status
   Extract: CR ID, affected tasks, incomplete checklist items
```

---

## Step 3: Determine Target Task

Parse $ARGUMENTS:

```
Case 1: "T{nn}" -> target_task = T{nn}, skip to Step 4

Case 2: "status" or empty with no executable tasks -> output status summary:
   - List all tasks with current status
   - Highlight next available task
   - Show blocking reasons for blocked tasks
   - EXIT (status view only, no execution)

Case 3: empty or "next" -> auto-locate next available task:
   For each task in overview table order (T01 -> T{nn}):
     Skip if status is done
     Skip if status is active (another session may own it)
     Check availability:
       a. All prerequisite tasks (dependency column) are done
       b. Backend API (B{nn} mapping) is ready (done) or no backend dependency
       c. No active worktree contains this task ID
       d. No un-propagated CR blocks this task
     First task passing all checks -> target_task
   If no task available:
     Output blocking report + EXIT

Case 4: "F{nn}" -> look up config.yaml features or Feature YAML
   -> map to platform task T{nn} -> proceed as Case 1
```

---

## Step 4: Show Task Context

Read target task detail from TASKS_FILE and associated Feature YAML:

```
Output:
  ## Executing T{nn}: {task_name}
  Feature: F{nn} - {feature_name}
  Status: {current_status} -> will mark active

  ### Figma Pages
  | Page | Node ID | Usage |
  |------|---------|-------|
  (from Feature YAML figma.pages[])

  ### API Endpoints
  | Endpoint | Method | Source | Usage |
  |----------|--------|--------|-------|
  (from Feature YAML api[])

  ### i18n Strings
  | Key | Default |
  |-----|---------|
  (from Feature YAML i18n_keys[] or {version}/i18n/strings.md)

  ### Dependencies
  - Prerequisite tasks: {list with status}
  - Backend API: {list with status}
  - Shared: S1-S3 status

  ### Acceptance Criteria
  (from task detail or Feature YAML)
```

If the task is affected by un-propagated CRs, append:
```
  ### Pending CR Changes
  - CR-{nnn}: {description}
    Pending items: {incomplete checklist items}
```

---

## Step 5: Lock Task

```
1. Update TASKS_FILE:
   - Task overview table: status pending -> active
   - Stats row: update pending/active counts
   - Task detail section: status line pending -> active

2. Git commit in specs repo:
   cd {SPECS}
   git add {VERSION_DIR}/tasks/{platform}.md
   git commit -m "chore: mark T{nn} as in-progress ({platform})"

3. Create execution log:
   log_file = {LOG_DIR}/{date}-task-T{nn}-{platform}.md
   Write frontmatter + Parse/Check phase records
   git add log_file (commit with next specs change)

IMPORTANT: This step MUST complete before proceeding to Step 6.
Purpose: Prevent other sessions from claiming the same task.
```

---

## Step 6: Execute (7-Step Protocol)

Run the task-execution-workflow (see workflows/task-execution-workflow.md):

```
6.1 Parse
    - Confirm target task, read full task detail
    - Identify associated Feature YAML path
    - Read technical design (primary guide for implementation):
      - {VERSION_DIR}/designs/F{nn}-{name}.md (cross-platform design contract)
      - If exists → Worker follows Section 3 ({platform} implementation plan)
        - API contracts in Section 2 are authoritative (must match exactly)
        - Module paths, files to change, UI components defined in Section 3
      - If missing → warn "No technical design, proceeding with Feature YAML only"
        - Worker makes best-effort decisions from Feature YAML + PROJECT.md
        - Higher risk of cross-platform misalignment

6.2 Check
    - Verify all dependencies are still met (may have changed since Step 3)
    - API Contract Verify (mandatory when backend dependencies exist):
      a. Get endpoint list from task detail API table
      b. For Swagger endpoints: resolve path via .context-resolved.yaml:
         {API_DOC}/{service}_swagger.json (absolute path, worktree-safe)
         Fallback: api-doc/{service}_swagger.json (legacy relative path)
         For non-Swagger endpoints: get params from backend.md
      c. Field-by-field verification: request params, response fields, enum values
      d. Discrepancies -> output report, write to task tech notes
      e. During development, Swagger/backend.md is truth, not spec assumptions

6.3 API Contract Verify (merged into Check above)

6.4 Collect
    - Download Figma screenshots via MCP to .claude/cache/{version}/figma/
    - Extract API definitions (full request/response schemas)
    - Read i18n strings from {version}/i18n/strings.md
    - Read analytics definitions from Feature YAML
    - Search project code for related modules, reusable components
    - Identify files that need modification

6.5 Execute
    - Implement feature code following platform coding standards
    - Add i18n strings to platform internationalization files
    - Add analytics tracking code
    - Follow ui_contract (required + forbidden)
    - Follow delivery_contract (stack baseline, data source priority)
    - API params use Swagger/backend.md as truth

6.6 Verify
    - Run build verification: ./scripts/build.sh (or platform build_cmd)
    - Expect: BUILD SUCCEEDED (iOS) / BUILD SUCCESSFUL (Android)
    - On failure:
      1. Analyze error log, locate problematic source file
      2. Fix compilation error (prioritize current-change issues)
      3. Re-run build
      4. 3 consecutive failures -> pause, mark as blocked, append reason
    - Log: standard pass writes "build passed", expand only on anomalies

6.7 Review
    - Self-review: check code quality, edge cases, error handling
    - Verify UI contract compliance (required items present, forbidden items absent)
    - Verify delivery gate compliance (stack baseline, data contract)
    - Max 3 review-fix rounds, then accept or mark issues
```

---

## Step 7: Merge (if applicable)

```
If working in a task-specific worktree (legacy per-task worktree mode):
  1. Switch to version branch: git checkout {version_branch}
  2. Merge task branch: git merge --no-ff {task_branch}
  3. Resolve conflicts if any (see ai/git.md for conflict handling)
  4. Verify build passes on merged code
  5. Cleanup: remove worktree + delete task branch

If working directly in version worktree (standard mode):
  1. Commit code changes to version branch:
     git add {changed_files}
     git commit -m "feat({scope}): {task_description} (T{nn})"
  2. No merge needed -- already on version branch
```

---

## Step 8: Update Status

```
build_succeeded:
  1. Update TASKS_FILE:
     - Task overview table: status active -> done
     - Stats row: update active/done counts
     - Task detail: status line active -> done
  2. Git commit in specs repo:
     cd {SPECS}
     git add {VERSION_DIR}/tasks/{platform}.md
     git commit -m "feat: complete T{nn} - {task_name} ({platform})"
  3. Append completion record to execution log:
     - Verify phase result
     - Friction point summary
     - Outcome section

build_failed_or_interrupted:
  1. Status remains active
  2. Append blocking reason to task detail in TASKS_FILE
  3. Append failure record to execution log
  4. Do NOT mark as done
```

---

## Step 9: Loop

```
After completing or blocking current task:

1. Run Step 2 again (refresh status -- tasks may have been completed by other sessions)
2. Run Step 3 with "next" mode (auto-locate next available task)
3. If next task found -> continue from Step 4
4. If no task available -> output final report and EXIT

Exit conditions:
  - All tasks are done -> "All tasks complete for {platform} v{version}"
  - All remaining tasks are blocked -> output blocking report with reasons
  - 2 consecutive task failures -> pause, suggest human intervention
  - User interruption
```

---

## Status Definitions

| Symbol | Meaning | Transition |
|--------|---------|------------|
| pending | Not started | -> active (Lock) |
| active | In progress | -> done (Update) or remains active (failure) |
| done | Completed | -> rework (CR change) |
| rework | Needs rework | -> active (CR propagation) |
| blocked | Cannot proceed | -> pending (Reset) |

---

## Task Availability Rules

A task is "available" when ALL conditions are met:

1. Status is pending or rework
2. All prerequisite tasks in dependency column are done (or rework)
3. Backend API dependency (B{nn}) is done, or task has no backend dependency
4. No active worktree branch contains this task ID
5. Shared dependencies (S1-S3) are met

---

## Execution Log Requirements

Every task execution MUST produce a log file at:
```
{VERSION_DIR}/_logs/{date}-task-T{nn}-{platform}.md
```

Log format follows `workflows/execution-log.template.md`. Required sections:

- Frontmatter (date, type, scope, executor, result)
- Gate Check (for UI-related tasks)
- Phase records (what was done at each step)
- Friction point summary (for /retro aggregation)
- Outcome (user acceptance result)

---

## Quick Reference

| Argument | Action |
|----------|--------|
| (empty) | Auto-locate next available task, execute, loop |
| `T{nn}` | Execute specific task, then loop |
| `F{nn}` | Map to platform task, execute, loop |
| `status` | Show current status overview, no execution |
| `next` | Same as empty -- auto-locate and execute |
