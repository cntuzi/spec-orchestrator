# Work Type Routing & Execution Workflow

> Routes incoming work to the correct execution flow based on type.
> Shared across all platforms -- platform-specific steps are noted where applicable.

---

## Work Type Routing Table

| Type | Trigger | Flow | Log Required |
|------|---------|------|-------------|
| **task** | `/spec-next T{nn}` or auto | Parse -> Check -> Lock -> Collect -> Execute -> Verify -> Update | Yes |
| **visual-qa** | User sends screenshot / AB comparison | Trigger -> Baseline -> Delta -> Fix -> Verify | Yes |
| **fix** | User feedback / self-check discovery | Trigger -> Collect -> Execute -> Verify | Yes |
| **review** | Manual walkthrough instruction | Trigger -> Collect -> Execute -> Verify | Yes |
| **feat** | User describes a feature (no spec task) | Forced flow (see below) | Yes |
| **sync** | Upstream repo has new commits | Collect -> Execute -> Update | Yes |

### How to Determine Work Type

```yaml
if user_input matches "/spec-next" or "execute T{nn}":
  type = task

elif user_input contains screenshot or "looks different from design":
  type = visual-qa

elif user_input describes a bug or "fix this":
  type = fix

elif user_input says "review" or "check" or "walk through":
  type = review

elif user_input describes a new feature or enhancement (not tracked in specs):
  type = feat

elif user_input says "sync" or "update from upstream":
  type = sync

else:
  # Ambiguous -- ask user to clarify, or default to fix if it's a code change request
  ask_user_to_clarify
```

---

## Tool-Specific Routing

Different AI CLI tools have different capabilities. The spec-drive orchestrator uses this routing to decide which tool launches a given work type.

### Routing Matrix

| Work Type | Best Tool | Reason | Fallback |
|-----------|-----------|--------|----------|
| **task** | Codex | Fully autonomous, no interaction needed | Claude Code |
| **fix** | Codex | Code-only, no screenshots or user context required | Claude Code |
| **sync** | Codex | No interaction needed, read upstream + apply changes | Claude Code |
| **visual-qa** | Claude Code | Needs screenshot viewing, image comparison | Cannot run on Codex |
| **review** | Claude Code | Needs user context and interactive confirmation | Cannot run on Codex |
| **feat** | Claude Code | Has two mandatory user confirmation gates | Codex (only if both gates pre-approved) |

### Decision Logic

```yaml
route_to_tool:
  if type in [visual-qa]:
    tool = claude-code  # Hard requirement: needs image viewing
  elif type in [review]:
    tool = claude-code  # Hard requirement: needs user interaction
  elif type in [feat]:
    if confirmation_gates_pre_approved:
      tool = codex      # Can run autonomously if plan is pre-confirmed
    else:
      tool = claude-code
  elif type in [task, fix, sync]:
    tool = codex         # Preferred: fully autonomous
    fallback = claude-code
  else:
    tool = claude-code   # Default to interactive tool for unknown types
```

### Handoff Protocol

When spec-drive (or a human operator) delegates work between tools:

```
1. Orchestrator determines work type and selects tool per routing matrix
2. If tool = Codex:
   a. Claude Code (or human) creates execution log, pre-fills frontmatter + Trigger
   b. Claude Code caches any needed Figma screenshots to .claude/cache/
   c. Codex is launched with: task ID + log file path + any pre-filled context
   d. Codex executes autonomously: Gate Check -> Collect -> Execute -> Verify -> Update
   e. Claude Code (or human) post-fills Outcome after reviewing Codex output
3. If tool = Claude Code:
   a. Claude Code handles the entire lifecycle including Trigger and Outcome
   b. No handoff needed
```

### Pre-Flight Checklist (before Codex launch)

Before delegating to Codex, the orchestrator should ensure:

- [ ] Figma screenshots cached (if UI work): `.claude/cache/{version}/figma/` has relevant node PNGs
- [ ] Execution log created with frontmatter (date, type, scope, chain info)
- [ ] Trigger section filled (if applicable for the work type)
- [ ] Task is available (status = pending, dependencies met, no worktree conflict)
- [ ] API docs are accessible (api-doc path resolves, Swagger files present)

---

## Forced Flow: feat Type

When the work type is `feat` (user-described feature, not a tracked spec task), follow this mandatory flow. Skipping steps is not allowed.

```
Materials -> Requirement Summary (CONFIRM) -> Current State Analysis
         -> Design Resources (if UI involved)
         -> Implementation Plan (CONFIRM) -> Execute -> Verify
```

### Step-by-Step

```yaml
step_1_requirement_summary:
  - Parse user's feature description
  - Present structured requirement list:
    - Numbered requirements (R01, R02, ...)
    - Flag ambiguities with [?]
    - Flag assumptions with [assumed]
  - WAIT for user confirmation
  - User correction -> update -> re-confirm (may iterate)

step_2_current_state_analysis:
  - Search codebase for related modules
  - Simple feature: list affected files + brief impact
  - Complex feature: trace full call chain, document module interactions
  - Output: affected files list + dependency map

step_3_design_resources:
  - If UI changes involved:
    - Check if Figma reference exists
    - Download design screenshots if available
    - If no design: note that implementation will follow code patterns only
  - If pure logic: skip this step

step_4_implementation_plan:
  - Present plan with:
    - File change manifest (new files + modified files)
    - Key design decisions
    - Reuse annotations: mark components/patterns that could be shared
    - Risk areas: parts that might need iteration
  - WAIT for user confirmation
  - User correction -> update -> re-confirm

step_5_execute:
  - Implement following the confirmed plan
  - Build after each logical module (do not accumulate errors)
  - Follow platform coding standards

step_6_verify:
  - Build verification
  - Self-review for quality
```

