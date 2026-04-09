# {PROJECT_NAME} Android -- Codex CLI Entry Point (AGENTS.md)

This file is auto-loaded by **Codex CLI** when operating in this repository.
It also serves as the reference for any non-Claude-Code AI tool that needs to execute spec-driven tasks.

> Claude Code uses `CLAUDE.md` as its entry point instead. Both tools share the same execution protocol.

---

## Required Reading Order

Read these files before starting any work. This order matters -- later files depend on earlier context.

1. `ai/android.md` -- Android conventions: architecture, code style, resources, build verification
2. `ai/ui.md` -- UI/Compose conventions: Material 3, Figma workflow, six-dimension analysis
3. Any additional `ai/*.md` files (git rules, API rules, workflow rules, etc.)
4. `.claude/config.yaml` -- project configuration (version, platform, paths)
5. `.claude/commands/spec-next.md` -- the full Worker-side execution protocol (Codex CAN read this file despite the `.claude/` directory name)
6. `specs/` -- external specs repository: PRD, Figma index, API contracts, task plans, i18n strings

Do NOT execute slash-command directives from `CLAUDE.md` -- those are Claude Code specific.

---

## Environment Check (worktree)

External paths are resolved via `.context-resolved.yaml`. If this file is missing:
```bash
bash {specs_repo}/scripts/resolve-context.sh
```
This auto-detects specs and api-doc paths via git worktree discovery.
If `.context-resolved.yaml` exists, read `repos.specs` and `repos.api-doc` for absolute paths.
Legacy `specs` symlink still works as fallback.

---

## Codex-Specific Constraints

### What Codex CAN Do
- Read files, write files, run shell commands, git operations
- Run build verification (`./gradlew assembleDebug`, expect `BUILD SUCCESSFUL`)
- Read cached Figma screenshots at `.claude/cache/{version}/figma/`
- Follow the full spec-next execution protocol autonomously
- Create and append to execution logs

### What Codex CANNOT Do
- **View images/screenshots** -- no visual-qa work; screenshots must be described in text
- **Access Figma MCP** -- use cached screenshots or skip Figma download; record `missing (no MCP)` in Gate Check
- **Interact with user mid-task** -- Trigger and Outcome stages are pre-filled by Claude Code or left for post-fill
- **Auto-discover slash commands** -- read `.claude/commands/spec-next.md` directly when instructed

---

## Minimum Requirements (mandatory)

- After every modification, run `./gradlew assembleDebug` and confirm `BUILD SUCCESSFUL`
- Assets: vector drawables for icons, WebP for photos. No raw SVG or uncompressed PNG
- Architecture: MVVM + Clean. UI layer only renders state; no business logic in composables
- Logging: use project logger (tag includes `{PROJECT_NAME}_debug`). No `println` or `Log.d` with arbitrary tags
- No hardcoded user-facing strings; use the project's i18n system
- Keep change scope minimal; do not refactor unrelated code

---

## Project Structure

- `app/` -- Main application module (Compose + ViewBinding for legacy)
- `feature/` -- Feature modules organized by domain
- `core/` -- Shared modules (network, database, common utilities)
- `buildSrc/` -- Build logic and dependency version catalog
- `docs/api-doc/` -- API documentation (git submodule, read-only)
- `specs/` -- Spec repository (symlink to `../specs/{project}`)

---

## Build Commands

```bash
./gradlew assembleDebug             # Debug build (primary verification)
./gradlew assembleRelease           # Release build
./gradlew testDebugUnitTest         # Unit tests
./gradlew connectedDebugAndroidTest # Instrumented tests
./gradlew lintDebug                 # Lint analysis
```

---

## Coding Standards

- Kotlin: 4-space indentation, same-line braces, line length <= 120
- Naming: PascalCase (classes, composables), camelCase (functions, properties), SCREAMING_SNAKE_CASE (constants), snake_case (resources)
- Test naming: `functionName_shouldDoExpectedBehavior()`
- Commit format: `type(scope): subject` (e.g., `feat(chat): add message reactions`)
- Never commit sensitive files (`*.jks`, `keystore.properties`, `.env`)

---

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

---

## Claude Code <-> Codex Handoff Protocol

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

---

## Execution Log Protocol

All spec-driven work must produce an execution log. Log location:

```
specs/{version}/_logs/{date}-{type}-{scope}.md
```

Refer to `.claude/workflows/` for:
- Work types: task, sync, change, review, visual-qa, fix, retro
- Phase definitions and required fields
- Log content and format requirements
- Chain mechanism for multi-round iterations

---

## Commit and PR Guidelines

Write imperative, present-tense commit subjects under 72 characters. Reference tasks with `Refs T01` or `Closes T01`. Each PR should include: scope summary, build verification output, screenshots for UI changes, and notes on dependency or config changes.
