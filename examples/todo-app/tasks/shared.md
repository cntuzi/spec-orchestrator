# Shared Prerequisites -- Todo App v1.0

> Cross-platform prerequisites that must be resolved before task execution begins.

---

## Prerequisites

| ID | Item | Status | Owner | Notes |
|----|------|--------|-------|-------|
| S1 | PRD confirmed | pending | PM | PRD v1.0 in prd/README.md |
| S2 | Design reviewed | pending | Design | Figma file key in config.yaml |
| S3 | API defined | pending | Backend | Swagger in api-doc/todo_swagger.json |

---

## API Patterns

All endpoints follow these conventions:

### Base URL

```
Production:  https://api.example.com/v1
Staging:     https://api-staging.example.com/v1
```

### Authentication

```
Header: Authorization: Bearer {access_token}
```

### Response Envelope

All responses wrapped in a standard envelope:

```json
{
  "code": 0,
  "message": "success",
  "data": { ... }
}
```

### Error Codes

| Code | Meaning | Client Action |
|------|---------|---------------|
| 0 | Success | Process data |
| 401 | Unauthorized | Redirect to login |
| 404 | Not found | Show "not found" state |
| 422 | Validation error | Show field-level errors |
| 429 | Rate limited | Retry after delay |
| 500 | Server error | Show generic error, retry |

### Pagination

```json
{
  "data": {
    "items": [...],
    "total_count": 42,
    "page": 1,
    "per_page": 20
  }
}
```

---

## Platform Build Commands

| Platform | Build Command | Expected Output |
|----------|--------------|-----------------|
| iOS | `./scripts/build.sh` | `BUILD SUCCEEDED` |
| Android | `./gradlew assembleDebug` | `BUILD SUCCESSFUL` |
