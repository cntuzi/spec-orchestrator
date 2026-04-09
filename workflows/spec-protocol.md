# Spec Workflow Protocol v2

> Tool-agnostic workflow specification. Any AI tool (Claude Code / Codex / others) can execute the workflow after reading this file.
> Tool-specific operations are implemented by their respective adapter layers (spec-drive.md / AGENTS.md).
>
> v2 changes (2026-03-26):
> - Added `visual-qa` work type for screenshot-driven UI convergence
> - review / fix / visual-qa types gain a `Trigger` phase to record user input
> - All UI-related work types require `Gate Check` recording
> - Added `chain` mechanism to link multi-round iterations on the same module
> - Log requirements gain `Outcome` closure field
> - Verify section deduplication: standard pass is one line, only expand on anomalies

---

## Work Types

| Type | Definition | Phases | Trigger |
|------|-----------|--------|---------|
| **task** | Feature development (T{nn}) | Parse -> Check -> Lock -> Collect -> Execute -> Verify -> Update | /spec-drive T{nn} or manual |
| **sync** | External document sync (PRD/API/Figma) | Collect -> Execute -> Update | Upstream repo has new commits |
| **change** | Change request record (CR-{nnn}) | Detect -> Analyze -> Record -> Propagate | PRD/API/Figma change |
| **review** | Walkthrough/fix | Trigger -> Collect -> Execute -> Verify | Manual trigger (text instruction) |
| **visual-qa** | Screenshot-driven UI convergence | Trigger -> Baseline -> Delta -> Fix -> Verify | User sends screenshot/AB comparison |
| **fix** | Single-point defect fix | Trigger -> Collect -> Execute -> Verify | User feedback / self-check discovery |
| **retro** | Workflow retrospective | Collect -> Analyze -> Report | Periodic or manual /retro |

---

## Phase Definitions

### Common Phase: Trigger (mandatory for review / visual-qa / fix)

> Record user input and intent. This is a critical data source for analyzing upstream process defects.

- **User raw input**: Direct quote or summary of user message (text portion)
- **Attachment description**: Text description of screenshot content (screenshots cannot be stored in logs, but content must be described)
- **Intent interpretation**: Model's understanding of user request
- **Related chain**: If this is a follow-up iteration on the same module, reference the previous log filename
- **Upstream process issues**: Upstream problems inferred from user input (spec missing? gate skipped? baseline not quantified?)

**Why this must be recorded**: Without Trigger data, you cannot answer "why did this module need N rounds to converge".

---

### task Type (full 7 phases)

#### 1. Parse - Identify Target
- **Input**: User instruction ("execute F01" / "execute T01" / "next")
- **Output**: target_task, target_platform, mode (new / cr_propagate)
- **Rules**:
  - F{nn} -> look up config.yaml features to map to T{nn}
  - :green_circle: task -> prompt that it's completed, confirm whether to redo
  - :yellow_circle: task -> prompt that it's in progress, search for existing context

#### 2. Check - Verify Dependencies
- **Input**: target_task
- **Output**: executable / blocking reason
- **Check items**:
  - Shared dependencies (tasks/shared.md: S1-S3)
  - Backend API (tasks/backend.md: B{nn} status)
  - Prerequisite tasks (tasks/{platform}.md: dependency column)
  - API Contract (mandatory when backend dependency exists)
  - UI Contract (mandatory when UI changes are involved)

#### 3. Lock - Lock Task
- **Input**: target_task, platform
- **Output**: tasks/{platform}.md status :red_circle: -> :yellow_circle:
- **Rules**: Immediately git commit to prevent concurrent execution

