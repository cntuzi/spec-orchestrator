---
description: Aggregate execution logs into workflow improvement insights
---

# /retro — Workflow Retrospective

User request: $ARGUMENTS

## Argument Parsing

```
$ARGUMENTS parsing:

  ""              → version=auto(latest), period=last 2 weeks
  "W12"           → version=auto, period=week 12
  "2026-03"       → version=auto, period=March 2026
  "all"           → version=auto, period=all time
  "1.3 W12"       → version=1.3, period=week 12
```

---

## Step 1: Collect Logs

```
1. Determine version:
   version=auto → read {project}/ directory for latest version number

2. Read log directory:
   log_dir = {project}/{version}/_logs/
   List all *.md files

3. Filter by time range:
   - Extract date from filename (YYYY-MM-DD)
   - Filter by period parameter
   - If no logs → "No execution logs in specified time range", exit

4. Parse each log's frontmatter:
   - date, type, scope, executor, duration, result
```

---

## Step 2: Aggregate Analysis

```
1. Work type distribution:
   - Count task/sync/change/review/visual-qa/fix/retro occurrences
   - Sum total duration per type (from duration field)
   - Output: table

2. Friction point aggregation:
   - Extract all "- [ ]" items from each log's "## Friction Points" section
   - Group by keyword similarity (same friction across different logs)
   - Sort by frequency descending
   - Annotate impact level distribution (high/med/low)

3. Phase deviation analysis:
   - Extract "deviation" field from each log's phase records
   - Count which phases most often have deviations
   - Count which phases are most often skipped (missing from log)
   - Skipped > 50% → flag as "possibly redundant step"

4. Workflow observation aggregation:
   - Extract content from each log's "## Workflow Observations" section
   - Categorize: process gap / process redundancy / tool issue / collaboration issue

5. Executor analysis:
   - Count claude-code / codex / human executions
   - Calculate success rate per executor (completed vs blocked/partial)
```

---

## Step 3: Generate Report

```
Output to: {project}/{version}/_retro/{date}-retro.md

Format:

# Workflow Retrospective: {period}

## Overview
| Metric | Value |
|--------|-------|
| Log count | {N} |
| Time range | {start} ~ {end} |
| Total duration | ~{N}min |

## Work Type Distribution
| Type | Count | Duration | Percentage |
|------|-------|----------|------------|
| task | {n} | {t}min | {p}% |
| sync | {n} | {t}min | {p}% |
...

## Top Friction Points
| # | Friction Point | Occurrences | Impact | Suggestion |
|---|---------------|-------------|--------|------------|
| 1 | {desc} | {n}x | high | {suggestion} |
...

## Phase Health
| Phase | Execution Rate | Deviation Rate | Friction Rate | Diagnosis |
|-------|---------------|---------------|---------------|-----------|
| Parse | 95% | 10% | 5% | Healthy |
| Check | 60% | 30% | 20% | Often skipped |
...

> Execution rate < 50% → "Consider simplifying or merging"
> Deviation rate > 50% → "Process doesn't match reality"
> Friction rate > 30% → "Needs improvement"

## Workflow Improvement Suggestions

Sorted by priority:

### P0 — Must fix
{Derived from high-frequency friction + high-deviation phases}

### P1 — Should fix
{Derived from mid-frequency friction + workflow observations}

### P2 — Nice to fix
{Derived from low-frequency but insightful observations}

## Suggested File Changes

> If improvement suggestions involve workflow files, list specific changes.

| File | Change | Related Suggestion |
|------|--------|--------------------|
| workflows/spec-protocol.md | {specific change} | P0-1 |
| .claude/commands/spec-drive.md | {specific change} | P1-2 |
...
```

---

## Step 4: Output Summary

```
Print report summary in terminal (not the full report):

## v{version} Workflow Retrospective ({period})

{N} logs, {total_time}min

Top 3 friction points:
1. {desc} ({n}x)
2. {desc} ({n}x)
3. {desc} ({n}x)

{M} improvement suggestions (P0: {a}, P1: {b}, P2: {c})

Full report: {project}/{version}/_retro/{date}-retro.md
```

---

## Key Conventions

- retro itself produces a log: `_logs/{date}-retro-{period}.md`
- retro reports are suggestions — they don't auto-modify workflow files
- If user confirms suggestions → manually execute or let AI apply changes
- Suggestions accumulate and are checked in the next retro for completion
