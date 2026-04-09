# Task Execution Protocol

> Standard flow for AI agents executing tasks.
> Includes Lock step and API Contract Verify, based on production experience.

---

## Trigger Methods

```
User: execute F01
User: execute T01
User: execute ios/T01
User: execute D1
```

---

## Execution Flow -- 7 Steps

### Step 1: Parse -- Resolve Target

```yaml
steps:
  parse_input:
    - F{nn} -> read {version}/features/F{nn}-*.yaml -> get platform task ID
    - T{nn} -> read {version}/tasks/{platform}.md#T{nn}
    - ios/T{nn} -> read {version}/tasks/ios.md#T{nn}
    - D{n} -> find all tasks with day=D{n}, order by dependency

  pre_check:
    - status done -> prompt "T{nn} already complete, re-execute?"
    - status active -> prompt "T{nn} in progress, continue?" -> search existing code context

output:
  - Target task ID and details
  - Associated Feature YAML path
```

### Step 2: Check -- Verify Dependencies

```yaml
steps:
  1_shared_dependencies:
     - Read {version}/tasks/shared.md, check S1-S3 status
     - Any pending -> report blocking reason

  2_backend_dependencies:
     - Read {version}/tasks/backend.md, check corresponding B{nn} status
     - Status pending -> report blocking reason

  3_feature_dependencies:
     - Check Feature YAML dependencies field
     - Check task detail dependency list
     - Dependency task not complete -> report blocking reason

  4_api_contract_verify:  # mandatory when backend dependencies exist
     a. Get endpoint list from task detail API table
     b. Distinguish endpoint sources:
        - Swagger endpoints
          -> extract schema from api-doc/{service}_swagger.json
        - Non-Swagger endpoints
          -> get param tables from {version}/tasks/backend.md
     c. Availability check:
        - Swagger file does not exist -> warn "backend may not have provided API docs yet"
        - Endpoint not defined -> warn "{endpoint} not defined in Swagger"
        - Does NOT block execution, but write missing info to task technical notes (marked missing)
     d. Field-by-field verification:
        - Request params: field names in tasks/*.md match Swagger/backend.md
        - Response fields: fields that task logic depends on exist
        - Enum values: referenced status enums are defined
     e. Discrepancy handling:
        - Mismatch found -> output discrepancy report (marked warning)
        - Write discrepancies to tasks/*.md task technical notes
        - During development, use Swagger/backend.md as truth, not spec assumptions

output:
  - Executable / Blocked (with reason)
  - API verification report (if discrepancies found)
```

### Step 3: Lock -- Claim the Task

```yaml
steps:
  1. Update {version}/tasks/{platform}.md:
     - Task overview table: status column pending -> active
     - Stats row: update counts
     - Task detail: status line pending -> active
  2. git commit: "chore: mark T{nn} as in-progress"
  3. This step MUST complete before Collect/Execute

purpose:
  - Prevent other sessions from claiming the same task
  - Leave an explicit start timestamp in git history
```

### Step 4: Collect -- Gather Context

```yaml
steps:
  a_prd_details:
     - Read {version}/prd/README.md for the relevant feature section
     - If needed, read original PRD from {version}/prd/

  b_figma_design:
     - Get node_id list from Feature YAML figma.pages (primary source)
     - Cross-check with {version}/figma-index.md (supplementary source):
       - figma-index has page but YAML doesn't reference it -> identify as omission
       - Auto-append to Feature YAML, annotate source: figma-index
       - Output fill log: "+ F01: added 100:200 task-list-empty-state"
     - Get figma.file_key from {version}/config.yaml
     - Download screenshots via Figma MCP to .claude/cache/{version}/figma/

  c_api_endpoints:
     - Get endpoints from Feature YAML api field
     - Distinguish sources:
       - Swagger endpoints -> extract full definition from api-doc/{service}_swagger.json
       - Non-Swagger endpoints -> get param tables, error codes from {version}/tasks/backend.md

  d_i18n_strings:
     - Get feature strings from {version}/i18n/strings.md
     - Note platform format differences (%s -> iOS %@, Android %s)

  e_analytics:
     - Get tracking definitions from Feature YAML analytics field

  f_existing_code:
     - Search project code for related module implementations
     - Identify reusable components/patterns
     - Determine files that need modification

output:
  - Figma screenshot paths
  - API definition text (annotated by source)
  - i18n string list
  - Related code file list
```

### Step 5: Execute -- Implement

