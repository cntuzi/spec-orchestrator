# Task Execution Workflow -- 7-Step Protocol

> Standard execution flow for AI agents implementing feature tasks.
> Includes Lock step and API Contract Verify, refined from production experience.
> Tool-agnostic: any AI tool can follow this protocol.

---

## Trigger Methods

```
User: execute F01        -> Feature -> resolve to platform task
User: execute T01        -> Direct task reference
User: execute {platform}/T01  -> Explicit platform + task
User: execute D1         -> All tasks scheduled for day D1
Agent: /spec-next        -> Auto-locate next available task
```

---

## Execution Flow

### Step 1: Parse -- Resolve Target

```yaml
steps:
  parse_input:
    - "F{nn}" -> read {version}/features/F{nn}-*.yaml -> get platform task ID
    - "T{nn}" -> read {version}/tasks/{platform}.md#T{nn}
    - "{platform}/T{nn}" -> read {version}/tasks/{platform}.md#T{nn}
    - "D{n}" -> find all tasks with day=D{n}, order by dependency

  pre_check:
    - status done -> prompt "T{nn} already complete, re-execute?"
    - status active -> prompt "T{nn} in progress, continue?" -> search existing code context

  implementation_docs:
    - Read {version}/implementation/overview.md (global context)
    - Read {version}/implementation/{platform}/tech-plan.md (platform approach)
    - Read {version}/implementation/F{nn}-{name}/design.md
      If missing -> generate from Feature YAML + template, commit to specs
    - Generate/update {version}/implementation/F{nn}-{name}/{platform}.md
      If exists -> check if update needed

output:
  - Target task ID and full detail
  - Associated Feature YAML path
  - Implementation design docs (read or generated)
```

### Step 2: Check -- Verify Dependencies

```yaml
steps:
  1_shared_dependencies:
    - Read {version}/tasks/shared.md, check S1-S3 status
    - Any not ready -> report blocking reason

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
       - Does NOT block execution, but write missing info to task tech notes (marked missing)
    d. Field-by-field verification:
       - Request params: field names in tasks/*.md match Swagger/backend.md
       - Response fields: fields that task logic depends on exist
       - Enum values: referenced status enums are defined
    e. Discrepancy handling:
       - Mismatch found -> output discrepancy report (marked warning)
       - Write discrepancies to tasks/*.md task tech notes
       - During development, use Swagger/backend.md as truth, not spec assumptions

  5_ui_contract_verify:  # mandatory when UI changes are involved
    - Check Feature YAML ui_contract exists and is complete
    - Check delivery_contract stack baseline
    - Missing or incomplete -> warn, record in Gate Check

output:
  - Executable / Blocked (with reason)
  - API verification report (if discrepancies found)
  - Gate Check status (for execution log)
```

### Step 3: Lock -- Claim the Task

```yaml
steps:
  1. Update {version}/tasks/{platform}.md:
     - Task overview table: status column pending -> active
     - Stats row: update counts
     - Task detail: status line pending -> active
  2. Git commit in specs repo: "chore: mark T{nn} as in-progress ({platform})"
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
    - Get node_id list from Feature YAML figma.pages[] (primary source)
    - Cross-check with {version}/figma-index.md (supplementary source):
      - figma-index has page but YAML doesn't reference it -> identify as omission
      - Auto-append to Feature YAML, annotate source: figma-index
      - Output fill log: "+ F{nn}: added {node_id} {page-name}"
    - Get figma.file_key from {version}/config.yaml
    - Download screenshots via Figma MCP to .claude/cache/{version}/figma/

  c_api_endpoints:
    - Get endpoints from Feature YAML api field
    - Distinguish sources:
      - Swagger endpoints -> extract full definition from api-doc/{service}_swagger.json
      - Non-Swagger endpoints -> get param tables, error codes from {version}/tasks/backend.md

  d_i18n_strings:
    - Get feature strings from {version}/i18n/strings.md
    - Note platform format differences (e.g. %s -> iOS %@, Android %s)

  e_analytics:
    - Get tracking definitions from Feature YAML analytics field

  f_existing_code:
    - Search project code for related module implementations
    - Identify reusable components/patterns
    - Determine files that need modification

output:
  - Figma screenshot paths
  - API definition text (annotated by source)
  - i18n string list (with platform format notes)
  - Related code file list
```

### Step 5: Execute -- Implement

```yaml
rules:
  1. Create/modify source files to implement the feature
  2. Add i18n strings to platform internationalization files
  3. Add analytics tracking code
  4. Follow platform coding standards (see platform-specific ai/{platform}.md)
  5. API params use Swagger/backend.md as truth, not Feature YAML assumptions
  6. Follow ui_contract: implement required items, avoid forbidden items
  7. Follow delivery_contract: use specified stack baseline, respect data source priority
  8. Follow layered execution order when defined:
     - L1-Structure: layout skeleton, navigation, data binding
     - L2-Visual: styles, spacing, typography, colors
     - L3-Interaction State: all state_matrix scenarios handled
     - L4-Verification Evidence: screenshots, scan results

commit_strategy:
  - Atomic commits: one logical change per commit
  - Format: "{type}({scope}): {description} (T{nn})"
  - Commit after each stable milestone (compiles, feature subset works)
```

