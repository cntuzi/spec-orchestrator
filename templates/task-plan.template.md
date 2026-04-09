# {VERSION} {PLATFORM} Task Plan

## Metadata

| Field | Value |
|-------|-------|
| **Version** | {VERSION} |
| **Platform** | {PLATFORM} |
| **PRD** | `specs/{VERSION}/prd/` |
| **Figma** | [figma-index.md](../figma-index.md) (file key: `{FIGMA_FILE_KEY}`) |
| **API** | `specs/api/API-CATALOG.md` + `api-doc/{service}_swagger.json` |
| **Tech Doc** | `api-doc/tec_docs/{TECH_DOC}` |
| **Created** | {DATE} |
| **Last Updated** | {DATE} |

---

## Dependency Check

Verify the following prerequisites before executing tasks:

| Dependency | Status |
|------------|--------|
| S1 PRD Confirmed | :red_circle: |
| S2 Design Reviewed | :red_circle: |
| S3 API Defined | :red_circle: |

---

## Task Overview

| ID | Module | Task Name | Feature | Priority | Schedule | Status | Dependencies |
|----|--------|-----------|---------|----------|----------|--------|--------------|
| **{MODULE_GROUP}** |
| T01 | {MODULE} | {TASK_NAME} | F01 | P0 | D1 | :red_circle: | - |
| T02 | {MODULE} | {TASK_NAME} | F02 | P0 | D1-D2 | :red_circle: | T01 |

**Stats**: {TOTAL} tasks | :red_circle: Pending: {PENDING} | :yellow_circle: In Progress: {IN_PROGRESS} | :green_circle: Completed: {COMPLETED}

---

## Task Details

---

### T01: {TASK_NAME}

#### Requirements
{REQUIREMENT_DESCRIPTION}

#### Figma
| Page | Node ID | Usage |
|------|---------|-------|
| {PAGE_NAME} | `{NODE_ID}` | {PAGE_DESCRIPTION} |

> All Node IDs must be cross-validated with figma-index.md to ensure no pages are missed.

#### UI Contract (blocking)
| Field | Content |
|-------|---------|
| Must Implement | {UI_REQUIRED_1} |
| Forbidden | {UI_FORBIDDEN_1} |
| Key Dimensions/Tokens | {UI_TOKEN_1} |
| State Matrix | {STATE_1}:{NODE_1}, {STATE_2}:{NODE_2} |

> Detailed rules in `specs/workflows/ui-contract.md`. Tasks involving UI cannot be marked :green_circle: without passing this gate.

#### Delivery Gate (delivery_contract, blocking)
| Gate | Content |
|------|---------|
| Stack Baseline | iOS: {IOS_STACK_BASELINE} / Android: {ANDROID_STACK_BASELINE} |
| Forbidden Alternatives | {STACK_FORBIDDEN_1} |
| Data Field Source Priority | {DATA_FIELD_1}: {SOURCE_PRIORITY_1} |
| Writeback Target | {DATA_WRITEBACK_1} |

> Detailed rules in `specs/workflows/ui-delivery-playbook.md`. Tasks involving UI cannot be marked :green_circle: without passing this gate.

#### API
| Endpoint | Method | Usage | Source |
|----------|--------|-------|--------|
| /api/{endpoint} | POST | {API_DESCRIPTION} | backend.md#B{nn} |
| /api/{endpoint} | POST | {API_DESCRIPTION} | swagger: {service}_swagger.json |

> Endpoint sources: Swagger vs manual backend.md, see backend.md for details.

#### i18n
| Key | Default Value |
|-----|---------------|
| `{module}.{feature}.{key}` | {DEFAULT_VALUE} |

> Full copy in {VERSION}/i18n/strings.md. Apply platform-specific formatting when writing to i18n files.

#### Analytics
`{action}` x `{scene}` x `{object}`

#### Layered Execution (L1-L4)
- [ ] L1-Structure: {L1_STRUCTURE_DELIVERABLE}
- [ ] L2-Visual: {L2_VISUAL_DELIVERABLE}
- [ ] L3-Interaction State: {L3_INTERACTION_DELIVERABLE}
- [ ] L4-Verification Evidence: {L4_EVIDENCE_DELIVERABLE}

#### Acceptance Criteria
- [ ] AC1: {ACCEPTANCE_CRITERIA_1}
- [ ] AC2: {ACCEPTANCE_CRITERIA_2}

#### Visual Acceptance (blocking)
- [ ] VS1: {VISUAL_CRITERIA_1}
- [ ] VS2: {VISUAL_CRITERIA_2}
- [ ] VS3: Forbidden implementation not triggered (scan `UI_FORBIDDEN`)
- [ ] VS4: Stack baseline check passed (no hits on `delivery_contract.stack_baseline.forbidden`)
- [ ] VS5: Data contract check passed (field source/priority/writeback matches Feature)

#### Verification Evidence
- Figma baseline screenshot: {FIGMA_BASELINE_PATH}
- Implementation screenshot: {IMPLEMENTATION_SCREENSHOT_PATH}
- Scan command summary: {VALIDATION_COMMAND_RESULT}

#### Tech Notes
- {TECH_NOTE_1}
- **Reusable**: {REUSABLE_COMPONENT}
- **API Change**: {KNOWN_API_GAP_DESCRIPTION}, see backend.md B{nn}
- **API Missing**: {MISSING_API_DESCRIPTION}, backend team needs to provide

> API gap markers come from Phase 3 alignment; verified at execution time via API Contract Verify.

#### Dependencies
- T{nn} ({DEPENDENCY_TASK_NAME})
- backend.md B{nn} ({BACKEND_DEPENDENCY_DESC})

#### Status
:red_circle: Pending

---

## Execution Guide

This file works with the 7-step process defined in spec-protocol.md. To execute a single task:

```
User: Execute T01

AI Agent 7-step process (see spec-protocol.md):
1. Parse  - Read this file to get T01 details
2. Check  - Verify dependency status (S1-S3 + backend.md) + API Contract Verify + UI Contract Verify + Delivery Contract Verify
3. Lock   - Update T01 status :red_circle: -> :yellow_circle: + git commit
4. Collect - Download Figma screenshots + extract API definitions + search code context
5. Execute - Implement feature code + i18n + analytics + satisfy UI contract/delivery gate
6. Verify  - Build verification (./scripts/build.sh) + visual gate acceptance
7. Update  - Update T01 status :yellow_circle: -> :green_circle: + git commit
```

### Batch Execution

```
User: Execute {MODULE} module in order (T01-T05)

AI Agent process:
1. Check cross-platform dependencies (S1-S3)
2. Check inter-task dependencies
3. Execute in dependency order; tasks without dependencies can run in parallel
4. Each task goes through the full 7-step process
```

### View Progress

```bash
grep -E "^\| T[0-9]+ \|" specs/{VERSION}/tasks/{PLATFORM}.md
```

### Parallelism

```
D1: {DAY_1_TASKS}
D2: {DAY_2_TASKS}
...
```