The key difference from `task` type: `feat` has two mandatory confirmation gates (requirement summary + implementation plan). `task` type has pre-confirmed specs and runs autonomously.

---

## UI Change Gate Check

**Applies to**: task, visual-qa, fix, review -- any work that modifies UI code.

Before executing UI changes, check these gates:

```yaml
gate_check:
  feature_yaml:
    check: Does a Feature YAML exist for this feature?
    values: exists / missing / N/A

  ui_contract:
    check: Is ui_contract defined (required/forbidden/key_tokens)?
    values: complete / partial / missing / N/A

  pixel_baseline:
    check: Are key dimensions quantified (not "looks about right")?
    values: quantified / not quantified / N/A

  data_contract:
    check: Is data_contract defined (field sources, writeback targets)?
    values: defined / missing / N/A

  figma_baseline:
    check: Is Figma baseline screenshot cached locally?
    values: cached / missing (reason)

  skip_reason:
    check: If any gate failed but execution continues, explain why
    values: {reason text} / null
```

### Gate Check Recording

Record gate status in the execution log for every UI-related work:

```markdown
### Gate Check
- Feature YAML: {value}
- ui_contract: {value}
- pixel_baseline: {value}
- data_contract: {value}
- Figma baseline image: {value}
- Skip reason: {value or omit if all passed}
```

### When Gates Fail

```yaml
all_gates_pass:
  -> proceed normally

some_gates_fail:
  -> record which gates failed and why
  -> if ui_contract missing: implement based on Figma screenshots + code patterns
  -> if Figma missing: implement based on requirements text only, flag for visual review
  -> ALWAYS record skip reason in log

critical_gate_fail:
  -> if Feature YAML missing AND no Figma AND no requirements: STOP, ask user for context
```

---

## Execution Log Requirements

**All work types** must produce an execution log. No exceptions.

### Log Location

```
{project}/{version}/_logs/{date}-{type}-{scope}.md
```

### Naming Examples

| Work Type | Example Filename |
|-----------|-----------------|
| task | `2026-03-20-task-T07-ios.md` |
| visual-qa | `2026-03-26-visual-qa-f05-home-tag.md` |
| fix | `2026-03-26-fix-search-highlight-stale.md` |
| review | `2026-03-21-review-chat-ui-walkthrough.md` |
| sync | `2026-03-23-sync-prd-api.md` |
| feat | `2026-03-25-feat-export-pdf.md` |

### Log Timing

```yaml
at_start:
  - Create log file with frontmatter
  - Write Trigger section (mandatory for visual-qa, fix, review)
  - Write Gate Check (mandatory for UI-related work)

at_each_phase:
  - Append: what was done, deviations, friction, decisions

at_end:
  - Append: friction point summary (checklist format, for /retro)
  - Append: Outcome section (user acceptance result)
  - Append: workflow observations (if any)
```

### What to Write

- User raw input (Trigger section, mandatory for review/visual-qa/fix)
- Gate execution status (Gate Check, mandatory for UI-related work)
- Chain linking (mandatory for multi-round iterations on same module)
- Outcome (whether user accepted the result)
- Conflict decisions (choices and rationale when PRD vs Figma contradict)
- Key decisions and their rationale

### What NOT to Write

- Code-level debug processes (belongs in commit messages)
- CR details already recorded in CHANGELOG (just reference CR number)
- Technical details unrelated to the workflow
- Known environment warnings (record only on first occurrence)
- Defensive boundary statements about what was NOT changed

---

## Chain Mechanism (multi-round iteration linking)

When iterating on the same module across multiple rounds:

```yaml
rules:
  chain_id: "{feature}-{scope}"    # e.g. f05-home-ui, create-channel-tags
  iteration: current round number (starting from 1)
  prev: previous round's log filename (empty for first round)

same_chain:
  - UI convergence on same module/page (even across days)
  - Follow-up feedback on same area
  - Multiple fix attempts for same bug

new_chain:
  - Different module/page
  - Same module but completely different problem domain
```

---

## Outcome Closure (mandatory)

Every log must end with:

```markdown
## Outcome
- **User acceptance**: passed / not passed / pending
- **Next chain**: {next round log filename if not passed | "closed" if passed}
- **Convergence rounds**: {total rounds, only fill when closed}
```

---

## Quality Gates by Work Type

| Work Type | Must Satisfy |
|-----------|-------------|
| task | Build passes + status updated in tasks/{platform}.md |
| visual-qa | Build passes + Trigger recorded + Delta table filled |
| fix | Build passes + Trigger recorded |
| review | Build passes + Trigger recorded |
| feat | Build passes + both confirmation gates passed |
| sync | Changes recorded in CHANGELOG + upstream commit hash annotated |
| All types | Execution log written + Outcome filled |
