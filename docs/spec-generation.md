# Spec Generation Workflow

> Standard process for turning new version requirements into executable specs.
> Goal: Generate high enough quality in one pass to minimize patching during execution.

---

## Why This Workflow Exists

Spec execution in early versions revealed the following issues -- all avoidable at generation time:

| Issue Type | Example | Root Cause |
|-----------|---------|-----------|
| Field name mismatch | `user_name` vs Swagger's `username` | Guessed field name from PRD instead of checking Swagger |
| Endpoint model wrong | Assumed WebSocket, actually HTTP POST | Based on early technical discussion, implementation changed |
| Response field missing | `GET /tasks/{id}` lacks `assignee_id` | Assumed API would return needed fields |
| Enum undefined | `status` field values unclear | Did not confirm with Swagger or backend docs |
| Figma page omission | Feature YAML did not reference figma-index pages | YAML and figma-index written independently |
| No defensive flow | No task locking, no API verification | Assumed specs were perfect |

---

## Generation Flow

### Phase 0: Input Materials Checklist

Before starting generation, confirm these materials are ready:

```
[ ] PRD document (PDF / Markdown)
[ ] Figma design file (file_key + page structure)
[ ] Backend technical spec (if available)
[ ] Swagger / API documentation (if available)
[ ] Previous version specs (for structural reference)
```

**Key principle**: For features without API documentation, mark `? pending confirmation` in backend.md rather than assuming.

### Phase 1: Structure Setup

Create the version directory structure:

```
{project}/{version}/
+-- config.yaml          # Version config (Figma key, path mapping)
+-- summary.md           # Version overview
+-- DASHBOARD.md         # Progress dashboard
+-- prd/                 # PRD documents
+-- features/            # Feature YAML
+-- figma-index.md       # Figma page index
+-- i18n/                # Internationalization strings
+-- tasks/               # Task plans
    +-- shared.md
    +-- backend.md
    +-- ios.md
    +-- android.md
```

### Phase 2: Requirement Decomposition -> Feature YAML

Decompose PRD into Feature YAML files.

#### 2.1 PRD Sections -> Feature ID Mapping

Map PRD functional sections to Feature IDs by these rules:

```
Steps:
1. Read through PRD, identify all independent functional units
   (one function = one user-perceivable complete interaction)
2. Group and number by module:
   - Core module: F01-F03
   - Settings module: F04-F05
   - Social module: F06-F08
   - ...
3. For each Feature determine:
   - module: parent module
   - priority: P0 (core) / P1 (important) / P2 (deferrable)
   - dependencies: other Feature IDs it depends on
4. One PRD section may split into multiple Features
   (e.g., "Task Management" splits into List + Create + Detail)
5. Multiple PRD sections may merge into one Feature
   (e.g., "Task Editing" and "Edit Permissions" merge into F03)
```

#### 2.2 Figma Page Extraction

Figma node_id **must be extracted from figma-index.md**, never inferred from PRD:

```
Steps:
1. Read {version}/figma-index.md
2. Traverse each page by section:
   - Identify which Feature the page belongs to (by page name + description)
   - Extract node_id
3. Write into Feature YAML's figma.pages:
   - node_id: "100:200"
     name: Page name (matching figma-index)
     source: figma-index
4. Pages in figma-index that cannot map to any Feature
   -> Record as omission, create new Feature or extend existing one

Note: PRD may mention Figma page names without node_ids. Do not use PRD
names as substitutes for node_ids from figma-index.
```

#### 2.3 API Endpoint Determination

API information has a strict priority order:

```
Steps:
1. For each Feature, determine required API endpoints
2. Search by source priority:
   a. Swagger documentation (api-doc/{service}_swagger.json):
      - Found -> source: swagger, verified: true (if params also match)
   b. Backend technical spec / separate API docs:
      - Found -> source: backend.md#B{nn}, verified: true
   c. Mentioned in PRD but not found in docs:
      - source: pending, verified: false
      - Create corresponding B{nn} entry in backend.md, mark ? pending

3. Absolutely forbidden: infer field names from PRD descriptions
   (e.g., PRD says "task title" -> do NOT assume field name is task_title)

Each api entry must include:
  - endpoint: full path
  - method: HTTP method
  - source: source annotation
  - verified: whether validated
```

