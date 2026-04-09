---
description: Generate complete spec skeleton from PRD + Figma + API docs — prerequisite for /spec-drive
---

# /spec-init — Version Spec Initialization

User request: $ARGUMENTS

## Role

From PRD + design + API docs, generate a complete spec skeleton (config + features + tasks + CHANGELOG) in one pass, for /spec-drive to take over execution. Optional capabilities (i18n, analytics, dark_mode, etc.) are declared in capabilities.yaml and only generate artifacts when enabled.

---

## Step 1: Parse Arguments

```
$ARGUMENTS parsing:

  ""                    → read .claude/config.yaml version.current, mode = "generate"
  "{version}"           → version = argument, mode = "generate"
  "{version} refresh"   → version = argument, mode = "refresh"
  "{version} validate"  → version = argument, mode = "validate"
  "{version} design"    → version = argument, mode = "design"
  "{version} design F{nn}" → version + specific feature, mode = "design"

mode:
  generate  → full generation (when version directory doesn't exist)
  refresh   → incremental update (version dir exists, fill gaps, don't overwrite)
  validate  → check only, no file changes
  design    → generate/validate technical designs (prerequisite for spec-drive)
```

---

## Step 1.5: Project Bootstrap (existing projects only)

```
Skip if {project}/PROJECT.md already exists and is up-to-date.

For existing projects being onboarded to spec-orchestrator:

1. Check {project}/PROJECT.md exists:
   - Exists → skip this step (project already bootstrapped)
   - Missing → trigger project analysis

2. Resolve platform repos (from .context-resolved.yaml or config hints):
   - ios_repo, android_repo, backend_repo paths

3. For each resolved repo, scan and extract:
   a. Tech stack: language, framework, build system, min SDK
      - iOS: check Podfile/Package.swift, .xcodeproj, Swift version
      - Android: check build.gradle, Kotlin version, compose usage
      - Backend: check go.mod/requirements.txt/pom.xml, framework
   b. Module structure: top-level directory tree (2-3 levels)
   c. Key modules: identify modules relevant to this version's features
      - Match PRD feature names against directory/file names
      - Extract module descriptions from README/comments
   d. Networking: API client, base URL config, request patterns
   e. Navigation: routing pattern, entry points

4. Generate {project}/PROJECT.md:
   Per templates/project.template.md format.
   Fill cross-cutting concerns: feature → module mapping for this version.

5. Output:
   PROJECT.md generated with {N} modules identified across {M} repos.
   This file is version-independent — update when project structure changes.

6. Git commit: "docs: bootstrap project overview for {project}"
```

---

## Step 2: Environment Setup

```
1. Resolve version:
   - Has argument → version = argument
   - No argument → read .claude/config.yaml version.current

2. Read project name:
   - From .claude/config.yaml project.name → {project}

3. Check directory:
   - {project}/{version}/ exists + mode=generate → ❌ "Version dir exists, use refresh"
   - {project}/{version}/ missing + mode=refresh → ❌ "Version dir missing, cannot refresh"
   - {project}/{version}/ missing + mode=validate → ❌ "Version dir missing, cannot validate"
   - {project}/{version}/ missing + mode=generate → create directory structure
   - mode=validate → skip to Step 7 (check only)

3. Resolve external context:

   Run context resolution to locate external repos:
   bash scripts/resolve-context.sh --resolve-repos
   → produces .context-resolved.yaml with absolute paths for repos (api-doc, etc.)
   → if .context-resolved.yaml already exists and is fresh, reuse it

   Read resolved paths:
   - api_doc_path = .context-resolved.yaml repos.api-doc (if resolved)
   - platform repos = .context-resolved.yaml repos.ios / repos.android (if resolved)

4. Collect source paths (auto-discover by priority):

   a. PRD: scan {project}/{version}/prd/*.pdf + *.md
      - Has README.md → prd_source = "{project}/{version}/prd/README.md"
      - Has PDF no README → prd_source = PDF path (use Read tool)
      - None → prompt user to place PRD file in {project}/{version}/prd/

   b. Figma: check source
      - {project}/{version}/config.yaml already has figma.file_key → use it
      - User provides Figma URL or file_key → record figma_file_key
      - None → prompt input (can skip, fill later)

   c. API docs: use resolved api_doc_path from .context-resolved.yaml
      - api_doc_path resolved → scan {api_doc_path}/*_swagger.json
      - Found → record swagger_files[] (repo_id: api-doc, relative paths within repo)
      - api_doc_path not resolved → scan local api-doc/ as fallback
      - None → mark api_source = "pending"

   d. Capabilities: read context.yaml capabilities section (version-level)
      - If not found → use defaults (analytics enabled, others disabled)
      - Record enabled capability set for Steps 6-7
      - See templates/capabilities.template.yaml for available capabilities

   e. Platform repos: use resolved paths from .context-resolved.yaml
      - Record base_commit for each platform: git -C {resolved_path} rev-parse HEAD

5. Output source inventory:

   ## v{version} Initialization Sources

   | Source | Repo ID | Path | Status | Pin |
   |--------|---------|------|--------|-----|
   | PRD | local | {prd_source} | ✅ / ❌ missing | - |
   | Figma | figma | {figma_file_key} | ✅ / ⚠️ pending | - |
   | Swagger | api-doc | {swagger_files} | ✅ / ⚠️ pending | {commit} |
   | iOS repo | ios | {ios_path} | ✅ / ⚠️ pending | {commit} |
   | Android repo | android | {android_path} | ✅ / ⚠️ pending | {commit} |
   | Capabilities | local | capabilities.yaml | {enabled list} | - |

6. Confirm to continue (PRD is required, others can be filled later)
```

