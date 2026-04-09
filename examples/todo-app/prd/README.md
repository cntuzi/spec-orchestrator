# PRD -- Todo App v1.0 (MVP)

> Structured PRD index for the Todo App MVP release.

---

## Version Overview

**Version**: 1.0
**Codename**: MVP
**Goal**: Deliver a minimal but polished task management app with list, create, and detail views across iOS and Android.

**Target Users**: Individual users who want a simple, fast task tracker without the overhead of full project management tools.

---

## Feature List

| ID | Feature | Module | Priority | Description |
|----|---------|--------|----------|-------------|
| F01 | Task List | tasks | P0 | Main screen showing all tasks with filtering, sorting, and swipe-to-delete |
| F02 | Create Task | tasks | P0 | Bottom sheet for creating new tasks with title and optional due date |
| F03 | Task Detail | tasks | P1 | Detail view with inline editing, status toggle, and notes |

---

## Feature Details

### F01 -- Task List

The main screen users see on app launch. Shows all tasks in a scrollable list.

**Key behaviors:**
- Pull-to-refresh reloads from server
- Filter tabs: All / Active / Completed
- Selected filter persists across app relaunches
- Swipe left reveals delete action with confirmation
- Empty state shown when no tasks exist
- Skeleton loading during initial fetch
- Overdue tasks highlighted with red due date
- Pagination: 20 tasks per page, load more on scroll

### F02 -- Create Task

A bottom sheet modal triggered by a floating action button on the task list.

**Key behaviors:**
- Title input with 100-character limit and live counter
- Optional due date picker (defaults to no due date)
- Save button disabled until title is non-empty
- Sheet dismissible by drag or tap outside (cancels creation)
- On success: dismiss sheet, new task appears at top of list
- On error: toast message, form preserved

### F03 -- Task Detail

Reached by tapping a task in the list. Shows full task information.

**Key behaviors:**
- Title and notes editable inline (auto-save with debounce)
- Checkbox toggles completion status (optimistic update)
- Due date changeable
- Shows creation date (read-only)
- Handles deleted-task scenario (404) gracefully

---

## Analytics Requirements

| Event | Trigger | Parameters |
|-------|---------|-----------|
| task_list_viewed | Task list screen appears | filter, task_count |
| task_filter_changed | User changes filter tab | from_filter, to_filter |
| task_deleted | User confirms deletion | task_id |
| create_task_sheet_opened | FAB tapped | - |
| task_created | Task saved successfully | has_due_date |
| task_detail_viewed | Detail screen appears | task_id, task_status |
| task_status_toggled | Checkbox tapped in detail | task_id, new_status |

---

## Key Dependencies

| Dependency | Owner | Status |
|-----------|-------|--------|
| Backend API (REST) | Backend team | In development |
| Figma design file | Design team | Complete |
| i18n translations (zh, ja) | Localization team | Complete |

---

## Non-Functional Requirements

- **Performance**: Task list must render within 300ms on mid-range devices
- **Offline**: Show cached data when offline; sync when back online
- **Accessibility**: VoiceOver / TalkBack support for all interactive elements
- **Minimum OS**: iOS 16+, Android API 26+