#### 2.4 Feature YAML Complete Format

**Every Feature must contain:**

```yaml
id: F01
name: Task List
module: tasks
priority: P0
description: Display all tasks with filtering and sorting

# === Fields below must have explicit sources, no assumptions ===

figma:
  pages:
    - node_id: "100:200"
      name: Page name
      source: figma-index  # Source annotation: figma-index / manual

api:
  - endpoint: /api/tasks
    method: GET
    source: swagger         # Source annotation: swagger / backend.md / pending
    verified: true          # Whether params validated
    params:
      - name: status
        type: string
        required: false
    response_fields:
      - name: tasks
        type: array

i18n:
  keys: [...]
  source: strings.md  # or "pending translation"

analytics:
  events: [...]
```

**The `source` and `verified` fields are critical**: force annotating the provenance of every piece of data, rather than filling from memory.

### Phase 3: API Alignment -- Three-Way Verification

This is the step most often skipped, and the most costly to skip.

```
+--------------------+    +------------------------+    +----------------------------+
|  Feature YAML      |    | Swagger / API docs     |    | Backend tech spec          |
|  (expected API)    |    | (actual API)           |    | (interaction flow)         |
+--------+-----------+    +-----------+------------+    +-------------+--------------+
         |                            |                               |
         +----------------------------+-------------------------------+
                                      v
                          +--------------------+
                          | Alignment Checklist|
                          +--------------------+
```

#### 3.1 Per-Feature Verification Checklist

**For each Feature YAML, execute these checks:**

```
For each Feature YAML:
  For each api entry:
    [ ] endpoint path exists in Swagger or backend.md
      - Swagger endpoint: search in api-doc/{service}_swagger.json
      - Non-Swagger endpoint: find corresponding B{nn} entry in backend.md
      - Not found -> mark as missing, create ? pending entry in backend.md

    [ ] method matches
      - Feature YAML method == Swagger/backend.md method
      - Mismatch -> fix Feature YAML

    [ ] all param names match
      - Compare Feature YAML params vs Swagger parameters field-by-field
      - Name differs (e.g., user_name vs username) -> use Swagger as truth, fix YAML
      - YAML has field but Swagger doesn't -> confirm if optional or doc omission
      - Swagger has required field but YAML doesn't -> add it

    [ ] all response fields (that task logic depends on) exist
      - Extract depended response fields from task technical notes and acceptance criteria
      - Confirm they exist in Swagger response schema
      - Missing -> mark as missing

    [ ] enum values are defined
      - status, type, etc. fields have explicit value mappings
      - Undefined -> mark as pending

    [ ] interaction model is correct
      - HTTP / SSE / WebSocket / long-poll
      - Wrong model -> fix

    [ ] error codes are listed

    Verification passed -> verified: true
    Verification has discrepancies -> fix Feature YAML, annotate warnings
    Verification has gaps -> verified: false, mark as missing
```

#### 3.2 Execution Method