---

## Step 3: PRD Parsing → Feature Extraction

```
1. Read PRD file:
   - PDF → use Read tool
   - Markdown (README.md) → read directly

2. Extract structure:
   a. Version metadata: version number, codename, cycle, test date
   b. Epic structure:
      - Epic name + number
      - Feature list per Epic
      - Each feature: name, description, priority, effort, complexity
   c. Feature details:
      - Interaction description (entry, flow, error handling)
      - Business rules
      - Data processing logic
   d. Analytics requirements: type/stype/frominfo/trigger table
   e. Key dependencies: backend APIs, design, other teams

3. Generate feature mapping table:

   | F{nn} | Name | Epic | Module | Priority | Effort | Backend | UI Weight |
   |-------|------|------|--------|----------|--------|---------|-----------|
   | F01 | ... | 1 | ... | P0 | 0.5d | - | heavy |
   | F02 | ... | 1 | ... | P0 | 1.5d | B01 | light |
   ...

   Module inference rules:
   - Derive module from Epic content / feature functionality
   - Use short, lowercase, kebab-case names
   - Examples: chat, settings, profile, feed, search, auth, notification

   UI weight inference rules (ui_weight):
   - Has Figma design + modal/panel/new page/complex interaction → heavy
   - Has Figma design + list items/text changes/simple state → light
   - No Figma design / pure backend / pure analytics / pure config → logic-only

4. Confirm feature list (output for user review):
   - Feature count, ID assignment, module grouping
   - Backend dependency mapping
   - Inter-feature dependencies
   - UI weight labels (heavy / light / logic-only)
```

---

## Step 4: Figma Index Building

```
Prerequisite: figma_file_key provided (otherwise skip, mark ⚠️ pending)

1. Query Figma file structure:
   mcp__figma-developer__get_figma_data(fileKey=figma_file_key, depth=2)
   → get Section/Page list

2. Build figma-index.md:
   Per templates/figma-index.template.md format:
   - Basic info (file name, file key, version, date)
   - Group by Section
   - Each Page: number, name, Node ID, inferred usage
   - Statistics table

3. Map Figma Page → Feature:
   - Fuzzy match page names with feature names
   - Extract node-id from PRD Figma reference links
   - Output mapping table for manual confirmation

4. Populate each Feature's figma.pages[]:
   - node_id: from Figma query result
   - usage: inferred from PRD
   - source: figma-index

5. Output:
   figma-index.md generated, {N} pages mapped to {M} Features
```

---

## Step 5: API Parsing + Backend Task Generation

```
Prerequisite: swagger_files[] provided (otherwise skip, mark pending)

1. Parse Swagger JSON:
   For each swagger file:
   - Extract endpoints: path, method, parameters, response schema
   - Extract models: field names, types, constraints

2. Match Feature → API:
   - Match PRD-mentioned endpoints to Swagger endpoints
   - Infer required API operations from feature descriptions
   - Generate Feature.api[] section:
     endpoint, method, source (swagger:{file}), verified: false
     params[] (from Swagger)
     response_fields[] (from Swagger)

3. Generate backend.md:
   - With Swagger → extract detailed params, responses, error codes
   - Only mentioned in PRD → mark source: "pending", generate skeleton
   - B{nn} numbering: assign in feature dependency order
   - Timeline table: fill from PRD key dependency table

4. If technical design doc exists:
   - Read supplementary API info (non-Swagger protocols etc.)
   - Mark source: "backend.md#B{nn}"
```

