# iOS Task Plan -- Todo App v1.0

> Single source of truth for iOS task status.
> Status is read and written here by Workers. DASHBOARD is aggregated from this file.

---

## Task Overview

| ID | Module | Task | Feature | Priority | Status | Deps |
|----|--------|------|---------|----------|--------|------|
| T01 | tasks | Task List | F01 | P0 | pending | - |
| T02 | tasks | Create Task | F02 | P0 | pending | T01 |
| T03 | tasks | Task Detail | F03 | P1 | pending | T01, B02 |

**Stats**: 0/3 complete | 0 active | 0 blocked | 3 pending

---

## Task Details

### T01 -- Task List

**Feature**: F01-task-list
**Priority**: P0
**Status**: pending
**Dependencies**: none
**Estimated effort**: 1.5 days

#### Description

Implement the main task list screen with filtering, pull-to-refresh, pagination,
swipe-to-delete, and all associated states (empty, loading, error, default).

#### API Endpoints

| Endpoint | Method | Source | Verified |
|----------|--------|--------|----------|
| /api/tasks | GET | swagger | yes |
| /api/tasks/{id} | DELETE | swagger | yes |

#### Figma Pages

| Node ID | Page Name |
|---------|-----------|
| 100:200 | Task List - Default |
| 100:300 | Task List - Empty State |
| 100:400 | Task List - Loading Skeleton |
| 100:500 | Task List - Swipe Delete |

#### i18n Keys

- todo.list.title
- todo.list.filter.all / .active / .completed
- todo.list.empty.title / .subtitle / .create_button
- todo.list.delete.confirm_title / .confirm_message / .cancel / .confirm
- todo.list.error.network / .cached_banner

#### Technical Notes

- Use DiffableDataSource for performant list updates
- Implement skeleton loading with custom ShimmerView
- Cache filter preference in UserDefaults
- Pagination: load next page when scrolled to last 5 items

#### Completion Record

_To be filled upon completion:_

- Completed: -
- Merge commit: -
- Implementation summary: -

---

### T02 -- Create Task

**Feature**: F02-create-task
**Priority**: P0
**Status**: pending
**Dependencies**: T01 (reuses task list data layer and cell component)
**Estimated effort**: 1 day

#### Description

Implement the bottom sheet for task creation with title input, character counter,
optional due date picker, and save flow.

#### API Endpoints

| Endpoint | Method | Source | Verified |
|----------|--------|--------|----------|
| /api/tasks | POST | swagger | yes |

#### Figma Pages

| Node ID | Page Name |
|---------|-----------|
| 200:100 | Create Task - Empty |
| 200:200 | Create Task - Filled |

#### i18n Keys

- todo.create.placeholder
- todo.create.due_date.none / .label
- todo.create.save
- todo.create.char_counter
- todo.create.error.save_failed

#### Technical Notes

- Use UISheetPresentationController with .medium() detent
- Character counter: update on every text change via Combine publisher
- Date picker: UIDatePicker in .compact style
- Dismiss: support both drag-to-dismiss and tap-outside

#### Completion Record

_To be filled upon completion:_

- Completed: -
- Merge commit: -
- Implementation summary: -

---

### T03 -- Task Detail

**Feature**: F03-task-detail
**Priority**: P1
**Status**: pending
**Dependencies**: T01 (navigation from list), B02 (GET/PATCH /api/tasks/{id})
**Estimated effort**: 1 day

#### Description

Implement the task detail screen with inline editing for title and notes,
status toggle, and due date modification.

#### API Endpoints

| Endpoint | Method | Source | Verified |
|----------|--------|--------|----------|
| /api/tasks/{id} | GET | swagger | yes |
| /api/tasks/{id} | PATCH | swagger | yes |

#### Figma Pages

| Node ID | Page Name |
|---------|-----------|
| 300:100 | Task Detail - Active |
| 300:200 | Task Detail - Completed |

#### i18n Keys

- todo.detail.notes.placeholder
- todo.detail.due_date.label
- todo.detail.created.label
- todo.detail.not_found

#### Technical Notes

- Optimistic UI: toggle checkbox immediately, revert on API failure
- Use UITextView for notes (multiline)
- Debounce title/notes edits (500ms) before sending PATCH
- Handle 404 response when task deleted by another client

#### Completion Record

_To be filled upon completion:_

- Completed: -
- Merge commit: -
- Implementation summary: -