1. Swagger endpoints: auto-compare Feature YAML `api` fields against Swagger JSON
2. Non-Swagger endpoints: manual comparison with backend docs
3. Discrepancies found -> fix Feature YAML and tasks/*.md, not deferred to execution phase

#### 3.3 Output

Annotate verification status on each backend.md entry:

```markdown
| ID | API | Blocks Feature | Status | Verification |
|----|-----|---------------|--------|--------------|
| B01 | GET /api/tasks | F01 | active | verified (2026-03-03) |
| B02 | POST /api/tasks | F02 | active | ? pending -- response schema unconfirmed |
```

### Phase 4: Figma Alignment

#### 4.1 Cross-Check Flow

```
For each section in figma-index.md:
  1. Identify which Feature ID the section corresponds to
     - Based on section title and page names
     - e.g., "Task Views" -> F01 Task List

  2. Find the corresponding Feature YAML
     - Read {version}/features/F{nn}-*.yaml

  3. For each page in the section:
     [ ] page.node_id exists in Feature YAML figma.pages
       - Exists -> pass
       - Missing -> omission, append to Feature YAML:
         - node_id: "{node_id}"
           name: "{page_name}"
           source: figma-index

  4. Reverse check: each node_id in Feature YAML figma.pages
     [ ] has a corresponding entry in figma-index.md
       - Missing -> node_id may be invalid or manually added
       - Annotate source: manual, pending verification
```

#### 4.2 Completeness Check

```
[ ] Every page in figma-index.md is referenced by at least one Feature YAML
[ ] Every node_id in Feature YAML figma.pages has a corresponding figma-index entry
[ ] Omitted pages are filled in with source: figma-index annotation
[ ] Pages that cannot map to any Feature -> record as anomaly, confirm if new Feature needed
```

### Phase 5: Task Generation -> tasks/*.md

Generate platform task files from Feature YAML. **Generation rules:**

1. **Task overview table**: includes Feature column and schedule column
2. **API table**: extracted from Feature YAML `api` field, includes full endpoint path, method, source column
3. **Figma table**: extracted from Feature YAML `figma.pages`, all node_ids from figma-index verification
4. **i18n table**: extracted from Feature YAML `i18n.keys`
5. **Analytics**: extracted from Feature YAML `analytics.events`
6. **Technical notes**: includes all warning/missing marks from Phase 3 alignment
7. **Dependencies**: inferred from Feature YAML `dependencies`, with backend.md cross-references

**tasks/backend.md must include:**
- Complete parameter tables for each endpoint (extracted from Swagger or backend docs, not self-authored)
- Error codes
- Verification status and date

### Phase 6: Readiness Gate

Before specs are marked as "executable," pass these checks:

```
=== Spec Readiness Checklist ===

Structural completeness:
[ ] config.yaml exists with valid figma.file_key
[ ] All Feature YAMLs exist
[ ] figma-index.md exists
[ ] i18n/strings.md exists
[ ] tasks/{ios,android,backend,shared}.md exist
[ ] DASHBOARD.md exists

API alignment:
[ ] Every Feature's api.verified == true, or marked ? pending
[ ] backend.md every entry has verification status column
[ ] No field names without source annotations

Figma coverage:
[ ] figma-index 100% covered by Feature YAMLs
[ ] No invalid node_ids in Feature YAMLs

Task consistency:
[ ] Every Feature has a task entry in corresponding platform tasks/*.md
[ ] Inter-task dependencies have no cycles
[ ] Backend dependencies have corresponding backend.md entries

Process completeness:
[ ] Workflow includes Lock step
[ ] Workflow includes API Contract Verify step
[ ] /spec-next command deployed to platform projects
```

---

## Role Responsibilities

| Role | Responsibility |
|------|---------------|
| **PM** | Provide PRD, Figma, confirm business rules |
| **Backend** | Provide Swagger, tech spec, API docs |
| **Spec Maintainer** | Execute Phase 1-6, ensure alignment |
| **AI Agent** | During execution, API Contract Verify as safety net; write back to specs if gaps found |

---

## Ongoing Maintenance

Specs are not "generate once and done." During the version development cycle:

1. **Backend API changes** -> update backend.md + Feature YAML + tasks/*.md
2. **Design changes** -> update figma-index + Feature YAML
3. **Requirement changes** -> update PRD + Feature YAML + tasks/*.md + DASHBOARD.md
4. **Gaps found during execution** -> API Contract Verify auto-writes back to tasks/*.md technical notes

Every change must sync all referencing files. Updating only one location is not allowed.

---

## Quick Reference

```
New Version Spec Generation:

Phase 0  Materials checklist  -> Confirm all inputs are ready
Phase 1  Structure setup      -> Create directory and skeleton files
Phase 2  Requirement decomp   -> PRD -> Feature YAML (annotate source + verified)
  2.1 PRD sections -> Feature ID mapping
  2.2 Figma pages from figma-index (not inferred from PRD)
  2.3 API endpoints: Swagger first -> backend.md -> pending
Phase 3  API alignment        -> Feature YAML x Swagger/docs three-way verify ***
  3.1 Per-Feature per-API verification checklist
  3.2 Swagger vs non-Swagger endpoint distinction
  3.3 Output: backend.md verification status column
Phase 4  Figma alignment      -> figma-index x Feature YAML cross-coverage
  4.1 Per-section per-page bidirectional check
  4.2 Fill omitted pages + source annotations
Phase 5  Task generation      -> Feature YAML -> tasks/*.md
Phase 6  Readiness gate       -> Readiness Checklist all passed
```

Phase 3 is where early versions hit the most issues. It must be executed thoroughly.