---

## Step 5.5: Backend Code Scan (when no Swagger)

```
Skip if swagger_files[] were found in Step 5.

When Swagger is unavailable but backend repo is resolved (from .context-resolved.yaml):

1. Detect backend framework:
   - Go: check go.mod for framework (go-zero, gin, echo, fiber)
   - Python: check requirements.txt (FastAPI, Django, Flask)
   - Java: check pom.xml/build.gradle (Spring Boot)
   - Node: check package.json (Express, Nest)

2. Locate route/handler files:
   Framework-specific discovery:
   - go-zero: gateway/internal/handler/routes.go
   - gin: router.go or routes.go
   - FastAPI: main.py or routers/
   - Spring: @RequestMapping annotations
   - Express: app.use() / router.* calls

3. Extract existing endpoints:
   For each route found:
   - HTTP method + path
   - Handler function name → locate handler file → read logic
   - Request/response types (from type definitions or handler params)

4. Match Feature → existing endpoint:
   For each PRD feature:
   - Fuzzy match feature keywords against endpoint paths
     (e.g., F01 "签到" → /task/activity_sign_in, /task/get_sign_in_info)
   - For matched endpoints: mark source as "backend:{handler_file_path}"
   - For unmatched features: mark source as "TBD (not found in codebase)"

5. Extract business logic constants:
   Search for reward values, limits, thresholds, cutoff dates
   in handler logic and config files — these inform whether
   the backend change is "new API" vs "modify constants".

6. Update Feature YAML api[] with findings:
   - endpoint: actual path from routes
   - source: "backend:{file_path}" (verified: true)
   - params/response_fields: from type definitions
   - usage: inferred from handler logic

7. Classify backend work:
   For each B{nn} in backend.md:
   - "modify_constants": endpoint exists, change values only
   - "modify_structure": endpoint exists, change request/response shape
   - "new_endpoint": no matching endpoint found
   - "new_field": endpoint exists, need to add fields to response

8. Output:
   Backend scan: {N} existing endpoints matched to {M} features
   {K} features have no matching backend endpoint (truly TBD)
```

---

## Step 6: Full Generation

