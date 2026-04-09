# Backend Coding Conventions

> Tool-agnostic backend project constraints. All AI tools (Codex CLI, Claude Code, Cursor, Copilot, etc.) must follow these rules when modifying backend code.

## Project Overview

- **Language**: {LANGUAGE} (e.g., Go / Node.js + TypeScript / Python / Java / Rust)
- **Framework**: {FRAMEWORK} (e.g., Gin / Express + Fastify / FastAPI + Django / Spring Boot)
- **Database**: {DATABASE} (e.g., PostgreSQL / MySQL / MongoDB)
- **ORM**: {ORM} (e.g., GORM / Prisma / SQLAlchemy / TypeORM)
- **Cache**: {CACHE} (e.g., Redis)
- **Message queue**: {MQ} (e.g., RabbitMQ / Kafka / none)

---

## Code Style (mandatory)

### General
- Follow the language's official style guide (gofmt, black, prettier, etc.).
- Line length: language default or <= 120 characters.
- One concern per file. Group by domain, not by layer.

### Naming
| Element | Convention | Example |
|---------|-----------|---------|
| Package / module | lowercase | `user`, `auth`, `payment` |
| Type / class | PascalCase | `UserService`, `OrderRepository` |
| Function / method | language convention | `CreateUser` (Go) / `createUser` (TS/JS) / `create_user` (Python) |
| Constant | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Database table | snake_case, plural | `users`, `order_items` |
| API endpoint | kebab-case | `/api/v1/order-items` |
| Environment variable | SCREAMING_SNAKE_CASE | `DATABASE_URL` |

### Error Handling
- Never swallow errors silently.
- Return structured error responses with consistent format.
- Log errors with context (request ID, user ID, operation).
- Use error codes, not just messages, for client-facing errors.

---

## API Design Rules (mandatory)

### RESTful Conventions
| Method | Usage | Idempotent |
|--------|-------|------------|
| GET | Read resource(s) | Yes |
| POST | Create resource | No |
| PUT | Full replace | Yes |
| PATCH | Partial update | Yes |
| DELETE | Remove resource | Yes |

### Response Format
```json
{
  "code": 0,
  "message": "success",
  "data": { ... }
}
```

Error response:
```json
{
  "code": 40001,
  "message": "Validation failed",
  "errors": [
    { "field": "email", "message": "invalid format" }
  ]
}
```

### Versioning
- URL path versioning: `/api/v1/`, `/api/v2/`.
- Do not break existing API contracts without version bump.

### Pagination
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 150
  }
}
```

---

## Database Rules (mandatory)

- All schema changes must be migration files (no manual DDL).
- Migrations must be reversible (up + down).
- Index frequently queried columns. Explain slow queries.
- Use transactions for multi-table writes.
- No `SELECT *` in production code; specify columns explicitly.
- Soft delete (set `deleted_at`) unless storage constraints require hard delete.

---

## Security Rules (mandatory)

- **Input validation**: validate and sanitize all user input at the boundary.
- **SQL injection**: use parameterized queries or ORM. Never concatenate user input into SQL.
- **Authentication**: verify auth token on every protected endpoint.
- **Authorization**: check permissions before accessing resources.
- **Secrets**: never hardcode secrets. Use environment variables or secret manager.
- **CORS**: configure explicitly. No wildcard `*` in production.
- **Rate limiting**: apply to public and auth endpoints.

---

## Build Verification (mandatory)

After every change, run:
```bash
# Replace with your project's commands
{BUILD_COMMAND}                     # Must compile/build successfully
{LINT_COMMAND}                      # Must pass (golint / eslint / flake8 / etc.)
{TEST_COMMAND}                      # Unit tests must pass
```

Build loop: modify -> build -> test -> fix errors -> repeat. Never accumulate errors.

Keep change scope minimal. Do not refactor unrelated code incidentally.

---

## Testing

- Unit tests for business logic (services, use cases).
- Integration tests for API endpoints (test full request/response cycle).
- Test database operations against a test database (not mocks for critical paths).
- Test coverage: aim for > 80% on business logic.
- Test naming: `TestCreateUser_WithValidInput_ReturnsUser` (Go) / `should create user with valid input` (JS/TS).

---

## Logging

- Structured logging (JSON format in production).
- Log levels: ERROR (failures), WARN (degraded), INFO (business events), DEBUG (development).
- Include request ID, user ID, and operation context in every log line.
- Never log sensitive data (passwords, tokens, PII).

---

## Git Conventions

- **Commit format**: `type(scope): subject`
- **Types**: feat, fix, refactor, test, docs, chore, perf, ci.
- **Subject**: imperative mood, no period, under 72 characters.
- Reference tasks: `Refs B01` or `Closes B01`.

---

## Worktree Environment

External paths (specs, api-doc) are resolved via `.context-resolved.yaml`.
If missing, run `bash {specs_repo}/scripts/resolve-context.sh` to auto-detect paths.
Legacy `specs` symlink still works as fallback.
