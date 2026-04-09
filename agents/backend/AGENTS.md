# {PROJECT_NAME} Backend -- Codex CLI Entry Point (AGENTS.md)

This file is auto-loaded by **Codex CLI** when operating in this repository.
It also serves as the reference for any non-Claude-Code AI tool that needs to execute spec-driven tasks.

> Claude Code uses `CLAUDE.md` as its entry point instead. Both tools share the same execution protocol.

---

## Required Reading Order

Read these files before starting any work. This order matters -- later files depend on earlier context.

1. `ai/backend.md` -- Backend conventions: architecture, code style, database, security
2. `ai/api.md` -- API design conventions: RESTful rules, contract verification, documentation
3. Any additional `ai/*.md` files (git rules, workflow rules, etc.)
4. `.claude/config.yaml` -- project configuration (version, platform, paths)
5. `.claude/commands/spec-next.md` -- the full Worker-side execution protocol (Codex CAN read this file despite the `.claude/` directory name)
6. `specs/` -- external specs repository: PRD, API contracts, task plans

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
- Run build verification (`{BUILD_COMMAND}`, `{TEST_COMMAND}`)
- Follow the full spec-next execution protocol autonomously
- Create and append to execution logs

### What Codex CANNOT Do
- **View images/screenshots** -- not relevant for backend but noted for consistency
- **Access Figma MCP** -- not applicable for backend tasks
- **Interact with user mid-task** -- Trigger and Outcome stages are pre-filled by Claude Code or left for post-fill
- **Auto-discover slash commands** -- read `.claude/commands/spec-next.md` directly when instructed

---

## Minimum Requirements (mandatory)

- After every modification, run build + tests and confirm all pass
- All API endpoints must match the spec contract (paths, methods, fields, types)
- Use parameterized queries; never concatenate user input into SQL
- Validate all user input at the boundary
- Never hardcode secrets; use environment variables
- Keep change scope minimal; do not refactor unrelated code

---

## Project Structure

- `cmd/` -- Entry points and main packages
- `internal/handler/` -- HTTP handlers / controllers
- `internal/service/` -- Business logic layer
- `internal/repository/` -- Data access layer
- `internal/model/` -- Domain models and DTOs
- `internal/middleware/` -- HTTP middleware
- `migrations/` -- Database migration files
- `config/` -- Configuration files
- `specs/` -- Spec repository (symlink to `../specs/{project}`)

> Adjust to match your language/framework conventions.

---

## Build Commands

```bash
{BUILD_COMMAND}                     # Build (primary verification)
{TEST_COMMAND}                      # Unit tests
{INTEGRATION_TEST_COMMAND}          # Integration tests
{LINT_COMMAND}                      # Lint check
{MIGRATE_COMMAND}                   # Database migrations
```

---

## Coding Standards

- Follow language-specific official style guide
- Error handling: never swallow errors; return structured error responses
- Database: migrations-only schema changes, parameterized queries, no SELECT *
- Security: validate input, check auth, no hardcoded secrets
- Commit format: `type(scope): subject` (e.g., `feat(auth): add JWT refresh endpoint`)
- Never commit sensitive files (`.env`, credentials, private keys)

---

## Spec-Driven Execution (Codex)

When instructed to execute a spec task (e.g., "Execute /spec-next B01"), follow this protocol:

1. Read `.claude/config.yaml` for project config (version, platform, specs path)
2. Read the full execution protocol at `.claude/commands/spec-next.md`
3. Follow the protocol steps: Config -> Status -> Resolve -> Context -> Lock -> Execute -> Verify -> Update -> Loop

### What Codex Handles
- **Collect phase** -- read specs, read API contracts, read codebase
- **Execute phase** -- write code following platform conventions in `ai/`
- **Verify phase** -- run build + tests, fix errors, re-run until pass or 3-failure limit
- **Stage records** -- append phase records to execution log as each phase completes

### What Codex Does NOT Handle
- **Trigger stage** -- pre-filled by Claude Code or human before Codex is launched
- **Outcome stage** -- post-filled by Claude Code or human after Codex completes
- **chain/iteration/prev fields** -- injected by Claude Code at log creation time

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
| MCP Figma access | Yes (not needed) | No |
| User interaction mid-task | Yes | No |
| Slash command auto-discovery | Yes (`.claude/commands/`) | No (read file directly) |

---

## Execution Log Protocol

All spec-driven work must produce an execution log. Log location:

```
specs/{version}/_logs/{date}-{type}-{scope}.md
```

Refer to `.claude/workflows/` for:
- Work types: task, sync, change, review, fix, retro
- Phase definitions and required fields
- Log content and format requirements
- Chain mechanism for multi-round iterations