```
Generate in this order (has dependencies):

━━━ 6.1 prd/README.md ━━━

If already exists (PRD came from this file) → skip
If PRD came from PDF → generate structured index:
  - Basic info table (version/codename/cycle/dates)
  - Version overview
  - Feature list (grouped by Epic)
  - Analytics requirements summary
  - Key dependency table

━━━ 6.2 config.yaml ━━━

  version: "{version}"
  codename: "{from PRD}"

  figma:
    file_key: "{figma_file_key}"
    base_url: "https://www.figma.com/design/{figma_file_key}"

  paths:
    prd: "prd/"
    figma_index: "figma-index.md"
    i18n: "i18n/strings.md"
    features: "features/"
    dashboard: "DASHBOARD.md"
    changelog: "CHANGELOG.md"
    tasks:
      shared: "tasks/shared.md"
      backend: "tasks/backend.md"
      ios: "tasks/ios.md"
      android: "tasks/android.md"

  api:
    swagger_files: [{swagger_files}]
    tech_doc: "{tech_doc_path if available}"

  features:  # quick index
    - id: F{nn}
      name: {name}
      module: {module}
      priority: P{n}
      ui_weight: heavy/light/logic-only
    ...

  dependency_index:
    api_to_features:    # reverse-build from Feature.api[].endpoint
    figma_to_features:  # reverse-build from Feature.figma.pages[].node_id
    feature_to_backend: # build from Feature.platform_tasks.backend

━━━ 6.3 features/F{nn}-{name}.yaml × N (mandatory full generation) ━━━

⚠️ IMPORTANT: must generate YAML for every feature. No skipping.
Feature YAML is the Worker's single information entry point.

Per templates/feature.template.yaml complete schema, generate one YAML per feature.

✅ Auto-fill (all features):
  - id, name, module, epic, priority
  - ui_weight: heavy/light/logic-only (Step 3 result)
  - prd_ref: "{PRD file}#{section}"
  - description: PRD original description
  - requirements: R01-Rnn (from PRD key points)
  - acceptance_criteria: AC01-ACnn (derived from requirements)
  - figma.pages[] (Step 4 result)
  - api[] (Step 5/5.5 result, verified: true/false)
  - capabilities: [list of enabled capabilities this feature uses]
    Only include capabilities that are both:
    a. enabled in context.yaml (version-level)
    b. relevant to this feature (e.g., logic-only features skip dark_mode)
  - Capability-specific fields (only for listed capabilities):
    - analytics[] — if analytics in capabilities list
    - i18n_ref + i18n_keys — if i18n in capabilities list
    - (other capability fields per capabilities.template.yaml definitions)
  - platform_tasks: ios: T{nn}, android: T{nn}, backend: B{nn}/null
  - dependencies: (from PRD dependency relationships)
  - status: pending

⚠️ Constraint fields — tiered by ui_weight:

  heavy (modals/panels/new pages/complex interactions):
  - ui_contract: auto-fill source_nodes, mark required/forbidden/key_tokens as "⚠️ TODO"
  - state_matrix: derive from PRD, auto-match figma_node
  - pixel_baseline: "⚠️ TODO: measure from Figma"
  - delivery_contract: stack_baseline "⚠️ TODO"
  - verification_evidence: template path

  light (lists/text/simple state):
  - state_matrix: derive from PRD, auto-match figma_node
  - Others: omit

  logic-only (pure backend/analytics/config):
  - All constraint fields: omit

Feature filename: F{nn}-{kebab-name}.yaml

━━━ 6.4 tasks/shared.md ━━━

  # {version} Shared Prerequisites
  ## Dependency Check
  | ID | Item | Status | Notes |
  | S1 | PRD Confirmed | 🔴 | |
  | S2 | Design Reviewed | 🔴 | |
  | S3 | API Defined | 🔴 | |

  ## Backend API Interaction Patterns
  ## Error Codes
  ## Swagger File Index

━━━ 6.5 tasks/backend.md ━━━

  ## Metadata
  ## API Readiness Timeline
  | ID | API | Blocking Feature | Required By | Status |
  ...
  ## B{nn}: {API Name}
  (Endpoint details, parameter table, response format from Swagger/docs)

━━━ 6.6 tasks/ios.md ━━━

Per templates/task-plan.template.md format.
Scatter each task's details from Feature YAML:
  - Requirements, Figma pages, UI contract, delivery contract
  - API table, i18n reference, analytics
  - L1-L4 execution checklist, acceptance criteria
  - Visual acceptance, verification evidence, dependencies

━━━ 6.7 tasks/android.md ━━━

Mirror iOS structure, replace platform info.

━━━ 6.8 Capability Artifacts ━━━

  Read capabilities.yaml (or context.yaml capabilities section).
  For each enabled capability, run its init-phase actions:

  i18n (if enabled):
    Generate i18n/strings.md:
      # {project} {version} Internationalization
      ## F{nn}: {name}
      | key | primary_lang | ... |
    Add i18n_ref to each Feature YAML.

  analytics (if enabled):
    Extract analytics events from PRD → add analytics[] to Feature YAMLs.

  dark_mode (if enabled):
    Add dark mode state entries to state_matrix for UI features.

  Other capabilities: run their phases.init actions as declared.

  If no capabilities.yaml exists → default: analytics enabled only.

━━━ 6.9 CHANGELOG.md ━━━

  # {version} Change Log
  (Empty — initial version)

━━━ 6.10 figma-index.md ━━━

Step 4 already generated. If skipped → create empty template.

━━━ 6.11 context.yaml (Context Manifest) ━━━

Per templates/context.template.yaml, generate with actual values from Steps 2-5:

  sources:
    prd:
      type: local
      description: "{project} PRD"
      artifacts:
        - prd/README.md              # or prd/{filename}.pdf

    api_doc:
      type: git-repo
      description: "Backend API documentation"
      repo_id: api-doc
      artifacts: [{swagger_files — relative paths within api-doc repo}]
      pin:
        commit: {api_doc_commit from Step 2.3}
        date: {today}

    figma:
      type: figma
      description: "UI Design"
      file_key: "{figma_file_key}"
      cache_dir: figma/
      pin:
        last_sync: {now if cache exists, else empty}
        node_count: {count from Step 4, else 0}

    platforms:
      ios:
        type: git-repo
        description: "{project} iOS client"
        repo_id: ios
        pin:
          branch: {current branch of ios repo}
          base_commit: {ios_commit from Step 2.3}
      android:
        type: git-repo
        description: "{project} Android client"
        repo_id: android
        pin:
          branch: {current branch of android repo}
          base_commit: {android_commit from Step 2.3}

  drift_policy: warn

Pin values come from .context-resolved.yaml (generated in Step 2.3).
If a repo was not resolved, omit the pin section and mark as pending.

━━━ 6.12 implementation/ directory skeleton ━━━

  {project}/{version}/implementation/
  ├── ios/.gitkeep
  └── android/.gitkeep

━━━ 6.13 Update .claude/config.yaml ━━━

  version.current → {version} (only when {version} > current)
```