### Step 6: Verify -- Build Check

```yaml
steps:
  run_build:
    - Execute platform build command (from .claude/config.yaml or ./scripts/build.sh)
    - Expected result: BUILD SUCCEEDED (iOS) / BUILD SUCCESSFUL (Android)

  build_failure_handling:
    1. Analyze error log, locate problematic source file
    2. Fix compilation error (prioritize issues introduced by current changes)
    3. Re-run build verification
    4. 3 consecutive failures -> pause, mark task as blocked, prompt for intervention

  self_review:
    - Check code quality: naming, structure, error handling
    - Verify UI contract compliance:
      - All required items present
      - No forbidden items used
      - Key tokens match (dimensions, corner radius, etc.)
    - Verify delivery gate compliance:
      - Stack baseline respected
      - Data source priority followed
      - Forbidden alternatives not used
    - Max 3 review-fix rounds

log_rules:
  - Standard pass: write "build passed" (one line)
  - Only expand on failure details or NEW warnings
  - Do not repeat known environment warnings (SDK path hints, proto warnings, etc.)
```

### Step 7: Update -- Record Completion

```yaml
build_succeeded:
  1. Update {version}/tasks/{platform}.md status active -> done
     - Task overview table + stats row + task detail status line
  2. Git commit in specs: "feat: complete T{nn} - {task_name} ({platform})"
  3. Append completion record to execution log:
     - Verify phase result
     - Friction point summary
     - Outcome section (user acceptance: pending)

build_failed_or_interrupted:
  1. Status remains active (in progress)
  2. Append blocking reason to task detail
  3. Append failure record to execution log
  4. Do NOT mark as done
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
     | Reset                               Verify pass      Verify fail
     |                                          |                 |
     |                                          v                 v
+------------+                            +-----------+   +-----------+
| blocked    |<---------------------------| done      |   | blocked   |
+------------+    External dep changed    | complete  |   | (+ reason)|
                                          +-----------+   +-----------+
                                               |
                                               | CR change
                                               v
                                          +-----------+
                                          | rework    |
                                          +-----------+
                                               |
                                               | propagate
                                               v
                                          active -> done

Lock:   pending -> active + git commit
Update: active -> done + git commit (success) or active remains (failure)
```

---

## Gate Check Recording (mandatory for UI-related work)

All UI-related tasks must record gate status in the execution log:

```markdown
### Gate Check
- Feature YAML: exists / missing
- ui_contract: complete / partial / missing / N/A
- pixel_baseline: quantified / not quantified / N/A
- data_contract: defined / missing / N/A
- Figma baseline image: cached / missing (MCP failure / not downloaded)
- Skip reason: {if any gate failed but execution continued, explain why}
```

---

## Execution Log

Every task execution produces a log at:
```
{version}/_logs/{date}-task-T{nn}-{platform}.md
```

Format follows `workflows/execution-log.template.md`. At minimum:
- Frontmatter with metadata
- Gate Check (UI tasks)
- Phase records for each step executed
- Friction point summary
- Outcome closure

---

## Example Execution

```
User: execute F01

Agent:
+---------------------------------------------------------------------+
| Step 1: Parse -- Resolve Target                                     |
|    F01 -> Feature YAML -> iOS task T01                              |
|    Status: pending                                                  |
|    Implementation: design.md exists, {platform}.md needs generation |
+---------------------------------------------------------------------+
| Step 2: Check -- Verify Dependencies                                |
|    - S1 PRD confirmed: pass                                         |
|    - S2 Design reviewed: pass                                       |
|    - S3 API defined: pass                                           |
|    - B01 Backend API: done                                          |
|                                                                     |
|    API Contract Verify:                                             |
|    - GET /api/resource                                              |
|      Source: swagger                                                |
|      Params: pass                                                   |
|      Response: pass                                                 |
+---------------------------------------------------------------------+
| Step 3: Lock -- Claim Task                                          |
|    - tasks/{platform}.md T01: pending -> active                     |
|    - git commit: "chore: mark T01 as in-progress ({platform})"     |
+---------------------------------------------------------------------+
| Step 4: Collect -- Gather Context                                   |
|    - Figma: downloaded 3 page screenshots                           |
|    - API: extracted from swagger {service}_swagger.json             |
|    - i18n: extracted 4 strings from strings.md                      |
|    - Code: found existing related files                             |
+---------------------------------------------------------------------+
| Step 5: Execute -- Implement                                        |
|    [implementing code...]                                           |
+---------------------------------------------------------------------+
| Step 6: Verify -- Build Check                                       |
|    - ./scripts/build.sh -> BUILD SUCCEEDED                          |
|    - UI contract: all required items present, no forbidden items    |
+---------------------------------------------------------------------+
| Step 7: Update -- Record Completion                                 |
|    - tasks/{platform}.md T01: active -> done                        |
|    - git commit: "feat: complete T01 - {task_name} ({platform})"   |
+---------------------------------------------------------------------+
```
