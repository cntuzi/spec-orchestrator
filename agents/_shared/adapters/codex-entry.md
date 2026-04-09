## Spec-Driven Execution (Codex)

When instructed to execute a spec task (e.g., "Execute /spec-next T01"), follow this protocol:

1. Read `.claude/config.yaml` for project config (version, platform, specs path)
2. Read the full execution protocol at `.claude/commands/spec-next.md`
3. Follow the protocol steps: Config -> Status -> Resolve -> Context -> Lock -> Execute -> Verify -> Update -> Loop

### What Codex Handles

- **Gate Check recording** -- read Feature YAML, evaluate ui_contract / pixel_baseline / data_contract gates
- **Collect phase** -- read specs, read code, read cached Figma screenshots at `.claude/cache/`
- **Execute phase** -- write code following platform conventions in `ai/`
- **Verify phase** -- run build command, fix compilation errors, re-run until pass or 3-failure limit
- **Stage records** -- append phase records to execution log as each phase completes

### What Codex Does NOT Handle

- **Trigger stage** -- pre-filled by Claude Code or human before Codex is launched
- **Outcome stage** -- post-filled by Claude Code or human after Codex completes
- **Screenshot comparison** -- Codex cannot see images; describe visual differences in text instead
- **Figma MCP downloads** -- use cached screenshots at `.claude/cache/{version}/figma/`; if cache is empty, skip Figma and note `missing (no MCP)` in Gate Check
- **chain/iteration/prev fields** -- injected by Claude Code at log creation time; Codex does not modify these frontmatter fields

### Execution Log

- Log file path is provided in the launch prompt
- If no log file exists yet, create one following `workflows/execution-log.template.md`
- Append stage records as you complete each phase
- Use `executor: codex` in frontmatter
- On completion, set `result:` to completed / blocked / partial -- leave `User acceptance:` as `pending`

### Claude Code <-> Codex Handoff Protocol

```
1. Claude Code creates log file, pre-fills frontmatter + Trigger
2. Claude Code launches Codex with: task prompt + log file path + target task ID
3. Codex executes:
   a. Gate Check (read Feature YAML, record gate status)
   b. Collect (read specs, cached Figma, API docs, i18n, codebase)
   c. Execute (implement feature code)
   d. Verify (run build, fix errors, re-run)
   e. Update (mark task done/blocked in specs, append log records)
4. Claude Code post-fills: Outcome (user acceptance result)
```

### Capabilities Matrix

| Capability | Claude Code | Codex CLI |
|------------|-------------|-----------|
| Read files | Yes | Yes |
| Write files | Yes | Yes |
| Run shell commands | Yes | Yes |
| Git operations | Yes | Yes |
| Build verification | Yes | Yes |
| View images/screenshots | Yes | No |
| MCP Figma access | Yes | No |
| User interaction mid-task | Yes | No |
| Slash command auto-discovery | Yes (`.claude/commands/`) | No (read file directly) |
