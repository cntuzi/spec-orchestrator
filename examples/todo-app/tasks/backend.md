# Backend API Tasks -- Todo App v1.0

> Backend API dependencies for frontend tasks.
> Each entry maps to endpoints that frontend features depend on.

---

## API Overview

| ID | API | Blocks Features | Status | Verification |
|----|-----|----------------|--------|--------------|
| B01 | GET/POST/DELETE /api/tasks | F01, F02 | pending | verified (2026-01-15) |
| B02 | GET/PATCH /api/tasks/{id} | F03 | pending | verified (2026-01-15) |

---

## B01 -- Task Collection Endpoints

**Blocks**: F01 (Task List), F02 (Create Task)
**Status**: pending

### GET /api/tasks

List tasks with optional filtering and pagination.

**Request Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| status | string | no | Filter: `all` (default), `active`, `completed` |
| page | integer | no | Page number, default 1 |
| per_page | integer | no | Items per page, default 20, max 100 |
| sort_by | string | no | Sort field: `due_date`, `created_at` (default) |
| sort_order | string | no | `asc` (default), `desc` |

**Response (200):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "tasks": [
      {
        "id": 1,
        "title": "Buy groceries",
        "status": "active",
        "due_date": "2026-04-01",
        "created_at": "2026-03-15T10:30:00Z",
        "updated_at": "2026-03-15T10:30:00Z"
      }
    ],
    "total_count": 42,
    "page": 1,
    "per_page": 20
  }
}
```

**Status Enum:**

| Value | Meaning |
|-------|---------|
| `active` | Task not yet completed |
| `completed` | Task marked as done |

### POST /api/tasks

Create a new task.

**Request Body (JSON):**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| title | string | yes | Task title, 1-100 characters |
| due_date | string | no | ISO 8601 date, e.g. `2026-04-15` |

**Response (201):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "task": {
      "id": 43,
      "title": "Buy groceries",
      "status": "active",
      "due_date": "2026-04-15",
      "notes": "",
      "created_at": "2026-03-31T14:00:00Z",
      "updated_at": "2026-03-31T14:00:00Z"
    }
  }
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| 422 | Title empty or exceeds 100 characters |

### DELETE /api/tasks/{id}

Delete a task by ID.

**Path Parameters:**

| Name | Type | Description |
|------|------|-------------|
| id | integer | Task ID |

**Response (200):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "success": true
  }
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| 404 | Task not found |

---

## B02 -- Task Detail Endpoints

**Blocks**: F03 (Task Detail)
**Status**: pending

### GET /api/tasks/{id}

Fetch full detail of a single task.

**Path Parameters:**

| Name | Type | Description |
|------|------|-------------|
| id | integer | Task ID |

**Response (200):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "task": {
      "id": 1,
      "title": "Buy groceries",
      "status": "active",
      "due_date": "2026-04-01",
      "notes": "Milk, eggs, bread, butter",
      "created_at": "2026-03-15T10:30:00Z",
      "updated_at": "2026-03-28T09:15:00Z"
    }
  }
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| 404 | Task not found |

### PATCH /api/tasks/{id}

Partially update a task. Only provided fields are updated.

**Path Parameters:**

| Name | Type | Description |
|------|------|-------------|
| id | integer | Task ID |

**Request Body (JSON):**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| title | string | no | Updated title, 1-100 characters |
| status | string | no | `active` or `completed` |
| notes | string | no | Updated notes text |
| due_date | string | no | ISO 8601 date or `null` to clear |

**Response (200):**

```json
{
  "code": 0,
  "message": "success",
  "data": {
    "task": {
      "id": 1,
      "title": "Buy groceries",
      "status": "completed",
      "due_date": "2026-04-01",
      "notes": "Milk, eggs, bread, butter",
      "created_at": "2026-03-15T10:30:00Z",
      "updated_at": "2026-03-31T14:30:00Z"
    }
  }
}
```

**Error Responses:**

| Code | Condition |
|------|-----------|
| 404 | Task not found |
| 422 | Title empty or exceeds 100 characters; invalid status value |