#### 4. Collect - Gather Context
- **Input**: target_task's associated Feature
- **Output**: Complete context package (PRD + Figma + API + i18n + analytics + existing code)
- **Source priority**:
  - PRD: Markdown (prd repo) > PDF (specs/prd/)
  - Figma: Feature YAML figma.pages[] -> MCP Figma tool
  - API: Feature YAML api[] -> api-doc/*.json
  - i18n: i18n/strings.md
  - Analytics: PRD analytics table + api-doc/tec_docs/analytics spec

#### 5. Execute - Implement
- **Input**: context package + platform code
- **Output**: source file changes
- **Rules**:
  - Add i18n copy simultaneously
  - Add analytics code simultaneously
  - Follow ui_contract (required + forbidden)
  - Follow platform coding standards

#### 6. Verify - Build Verification
- **Input**: modified code
- **Output**: BUILD SUCCEEDED / FAILED
- **Rules**:
  - Failure -> analyze error -> fix -> recompile
  - 3 consecutive failures -> pause, mark as blocked
- **Log rules**: Standard pass writes `build passed`, only expand on new warnings or failure details (do not repeat known environment warnings)

#### 7. Update - Update Status
- **Input**: verification result
- **Output**: tasks/{platform}.md status :yellow_circle: -> :green_circle:, git commit
- **Rules**:
  - Success -> :green_circle: + commit code + commit status
  - Failure -> :yellow_circle: + append blocking reason

---

### visual-qa Type (screenshot-driven UI convergence)

> Covers the most frequent real-world work mode: user sends screenshot -> model compares with Figma -> identifies deviations -> fixes UI.

```
1. Trigger  - Record user screenshot content and feedback (mandatory, format above)
2. Baseline - Determine Figma design baseline (node-id + key pixel values)
3. Delta    - List implementation vs baseline deviations item by item
4. Fix      - Fix code (record decisions only, don't enumerate code changes)
5. Verify   - Build verification (standard pass is one line)
```

**Delta section format**:
```markdown
### Delta
| Area | Figma Baseline | Current Implementation | Deviation | Action |
|------|---------------|----------------------|-----------|--------|
| tag track y position | y=98 | y=112 | +14pt | fix |
| right fade start | 107pt reserved | 91pt | 16pt short | fix |
| selected font | 15/500 | 14/400 | weight mismatch | fix |
```

**Difference from review**: visual-qa must have a screenshot-driven Trigger, and Delta must be a structured deviation table. review can be pure text/code walkthrough.

---

### review Type

```
1. Trigger - Record trigger source and user input (mandatory)
2. Collect - Determine walkthrough scope and design baseline
3. Execute - Fix code
4. Verify  - Build verification
```

### fix Type

```
1. Trigger - Record trigger source and user input (mandatory)
2. Collect - Locate root cause
3. Execute - Fix code
4. Verify  - Build verification
```

### sync Type

```
1. Collect - Check upstream repo for new commits (git log {last_synced}..HEAD)
2. Execute - Propagate changes to specs documents (README/CHANGELOG/tasks)
3. Update  - Record CR + git commit
```

### change Type

```
1. Detect    - Identify change source and scope
2. Analyze   - Expand impact scope via dependency_index (Features -> Tasks -> Backends)
3. Record    - Create CR entry in CHANGELOG.md
4. Propagate - Propagate changes to affected documents and code
```

---

## Chain Mechanism (multi-round iteration linking)

> Multi-round iterations on the same module must be linked via chain; otherwise convergence efficiency cannot be measured.

### Rules

1. **chain_id**: Format is `{feature}-{scope}`, e.g. `f05-home-ui`, `create-channel-tags`
2. **iteration**: Current round number for this chain, starting from 1
3. **Previous reference**: `prev` field in frontmatter points to the previous round's log filename
4. **First round marker**: First round's `prev` is empty

### When it's the same chain

- UI convergence on the same module/page (even across days)
- User's follow-up feedback on the same area
- Multiple fix attempts for the same bug

### When it's a new chain

- Different module/page
- Same module but completely different problem domain (e.g. UI issue vs data issue)

### Example

```yaml
# Round 1
chain: f05-home-ui
iteration: 1
prev: ~

# Round 3
chain: f05-home-ui
iteration: 3
prev: 2026-03-24-review-f05-home-header-comparison.md
```

---

## Gate Check Recording (mandatory for UI-related work)

> All UI-related work (task/review/visual-qa/fix) must record gate status in logs.
> Purpose: Quantify gate enforcement rate to provide data for process optimization.

### Required fields

```markdown
### Gate Check
- Feature YAML: exists / missing
- ui_contract: complete / partial / missing / N/A
- pixel_baseline: quantified / not quantified / N/A
- data_contract: defined / missing / N/A
- Figma baseline image: cached / missing (MCP failure / not downloaded)
- Skip reason: {if any gate failed but execution continued, must explain why}
```

### Gate statistics usage

/retro aggregation can compute:
- Gate pass rate (how many logs have all gates passed)
- Gate skip rate and reason distribution
- Correlation between gate gaps and rework rounds

---

## Log Requirements (mandatory)

### When to write logs
**All** spec-related work executed via AI tools must be logged. Regardless of work type.

### Log location
```
{project}/{version}/_logs/{date}-{type}-{scope}.md
```

Naming examples:
- `2026-03-20-task-T07-ios.md`
- `2026-03-23-sync-prd-api.md`
- `2026-03-23-change-CR-005.md`
- `2026-03-21-review-chat-ui-walkthrough.md`
- `2026-03-26-visual-qa-f05-home-tag.md`
- `2026-03-26-fix-search-highlight-stale.md`

### Log content

**At start**: Create file, write frontmatter + Trigger (if applicable) + execution summary.

**At each phase completion**, append:
- What was actually done
- Deviations from the spec-protocol process (if any)
- Friction or blocking encountered (if any)
- Decisions made and rationale (if any)

**At end**, append:
- Friction point summary (checklist format, for /retro aggregation)
- Outcome (user acceptance result)
- Workflow improvement suggestions (if any)

### Log format

See `workflows/execution-log.template.md`.

### What not to write
- Code-level debug processes (belongs in commit messages)
- CR details already recorded in CHANGELOG (just reference the CR number)
- Technical details unrelated to the workflow
- **Known environment warnings** (SDK path / proto hints etc., record only on first occurrence)
- **Defensive boundary statements about what was NOT changed** (logs focus on what was done, no need to enumerate what wasn't)

### What must be written
- **User raw input** (Trigger phase, mandatory for review/visual-qa/fix)
- **Gate execution status** (Gate Check, mandatory for UI-related work)
- **Chain linking** (mandatory for multi-round iterations on same module)
- **Outcome** (whether user accepted the result)
- **Conflict decisions** (choices and rationale when PRD vs Figma contradict)

---

## Outcome Closure (mandatory)

> Every log must end with an Outcome section to close the feedback loop.

```markdown
## Outcome
- **User acceptance**: passed / not passed / pending
- **Next chain**: {if not passed, next round log filename; if passed, "closed"}
- **Convergence rounds**: {total rounds for this chain, only fill when closed}
```

---

## Quality Gates

| Work Type | Must Satisfy |
|-----------|-------------|
| task | Build passes + status updated in tasks/{platform}.md |
| sync | Changes recorded in CHANGELOG + upstream commit hash annotated |
| change | CR entry created + checklist generated |
| review | Build passes + Trigger recorded |
| visual-qa | Build passes + Trigger recorded + Delta table filled |
| fix | Build passes + Trigger recorded |
| All types | Execution log written + Outcome filled |

---

## External Resource Index

| Resource | Location | Purpose |
|----------|----------|---------|
| Version config | {project}/{ver}/config.yaml | Figma key, feature list, path mappings |
| PRD source | PRD repo (Markdown) | Requirements source |
| PRD index | {project}/{ver}/prd/README.md | Structured requirements summary |
| API docs | api-doc/*.json | Swagger endpoint definitions |
| Tech docs | api-doc/tec_docs/ | Backend design + analytics spec |
| Figma index | {project}/{ver}/figma-index.md | Design page mappings |
| Feature definitions | {project}/{ver}/features/*.yaml | Feature specs |
| Task plans | {project}/{ver}/tasks/{platform}.md | Task status + details |
| Backend dependencies | {project}/{ver}/tasks/backend.md | API readiness status |
| Changelog | {project}/{ver}/CHANGELOG.md | CR records |
| Dashboard | {project}/{ver}/DASHBOARD.md | Aggregated view |
| Execution logs | {project}/{ver}/_logs/ | Workflow observability |
| Retro reports | {project}/{ver}/_retro/ | Improvement insights |