---

## Step 7: Validation + Report

```
1. Cross-validation:
   a. Feature ID continuity: F01-F{N} (gaps allowed after scope-change, warn only)
   b. Task ID consistency: every F{nn} has T{nn} in ios.md and android.md
   c. Backend mapping: Feature.platform_tasks.backend matches backend.md B{nn}
   d. Capability artifacts: for each enabled capability, validate its init outputs
      - i18n (if enabled): Feature.i18n_ref anchors exist in strings.md
      - analytics (if enabled): Feature.analytics[] not empty for non-logic-only features
   e. Figma references: Feature.figma.pages[].node_id in figma-index.md (warn only)
   f. API references: Feature.api[].endpoint in Swagger or backend.md (warn only)
   g. No circular dependencies: Feature.dependencies has no cycles
   h. dependency_index complete: all mappings covered
   i. Context manifest: context.yaml exists with all sources declared
   j. Context pins: all repo_id sources have non-empty pin.commit (warn only)

2. Generate report:

   ## v{version} Spec Init Report

   ### Generation Statistics
   | Type | Count |
   |------|-------|
   | Feature YAML | {N} |
   | Platform Tasks | iOS {N} + Android {N} |
   | Backend APIs | {M} |
   | Capabilities | {enabled list} |
   | Figma Pages | {P} |

   ### Context Manifest
   | Source | Repo ID | Pin | Status |
   |--------|---------|-----|--------|
   | PRD | local | - | ✅ |
   | API docs | api-doc | {commit} | ✅ / ⚠️ pending |
   | Figma | figma | {last_sync} | ✅ / ⚠️ pending |
   | iOS repo | ios | {commit} | ✅ / ⚠️ pending |
   | Android repo | android | {commit} | ✅ / ⚠️ pending |

   ### Constraint Completion (heavy + light only)
   | Field | Applicable | ✅ Filled | ⚠️ Pending |
   |-------|-----------|-----------|------------|
   | UI Contract | heavy ({H}) | {n}/{H} | {m}/{H} |
   | Pixel Baseline | heavy ({H}) | 0/{H} | {H} |
   | State Matrix | heavy+light | {n} | {m} |
   | Delivery Contract | heavy ({H}) | 0/{H} | {H} |

   ### ⚠️ Manual Completion Needed (by priority)
   1. P0 — heavy feature Constraints
   2. P1 — light feature state_matrix confirmation
   3. P2 — API field-by-field verification

   ### Next Steps
   1. (Optional) Manual constraint completion for heavy features
   2. `/spec-drive setup` → Create version branches
   3. `/spec-drive next` → Start execution

3. Git commit (generate/refresh mode):
   "docs: init {project}/{version} spec structure ({N} features, {M} tasks)"
```

---

## refresh Mode

```
/spec-init {version} refresh

1. Scan {project}/{version}/ existing files
2. Re-collect sources (Step 2)
3. Re-parse PRD (Step 3):
   - New features → create YAML + append Task
   - Existing features → skip (don't overwrite)
4. Fill missing files
5. Existing Feature YAML missing fields → fill (don't overwrite filled content)
6. Rebuild dependency_index (full recalculation)
7. Run Step 7 validation
8. Output diff report
9. Git commit: "docs: refresh {project}/{version} spec (+{N} features)"
```

---

## validate Mode

```
/spec-init {version} validate

1. Run all Step 7 cross-validations
2. Output validation report (pass/fail/warn)
3. No file modifications
```

---

## constraint Mode

