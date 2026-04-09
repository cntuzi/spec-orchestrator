# PRD Reading & Requirement Extraction Workflow

> Standard flow for reading PRD documents and extracting structured requirements.
> Tool-agnostic: any AI tool can follow this workflow.

---

## Input Materials

| Material | Format | Description |
|----------|--------|-------------|
| **PRD** | Markdown (preferred) or PDF | Full version PRD, AI extracts by section |
| **Scope** | Section number / feature name | When only a subset of a large PRD is needed (can mix) |
| **Figma** | Link + node-id | Supplementary design reference |
| **API** | Swagger JSON / backend.md | API documentation (auto-referenced) |

---

## PRD Source Priority

```
1. Markdown PRD (prd repo)     <- preferred, version-controlled, diff-friendly
2. PDF PRD (specs/{version}/prd/)  <- fallback, harder to parse programmatically
3. prd/README.md (structured index) <- always read as entry point
```

### Reading Strategy

```yaml
step_1_index:
  - Read {version}/prd/README.md first
  - This is the structured requirements summary
  - Contains: feature list, requirement IDs, acceptance criteria
  - Use as navigation map for deeper reads

step_2_detail:
  - For each feature needing detail:
    a. Check if Markdown PRD exists in prd repo -> read relevant section
    b. If only PDF available -> read PDF and extract relevant section
    c. Cross-reference with Feature YAML for any gaps

step_3_reconcile:
  - Compare PRD content with Feature YAML
  - Identify gaps: requirements in PRD not reflected in spec
  - Identify conflicts: spec assumptions that contradict PRD
  - Output reconciliation report
```

---

## Forced Flow (for feat/task work types)

```
Materials -> Requirement Summary (confirm) -> Current State Analysis -> Design Resources
         -> Implementation Plan (confirm) -> Execute
```

### Checkpoints

1. **Requirement summary must be confirmed** -- present as checklist, identify ambiguities
2. **Current state analysis is mandatory** -- simple features get shallow analysis, complex features get full call-chain tracing
3. **Implementation plan includes reuse annotations** -- mark reusable components/patterns with a designated tag
4. **Build after each module** -- do not accumulate errors

### Confirmation Protocol

When presenting requirement summary for confirmation:
```
- Present numbered requirement list
- Flag ambiguities or missing information with [?]
- Flag assumptions with [assumed]
- Flag contradictions with [conflict]
- Wait for user confirmation or correction
- Corrections -> update summary -> re-confirm (may iterate)
```

---

## Requirement Extraction Schema

For each feature extracted from PRD, produce:

```yaml
feature:
  id: F{nn}
  name: "{feature_name}"
  prd_section: "{section_reference}"

  requirements:
    - id: R{nn}
      desc: "{requirement description}"
      type: functional / ui / data / integration
      priority: P0 / P1 / P2

  acceptance_criteria:
    - id: AC{nn}
      type: ui / interaction / api / data
      desc: "{testable acceptance criterion}"

  state_scenarios:
    - id: S{nn}
      name: "{state_name}"     # empty / filled / error / loading
      trigger: "{what causes this state}"
      expected: "{expected behavior}"

  data_requirements:
    - field: "{field_name}"
      source: "{where data comes from}"
      format: "{expected format/type}"

  edge_cases:
    - "{edge case description}"
```

---

## Reuse Analysis

During requirement extraction, identify potential for reuse:

| Type | Examples |
|------|----------|
| Shared logic | Permission checks, pagination, error handling |
| Shared components | List cells, buttons, empty states, loading states |
| Infrastructure | Deep link routing, analytics framework, cache layer |

**Scope**: Focus on current requirements + note broader reuse opportunities.

Mark reusable items in the implementation plan with a consistent tag for later extraction.

---

## PRD Change Detection

When re-reading a PRD (e.g., after `/spec-init refresh`):

```
1. Compare new PRD content with existing Feature YAMLs
2. Identify:
   - New requirements not in any Feature YAML
   - Modified requirements (content changed)
   - Removed requirements
3. For each change:
   - Map to affected Features and Tasks
   - Flag for CR creation if tasks are in-progress or done
4. Output change report
```

---

## Output Artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| Requirement summary | {version}/prd/README.md | Structured index of all features |
| Feature specs | {version}/features/F{nn}-*.yaml | One file per feature |
| Task plans | {version}/tasks/{platform}.md | Platform-specific task breakdown |
| i18n strings | {version}/i18n/strings.md | Extracted copy |
| Change records | {version}/CHANGELOG.md | If PRD changed after initial generation |
