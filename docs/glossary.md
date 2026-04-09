# Spec System Glossary

> Definitions and relationships of all core terms. Read this to understand the full spec system.

---

## Specification Layer -- What + Constraint (define what to do and how to constrain it)

### Feature YAML

The feature specification file, located at `{project}/{version}/features/F{nn}-{name}.yaml`. A feature's **single authoritative definition**, containing What (what to do) and Constraint (how to constrain it) fields.

**What fields** (can be auto-generated):

| Field | Meaning |
|-------|---------|
| `id` / `name` / `module` / `epic` | Feature identity and grouping |
| `description` | Feature description (sourced from PRD) |
| `requirements` | R01-Rnn requirement items |
| `acceptance_criteria` | AC01-ACnn acceptance criteria, typed as ui / interaction / data |
| `figma.pages[]` | Associated Figma design pages with node_id |
| `api[]` | Associated backend endpoint definitions |
| `analytics[]` | Tracking events (type / stype / frominfo / trigger) |
| `i18n_ref` | Internationalization string reference (points to strings.md) |
| `platform_tasks` | Platform task mapping (ios: T{nn}, android: T{nn}, backend: B{nn}) |
| `dependencies` | Inter-feature dependencies |

**Constraint fields** (require manual or semi-automatic supplement):

| Field | Meaning |
|-------|---------|
| `ui_contract` | UI contract |
| `delivery_contract` | Delivery contract |
| `state_matrix` | State matrix |
| `pixel_baseline` | Pixel baseline |
| `conflict_resolution` | Conflict decisions |
| `verification_evidence` | Acceptance evidence |

**Division of labor**: `/spec-init` auto-generates What fields + Constraint skeleton (marked TODO), humans supplement Constraints by priority.

---

### UI Contract (ui_contract)

Defines a feature's **visual constraint contract**, written in the Feature YAML.

| Sub-field | Meaning | Example |
|-----------|---------|---------|
| `source_nodes` | Figma design node IDs, named by state/scenario | `empty_state: "100:200"` |
| `required` | Required structures/components/interactions | `Custom list cell with checkbox` |
| `forbidden` | Forbidden implementation approaches | `System default UITableViewCell` |
| `key_tokens` | Key visual parameters (size/color/radius) | `cell_height: 64` |
| `visual_blockers` | Visual issues that block acceptance | `List must support pull-to-refresh` |

**Core principle**: Visual is a blocker -- if visual gate check fails, task status must not be marked as done.

---

### Delivery Contract (delivery_contract)

Defines a feature's **tech stack constraints**, written in the Feature YAML.

| Sub-field | Meaning |
|-----------|---------|
| `stack_baseline` | Required tech stack per platform (e.g., iOS: UIKit + DiffableDataSource) |
| `ui_split` | UI implementation layers: L1-Structure -> L2-Visual -> L3-Interaction State -> L4-Acceptance Evidence |
| `data_contract` | Field source priority (e.g., `source_priority: [server, local_cache]`) |

---

### State Matrix (state_matrix)

Exhaustively enumerates a feature's **all key state scenarios** to prevent missing edge cases. Written in the Feature YAML.

Each entry contains:

| Field | Meaning |
|-------|---------|
| `id` | Identifier (S01, S02...) |
| `name` | State name |
| `figma_node` | Corresponding Figma design node ID |
| `trigger` | What action/condition triggers this state |
| `expected` | Expected behavior when entering this state |

**Value**: Each state binds to a Figma node -> locate design during development -> checklist each item during acceptance.

---

### Pixel Baseline (pixel_baseline)

**Quantified dimensions/spacing/tap areas** for key controls, rejecting "close enough by eye." Written in the Feature YAML.

```yaml
pixel_baseline:
  nav:
    bar_height: 44
    back_tap_area: "44x44"
  form:
    horizontal_inset: 16
    section_spacing: 8
```

---

### Conflict Resolution (conflict_resolution)

**Decision records** when PRD vs Figma vs API contradict each other. Written in the Feature YAML.

```yaml
conflict_resolution:
  - key: "Button height"
    figma: "48pt"
    prd: "44pt"
    decided_source: figma
    owner: design
    decision_date: "2026-03-20"
```

---

### Acceptance Criteria (acceptance_criteria)

AC01-ACnn acceptance items, in three types:

| Type | Meaning |
|------|---------|
| `ui` | Visual acceptance (compare against Figma) |
| `interaction` | Interaction acceptance (operation flow) |
| `data` | Data acceptance (API/storage) |

---

### config.yaml

Version configuration hub, located at `{project}/{version}/config.yaml`.

Core sections:

| Section | Meaning |
|---------|---------|
| `version` / `codename` | Version identifier |
| `figma.file_key` | Figma design file key |
| `paths` | Path mapping for all version resources |
| `api.swagger_files` | Backend Swagger file list |
| `features[]` | Feature quick index (id / name / module / priority) |
| `dependency_index` | Reverse index (see below) |

---

### Dependency Index (dependency_index)

**Reverse lookup tables** in config.yaml, used for change impact analysis.

| Sub-index | Direction | Purpose |
|-----------|-----------|---------|
| `api_to_features` | API endpoint -> Feature list | Locate affected features when API changes |
| `figma_to_features` | Figma node -> Feature list | Locate affected features when design changes |
| `feature_to_backend` | Feature -> Backend task list | Locate backend dependencies when feature changes |

---

## Task Layer -- Who + Sequence (define who does it and in what order)

### Task (T{nn})

Platform development task, written in `tasks/ios.md` or `tasks/android.md`. **Single source of truth** -- a task's current status is only read/written here.

Relationship with Feature: F{nn} and T{nn} numbers align (one-to-one). One Feature has one Task per platform.