```
/spec-init {version} constraint

Semi-auto fill Constraint fields for ui_weight=heavy features.
Run after generate, before spec-drive setup.

1. Read config.yaml features[], filter ui_weight=heavy
2. For each heavy Feature:
   a. Read existing YAML file
   b. Read figma-index.md, match source_nodes by name/feature
   c. If Figma MCP available:
      - Query node details, extract dimensions/colors/radii
      - Generate pixel_baseline skeleton
      - Derive required components from structure
   d. If no Figma MCP:
      - Derive source_nodes from figma-index page names
      - pixel_baseline marked "⚠️ TODO"
   e. Fill state_matrix.figma_node
   f. Generate ui_contract skeleton
3. Output completion report
4. After confirmation → git commit
```

---

## design Mode

```
/spec-init {version} design [F{nn}]

Generate or validate technical designs. Prerequisite for /spec-drive.
Technical designs are the cross-platform contract that Workers must follow.

Without F{nn}: generate designs for ALL features without existing design docs.
With F{nn}:    generate design for specific feature only.

=== Input Sources (priority order) ===

1. External design doc (highest priority):
   If {project}/{version}/designs/F{nn}-{name}.md already exists
   → validate structure, skip generation, mark as "external"

2. External resource reference:
   If Feature YAML has external_design field:
     external_design: "https://docs.google.com/..." or "../docs/tech-design-F01.md"
   → import and convert to standard format

3. Auto-generate from context:
   Feature YAML + PROJECT.md + backend.md + Backend Code Scan results
   → generate design skeleton with best-effort fill

=== Execution Flow ===

1. Determine target features:
   - No F{nn} → all features in config.yaml without design doc
   - F{nn} → single feature

2. For each target feature:

   a. Check {project}/{version}/designs/F{nn}-{name}.md exists:
      - Exists → validate structure, output status, skip generation
      - Missing → continue to generation

   b. Read context:
      - Feature YAML (requirements, API, state_matrix, capabilities)
      - PROJECT.md (platform modules, tech stack, networking patterns)
      - backend.md (existing API contracts, change type)
      - Backend Code Scan results (if available from Step 5.5)

   c. Generate design doc per templates/design-contract.template.md:

      Section 2 (API 契约 — cross-platform alignment):
      - From Feature YAML api[] → list endpoints with full request/response
      - From backend.md → existing params, response fields, error codes
      - From Backend Code Scan → actual type definitions, constants
      - Generate shared data models and status enums
      - Generate business rules (field validation, boundary conditions)

      Section 3 (各端实现方案):
      - From PROJECT.md → identify key modules per platform
      - From Feature YAML → determine what to change
      - iOS: module path, files to change, UI components, API client pattern
      - Android: module path, files to change, UI components, API client pattern
      - Backend: change type, key files, DB changes

      Section 4-5 (决策 + 风险):
      - Auto-infer from complexity and dependencies

   d. Write to {project}/{version}/designs/F{nn}-{name}.md

3. Cross-feature alignment check:
   - Multiple features sharing same API endpoint → verify consistent params
   - Multiple features modifying same module → flag potential conflicts
   - Dependencies between features → verify execution order is safe

4. Output design summary:

   ## v{version} Technical Designs

   | Feature | Status | Source | API Contracts | Platform Coverage |
   |---------|--------|--------|---------------|-------------------|
   | F01 | ✅ generated | auto | 4 endpoints | iOS + Android + Backend |
   | F03 | ✅ external | imported | 0 (no API) | iOS + Android |
   | F05 | ⚠️ incomplete | auto | 1 endpoint (B03 TBD) | iOS + Android + Backend |

   ### Cross-Platform Alignment Issues
   - (list any conflicts or inconsistencies found)

   ### Next Steps
   1. Review and approve designs
   2. /spec-drive setup → create version branches
   3. /spec-drive next → Workers execute per approved designs

5. Git commit: "docs: generate technical designs for {features}"

=== Integration with spec-drive ===

spec-drive Phase 1 checks design doc existence:
  For each task in exec_list:
    {project}/{version}/designs/F{nn}-{name}.md must exist
    If missing → warn "No technical design for F{nn}. Run /spec-init design first."
    If status != approved → warn "Design not approved, Worker may deviate."

spec-next (Worker) reads design doc in Step 6.1:
  Read designs/F{nn}-{name}.md → follow Section 3 for platform-specific plan
  Worker does NOT generate its own design; it implements the approved one.
```

---

## scope-change Mode

