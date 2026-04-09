# {PROJECT_NAME} Web -- Codex CLI Entry Point (AGENTS.md)

This file is auto-loaded by **Codex CLI** when operating in this repository.
It also serves as the reference for any non-Claude-Code AI tool that needs to execute spec-driven tasks.

> Claude Code uses `CLAUDE.md` as its entry point instead. Both tools share the same execution protocol.

---

## Required Reading Order

Read these files before starting any work. This order matters -- later files depend on earlier context.

1. `ai/web.md` -- Web conventions: TypeScript, framework, build, project structure
2. `ai/ui.md` -- UI/component conventions: Figma workflow, six-dimension analysis
3. Any additional `ai/*.md` files (git rules, API rules, workflow rules, etc.)
4. `.claude/config.yaml` -- project configuration (version, platform, paths)
5. `.claude/commands/spec-next.md` -- the full Worker-side execution protocol (Codex CAN read this file despite the `.claude/` directory name)
6. `specs/` -- external specs repository: PRD, Figma index, API contracts, task plans

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
- Run build verification (`{PACKAGE_MANAGER} run build`, expect zero errors)
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

- After every modification, run `{PACKAGE_MANAGER} run build` and confirm zero errors
- Run `{PACKAGE_MANAGER} run typecheck` to verify TypeScript types
- No hardcoded user-facing strings; use the project's i18n system
- Semantic HTML for accessibility (not `div` for everything)
- Keep change scope minimal; do not refactor unrelated code

---

## Project Structure

- `src/app/` -- App entry, routing, layout, providers
- `src/features/` -- Feature modules organized by domain
- `src/components/` -- Shared reusable components
- `src/hooks/` -- Custom hooks
- `src/utils/` -- Utility functions
- `src/types/` -- Shared TypeScript types
- `src/assets/` -- Static assets (images, fonts, icons)
- `public/` -- Public static files
- `specs/` -- Spec repository (symlink to `../specs/{project}`)

---

## Build Commands

```bash
{PACKAGE_MANAGER} run build             # Production build (primary verification)
{PACKAGE_MANAGER} run typecheck         # TypeScript check
{PACKAGE_MANAGER} run lint              # ESLint
{PACKAGE_MANAGER} run test              # Unit tests
{PACKAGE_MANAGER} run test:e2e          # E2E tests
```

---

## Coding Standards

- TypeScript: 2-space indentation, explicit return types on exports, no `any`
- Naming: PascalCase (components), camelCase (functions/variables), SCREAMING_SNAKE_CASE (constants)
- Component: one per file, functional only, co-locate tests and styles
- Commit format: `type(scope): subject` (e.g., `feat(chat): add message reactions`)
- Never commit sensitive files (`.env`, `.env.local`, credentials)

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

## Capabilities Matrix

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
