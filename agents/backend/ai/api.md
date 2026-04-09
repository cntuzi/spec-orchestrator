# API Development Conventions

> Rules for API design, documentation, and contract verification in backend projects.

## Core Principle

**API is a contract. Breaking changes require version bumps.**

Every API change must be verified against the spec before shipping.

---

## API Contract Verification

Before implementing any API task, verify against the spec:

1. **Read** the Feature YAML `api[]` section for endpoint definitions.
2. **Read** `tasks/backend.md` for detailed request/response schemas.
3. **Compare** with existing Swagger/OpenAPI if available.
4. **Implement** matching the spec exactly (paths, methods, field names, types).
5. **Test** with actual requests to verify contract compliance.

---

## Endpoint Design Checklist

| Aspect | Requirement |
|--------|-------------|
| **Path** | RESTful, kebab-case, versioned (`/api/v1/user-profiles`) |
| **Method** | Correct HTTP verb (GET for read, POST for create, etc.) |
| **Request body** | Validated with clear error messages |
| **Response** | Consistent envelope format with proper status codes |
| **Auth** | Protected unless explicitly public |
| **Pagination** | Required for list endpoints |
| **Error codes** | Documented and consistent across endpoints |
| **Idempotency** | POST endpoints should handle duplicate submissions |

---

## HTTP Status Codes

| Code | When to Use |
|------|-------------|
| 200 | Success (GET, PUT, PATCH, DELETE) |
| 201 | Resource created (POST) |
| 204 | Success with no body (DELETE) |
| 400 | Client error: validation failure, bad request |
| 401 | Not authenticated |
| 403 | Not authorized (authenticated but lacks permission) |
| 404 | Resource not found |
| 409 | Conflict (duplicate, version mismatch) |
| 422 | Unprocessable entity (valid format, invalid semantics) |
| 429 | Rate limited |
| 500 | Server error (unexpected failure) |

---

## Request/Response Patterns

### List with Pagination
```
GET /api/v1/tasks?page=1&page_size=20&status=active
```

### Create with Validation
```
POST /api/v1/tasks
Content-Type: application/json
{ "title": "...", "priority": "high" }
```

### Partial Update
```
PATCH /api/v1/tasks/123
Content-Type: application/json
{ "status": "done" }
```

---

## Documentation

- Every endpoint must have OpenAPI/Swagger annotations or doc comments.
- Document all query parameters, request body fields, and response schemas.
- Include example requests and responses.
- Document error responses for each endpoint.

---

## Migration from Spec to Code

When implementing a backend task (B{nn}):

1. Read the full task definition from `tasks/backend.md`.
2. Read related Feature YAMLs for business context.
3. Implement the endpoint matching the spec contract.
4. Write integration tests that verify the contract.
5. Update API documentation (Swagger/OpenAPI).
6. Verify against `tasks/backend.md` acceptance criteria.

---

## Performance

- N+1 query prevention: use eager loading / joins for related data.
- Add database indexes for query patterns identified in the spec.
- Use caching for frequently read, rarely changed data.
- Set reasonable timeouts for external service calls.
- Use connection pooling for database and HTTP clients.