```
/spec-init {version} scope-change "<description>"

Cascade a pre-development scope change across all spec files.
Use when PRD changes features BEFORE development starts (post-init, pre-drive).
For changes DURING development, use /spec-drive change instead.

Examples:
  /spec-init 1.30.0 scope-change "remove F04, F01 change to logic-only"
  /spec-init 1.30.0 scope-change "add F08 push notification"

1. Parse change description:
   - Identify actions: remove F{nn} / add F{nn} / modify F{nn} / change ui_weight
   - Confirm with user before proceeding

2. For each "remove F{nn}":
   a. Delete features/F{nn}-{name}.yaml
   b. Remove F{nn} from config.yaml features[] list
   c. Remove F{nn} entries from config.yaml dependency_index
   d. Remove T{nn} from tasks/ios.md and tasks/android.md (overview + detail)
   e. Remove corresponding B{nn} from tasks/backend.md (if F{nn} had backend dep)
   f. Update task stats rows
   g. Add comment: "# F{nn} removed — {reason}"
   Note: Do NOT renumber remaining F{nn}/T{nn}. Gaps are allowed.

3. For each "modify F{nn}" (e.g., change ui_weight):
   a. Update features/F{nn}-{name}.yaml (fields specified)
   b. Update config.yaml features[] entry
   c. If ui_weight changed to logic-only:
      - Remove figma/ui_contract/pixel_baseline sections from Feature YAML
      - Update task descriptions to note "logic-only, no UI changes"

4. For each "add F{nn}":
   a. Assign next available F{nn} number (fill gaps or append)
   b. Generate new Feature YAML from PRD description
   c. Add to config.yaml features[]
   d. Add T{nn} to tasks/ios.md and tasks/android.md
   e. Add B{nn} to backend.md if backend dependency needed

5. Record in CHANGELOG.md:
   ## [SCOPE] {date} — {description}
   - Actions taken (removed/modified/added)
   - Files changed

6. Git commit: "docs: scope change — {description}"
```

---

## Key Conventions

### File Naming

- Feature YAML: `F{nn}-{kebab-name}.yaml` (nn from 01, two-digit zero-padded)
- Task ID: `T{nn}` (maps 1:1 with F{nn}, same number)
- Backend ID: `B{nn}` (only features with backend dependency, independent numbering)
- Version directory: `{project}/{version}/`

### F{nn} → T{nn} → B{nn} Mapping

```
F01 → T01 (iOS + Android), backend: null
F02 → T02 (iOS + Android), backend: B01
F03 → T03 (iOS + Android), backend: B02
...
```

- F{nn} and T{nn} have matching numbers (1:1)
- B{nn} assigned on-demand, numbering independent from F/T
- Features without backend dependency get no B{nn}

### Auto vs Manual (tiered by ui_weight)

| Field | Auto | Manual | Applicable |
|-------|:----:|:------:|:----------:|
| id/name/module/epic | ✅ | - | all |
| ui_weight | ✅ | confirm | all |
| description/requirements | ✅ | - | all |
| acceptance_criteria | ✅ | confirm | all |
| figma.pages | ✅ | confirm | heavy + light |
| api | ✅ | ✅ verify | with API |
| analytics | ✅ | - | capability enabled |
| i18n_ref | ✅ | ✅ translate | capability enabled |
| state_matrix | ✅ | confirm | heavy + light |
| ui_contract | ⚠️ skeleton | ✅ fill | heavy |
| pixel_baseline | ❌ | ✅ measure | heavy |
| delivery_contract | ⚠️ skeleton | ✅ analyze | heavy |

### Integration with spec-drive

```
/spec-init {version}              → generate spec skeleton + all Feature YAMLs
  ↓
/spec-init {version} constraint   → semi-auto fill heavy Constraints (optional)
  ↓
/spec-init {version} design       → generate/import technical designs (recommended)
  ↓                                  cross-platform API contract + 各端实现方案
  ↓                                  可外部导入: 技术负责人直接放 designs/F{nn}.md
  ↓
/spec-drive setup                  → create version branches
/spec-drive next                   → Workers execute per approved designs
```

spec-drive setup checks spec-init output completeness:
- {project}/{version}/ directory exists
- config.yaml exists with features[] and ui_weight
- features/ has a corresponding YAML for every Feature in config.yaml
- tasks/ios.md + android.md exist
- ⚠️ Warning (non-blocking): heavy features missing ui_contract / pixel_baseline