### Backend (B{nn})

Backend API task, written in `tasks/backend.md`. Numbered independently (not bound to F/T). Acts as a prerequisite dependency for frontend tasks.

### Shared (S1-S3)

Cross-platform prerequisites, written in `tasks/shared.md`:

| ID | Item |
|----|------|
| S1 | PRD confirmed |
| S2 | Design reviewed |
| S3 | API defined |

### Status Lifecycle

```
pending --Lock--> active --Pass--> done
                    |                 |
                    | Fail            | CR change
                    v                 v
                  blocked         rework --Propagate--> active -> done
```

| Status | Meaning |
|--------|---------|
| pending | Not started |
| active | In progress / blocked |
| done | Complete |
| rework | Needs rework (after CR change) |
| n/a | Not applicable |

### Wave

Build a DAG from the task dependency column to plan **parallel execution batches**:

- Wave 1: Tasks with no dependencies, can run in parallel
- Wave 2: Tasks depending on Wave 1
- Blocked: Tasks waiting for backend APIs

### DASHBOARD

Progress dashboard, located at `{project}/{version}/DASHBOARD.md`. **Aggregated** from `tasks/*.md`; Workers do not modify it directly.

---

## Orchestration Layer -- Pipeline (define the pipeline)

### spec-init

Generation layer command. **One-shot generates a complete spec skeleton** from PRD + Figma + Swagger.

Three modes:

| Mode | Command | Purpose |
|------|---------|---------|
| generate | `/spec-init 1.0` | Full generation |
| refresh | `/spec-init 1.0 refresh` | Incremental additions |
| validate | `/spec-init 1.0 validate` | Validate only |

### spec-drive

Orchestration layer command. Task analysis + dependency graph + worktree creation + Worker dispatch + status monitoring.

| Subcommand | Purpose |
|------------|---------|
| `setup` | Check spec completeness -> create version branch |
| `next` | Smart analysis -> worktree -> Worker dispatch |
| `status` | Aggregate cross-platform progress -> update DASHBOARD |
| `change` | Record CR + impact analysis |
| `propagate` | CR code rework |
| `reset` | Reset stuck tasks |
| `verify` | Version branch compilation check |
| `done` | Version completion summary |

### spec-next

Execution layer command (Worker perspective). View all platform task statuses and locate the next available task.

### Worker

An AI agent that **autonomously develops** in a worktree, following the 11-step loop:

```
Config -> Status -> Resolve -> Context -> Lock -> Analyze -> Execute -> Review -> Merge -> Update -> Loop
```

Exit conditions: all tasks complete / all tasks blocked / 2 consecutive failures.

### Worktree

Git worktree for isolated development. One worktree per task, cleaned up after merge.

Branch naming: `feat/{project}/{MMDD}/T{nn}-{name}`

---

## Change Management -- Change (define how to modify)

### CR (Change Record)

Change record, numbered CR-001, CR-002..., recorded in `CHANGELOG.md`.

Each CR contains: change source, impact scope, propagation checklist.

### Propagate

CR propagation flow:

```
CR record -> create worktree -> apply changes only -> build -> review -> merge -> checklist all [x] -> CR complete
```

---

## Execution Observability -- Observability (define how to record)

### Work Types

| Type | Definition |
|------|-----------|
| **task** | Feature development (T{nn}) |
| **sync** | External doc sync (PRD/API/Figma) |
| **change** | Requirement change record (CR-{nnn}) |
| **review** | Code/UI review |
| **visual-qa** | Screenshot-driven UI convergence |
| **fix** | Point defect fix |
| **retro** | Workflow retrospective |

### Execution Logs (_logs/)

Located at `{project}/{version}/_logs/{date}-{type}-{scope}.md`. Every AI work session must write one.

### Chain

**Linking mechanism** for multi-round iterations on the same module.

| Field | Meaning |
|-------|---------|
| `chain_id` | Format `{feature}-{scope}`, e.g., `f01-list-ui` |
| `iteration` | Current round (starting from 1) |
| `prev` | Previous round's log filename |

Purpose: measure "how many rounds this module needed to converge."

### Gate Check

Gate check status record, mandatory for UI-related work:

- Feature YAML: pass/fail
- ui_contract: pass/warning/fail/n-a
- pixel_baseline: pass/fail/n-a
- data_contract: pass/fail/n-a
- Figma baseline screenshot: pass/fail

### Outcome

Log closure. Mandatory at the end of every log:

- User acceptance: pass/fail/pending
- Follow-up chain: next round filename / closed
- Convergence rounds: filled only when closed

---

## Implementation Layer -- How + Why (define how to implement)

### implementation/

Located at `{project}/{version}/implementation/`. Feature YAML defines What; implementation defines **How**.

| File | Meaning | Generated By |
|------|---------|--------------|
| `overview.md` | Version-wide design overview | First Worker |
| `{platform}/tech-plan.md` | Platform-level technical plan | First Worker |
| `F{nn}-{name}/design.md` | Shared design (cross-platform) | Worker Step 6 |
| `F{nn}-{name}/{platform}.md` | Platform-specific design | Worker Step 6 |

---

## External Resources

### figma-index.md

**Page index** of the Figma design file. Grouped by Section, each Page records node_id and purpose.

Located at `{project}/{version}/figma-index.md`, auto-generated by `/spec-init` via Figma MCP.

### i18n/strings.md

**Single authoritative source** for internationalization strings. Grouped by Feature, one key + translations per row.

Feature YAML and Tasks only reference this file; they do not inline keys.

### prd/README.md

**Structured index** of the PRD. Feature list + analytics requirements + key dependencies.

PRD source is preferably read from a dedicated PRD git repository as Markdown, with PDF as fallback.
