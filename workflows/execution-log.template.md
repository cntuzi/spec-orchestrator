# Execution Log Template v2

> Copy this template to `{project}/{version}/_logs/{date}-{type}-{scope}.md` and fill in content.
> Reference: `workflows/spec-protocol.md` v2 log requirements.
>
> v2 changes (2026-03-26):
> - Added Trigger section, Gate Check section, Outcome section
> - Frontmatter gains chain / iteration / prev fields
> - type expanded to: task | sync | change | review | visual-qa | fix
> - Added visual-qa dedicated template variant
> - Verify section changed to only expand on anomalies

---

## General Template (task / sync / change / review / fix)

```markdown
---
date: {YYYY-MM-DD}
type: task | sync | change | review | fix
scope: {T07-ios | prd-api | CR-005 | chat-ui-walkthrough | search-highlight-stale}
executor: claude-code | codex | human
duration: ~{N}min
result: completed | blocked | partial
chain: {module identifier, e.g. f05-home-ui. Delete this line if not applicable}
iteration: {current chain round number. Delete this line if no chain}
prev: {previous round log filename. Delete this line if first round or no chain}
---

# {type}: {scope}

## Trigger

> Mandatory for review / fix types. Delete this section for task / sync / change.

- **Source**: user screenshot comparison / user text feedback / self-check discovery / spec task-driven
- **User raw input**: {direct quote or summary of user message}
- **Attachment description**: {text description of screenshot content. Delete this line if no attachment}
- **Intent interpretation**: {model's understanding of user request}
- **Upstream process issues**: {upstream defects inferred from user input. Delete this line if none}

## Gate Check

> Mandatory for UI-related work. Delete this section for pure backend / pure documentation work.

- Feature YAML: exists / missing / N/A
- ui_contract: complete / partial / missing / N/A
- pixel_baseline: quantified / not quantified / N/A
- data_contract: defined / missing / N/A
- Figma baseline image: cached / missing (reason)
- Skip reason: {reason for continuing despite gate failure. Delete this line if all passed}

## Execution Summary
{One sentence describing what was done and the final result}

## Phase Records

### {Phase Name} (e.g. Collect / Execute / Verify)
- **Input**: {what files/repos were read}
- **Output**: {what files/commits were produced}
- **Deviation**: {differences from spec-protocol process. Delete this line if none}
- **Friction**: {problems/inefficiencies/waiting encountered. Delete this line if none}
- **Decision**: {key judgments made and rationale. Delete this line if none}

(Repeat the above block for each phase actually executed)

### Verify
- build passed
(Standard pass is one line only. Expand details only on failure or **new** warnings. Do not repeat known environment warnings.)

## Friction Point Summary

> /retro command aggregates friction points from all logs. Fixed format for easy parsing.

- [ ] {problem description} | Suggestion: {improvement direction} | Impact: high/med/low
- [ ] ...

## Outcome

- **User acceptance**: passed / not passed / pending
- **Next chain**: {next round log filename if not passed | "closed" if passed}
- **Convergence rounds**: {only fill when closed, total rounds for this chain}

## Workflow Observations

> Observations about the workflow itself (not about code/business).
> Example: "sync type has no predefined step for checking upstream, relies on memory"
> Example: "user sent 3 rounds of screenshots to adjust UI, suggesting pixel_baseline should be quantified before starting"

{observation content, delete this section if none}
```

---

## visual-qa Dedicated Template

> Dedicated template for screenshot-driven UI convergence. Differs from general template: Delta section uses structured deviation table instead of free text.

```markdown
---
date: {YYYY-MM-DD}
type: visual-qa
scope: {f05-home-tag | create-channel-tags}
executor: claude-code | codex | human
duration: ~{N}min
result: completed | blocked | partial
chain: {module identifier}
iteration: {round number}
prev: {previous round filename. Delete if first round}
---

# visual-qa: {scope}

## Trigger

- **Source**: user screenshot comparison
- **User raw input**: {direct quote or summary}
- **Attachment description**: {screenshot A shows what, screenshot B shows what, which areas user marked}
- **Intent interpretation**: {model's understanding}
- **Upstream process issues**: {inferred upstream defects. Delete if none}

## Gate Check

- Feature YAML: exists / missing / N/A
- ui_contract: complete / partial / missing / N/A
- pixel_baseline: quantified / not quantified / N/A
- Figma baseline image: cached / missing (reason)
- Skip reason: {if any}

## Execution Summary
{One sentence}

## Baseline
- **Figma nodes**: {node-id list}
- **Key pixel values**: {core dimensions/spacing/colors/fonts extracted from Figma}
- **Baseline source**: Figma MCP / spec cached screenshot / user-provided design / conservative inference

## Delta

| Area | Figma Baseline | Current Implementation | Deviation | Action |
|------|---------------|----------------------|-----------|--------|
| {area} | {value} | {value} | {difference} | fix / keep(reason) / TBD |

## Fix
- **Decision**: {key fix decisions and rationale, do not enumerate code changes}
- **Conflict resolution**: {choice and rationale when PRD vs Figma contradict. Delete if none}

## Verify
- build passed
(Only expand on anomalies)

## Friction Point Summary

- [ ] {problem} | Suggestion: {direction} | Impact: high/med/low

## Outcome

- **User acceptance**: passed / not passed / pending
- **Next chain**: {filename | "closed"}
- **Convergence rounds**: {only fill when closed}

## Workflow Observations

{Delete if none}
```

---

## Fill-in Guide

### What to write
- User raw input (Trigger section)
- Gate execution status (Gate Check section)
- Key decisions and rationale
- Deviations from spec-protocol
- Friction/blocking encountered
- Conflict decisions (PRD vs Figma choices)
- User acceptance result (Outcome section)

### What not to write
- Complete list of code changes (belongs in commit message / PR)
- Repeated descriptions of known environment warnings (record only on first occurrence)
- Defensive boundary statements about what was NOT changed (focus on what was done)
- Technical implementation details unrelated to the workflow

### Chain judgment quick reference

| Situation | Same chain? | Example |
|-----------|-------------|---------|
| Same module UI multi-round adjustments | Yes | F05 home page 3 rounds of review |
| Same bug multiple fix attempts | Yes | Search highlight residual -> fix diff -> fix cell |
| Same module different problem domain | No | Create page UI adjustment vs create page data submission |
| Different modules | No | Home page vs search page |