```yaml
steps:
  1. Create/modify source files to implement the feature
  2. Add i18n strings to platform internationalization files
  3. Add analytics tracking code
  4. Follow platform coding standards
  5. API params use Swagger/backend.md as truth, not Feature YAML assumptions
```

### Step 6: Verify -- Build Check

```yaml
steps:
  iOS:     ./scripts/build.sh -> expect BUILD SUCCEEDED
  Android: ./scripts/build.sh -> expect BUILD SUCCESSFUL

  build_failure_handling:
    1. Analyze error log, locate problematic source file
    2. Fix compilation error (prioritize issues introduced by current changes)
    3. Re-run build verification
    4. 3 consecutive failures -> pause, prompt user intervention
```

### Step 7: Update -- Record Completion

```yaml
build_succeeded:
  1. Update {version}/tasks/{platform}.md status active -> done
     - Task overview table + stats row + task detail status line
  2. Update {version}/DASHBOARD.md feature progress
  3. git commit: "feat: complete T{nn} - {task_name}"

build_failed_or_interrupted:
  1. Status remains active (in progress)
  2. Append blocking reason to task detail
  3. Do NOT update DASHBOARD.md (only update on build success)
```

---

## State Machine

```
                    Dependencies met + Check passed
+------------+ ---------------------------------> +--------------+
| pending    |                                    | active       |
| not started|                                    | in progress  |
+------------+                                    +------+-------+
     ^                                                   |
     |                                          +--------+--------+
     |                                          |                 |
     | Dependencies                        Verify pass      Verify fail
     | not met                                  |                 |
     |                                          v                 v
+------------+                            +-----------+   +-----------+
| blocked    |<---------------------------| done      |   | blocked   |
+------------+    External dep changed    | complete  |   | (+ reason)|
                                          +-----------+   +-----------+

Lock:   pending -> active + git commit
Update: active -> done + git commit (success) or active remains (failure)
```

---

## Shortcut Commands

| Command | Meaning |
|---------|---------|
| `execute F01` | Execute feature (auto-select current platform) |
| `execute T01` | Execute current platform task |
| `execute ios/T01` | Execute specified platform task |
| `execute D1` | Execute all tasks for specified day |
| `status` | Show current version progress |
| `blocked` | Show all blocked items |
| `next` | Execute next available task |

---

## Example Execution

```
User: execute F01

Agent:
+---------------------------------------------------------------------+
| Step 1: Parse -- Resolve Target                                     |
|    F01 -> Task List -> iOS task T01                                 |
|    Status: pending                                                  |
+---------------------------------------------------------------------+
| Step 2: Check -- Verify Dependencies                                |
|    - S1 PRD confirmed: pass                                         |
|    - S2 Design reviewed: pass                                       |
|    - S3 API defined: pass                                           |
|    - B01 Backend API: active (in progress)                          |
|                                                                     |
|    API Contract Verify:                                             |
|    - GET /api/tasks                                                 |
|      Source: swagger                                                |
|      Params: pass -- status (optional), page, per_page              |
|      Response: pass -- tasks[], total_count                         |
|    - GET /api/tasks/{id}                                            |
|      Source: swagger                                                |
|      Params: pass -- id (path param)                                |
|      Response: pass -- task object with all required fields         |
+---------------------------------------------------------------------+
| Step 3: Lock -- Claim Task                                          |
|    - tasks/ios.md T01: pending -> active                            |
|    - git commit: "chore: mark T01 as in-progress"                   |
+---------------------------------------------------------------------+
| Step 4: Collect -- Gather Context                                   |
|    - Figma: downloaded 3 page screenshots (100:200, 100:300, 100:400)|
|    - API: extracted from swagger todo_swagger.json                  |
|    - i18n: extracted 4 strings from strings.md                      |
|    - Code: found TaskListViewController, TaskCell existing files    |
+---------------------------------------------------------------------+
| Step 5: Execute -- Implement                                        |
|    [implementing code...]                                           |
+---------------------------------------------------------------------+
| Step 6: Verify -- Build Check                                       |
|    - ./scripts/build.sh -> BUILD SUCCEEDED                          |
+---------------------------------------------------------------------+
| Step 7: Update -- Record Completion                                 |
|    - tasks/ios.md T01: active -> done                               |
|    - DASHBOARD.md: F01 iOS complete                                 |
|    - git commit: "feat: complete T01 - Task List"                   |
+---------------------------------------------------------------------+
```
