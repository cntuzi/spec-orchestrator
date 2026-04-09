# Figma Index -- Todo App v1.0

> Design page index. Each entry maps a Figma node ID to a specific design state.
> Feature YAMLs reference these node IDs. Auto-generated via Figma MCP.

**File key**: `YOUR_FIGMA_FILE_KEY`
**Base URL**: `https://www.figma.com/design/YOUR_FIGMA_FILE_KEY`

---

## Section: Task List

| Node ID | Page Name | Description |
|---------|-----------|-------------|
| 100:200 | Task List - Default | Main list with mixed active/completed tasks |
| 100:300 | Task List - Empty State | No tasks, illustration + CTA |
| 100:400 | Task List - Loading Skeleton | Shimmer skeleton cells during fetch |
| 100:500 | Task List - Swipe Delete | Left-swipe reveals delete action |

## Section: Create Task

| Node ID | Page Name | Description |
|---------|-----------|-------------|
| 200:100 | Create Task - Empty | Bottom sheet with empty form |
| 200:200 | Create Task - Filled | Bottom sheet with title and due date filled |

## Section: Task Detail

| Node ID | Page Name | Description |
|---------|-----------|-------------|
| 300:100 | Task Detail - Active | Detail view for an uncompleted task |
| 300:200 | Task Detail - Completed | Detail view for a completed task (strikethrough) |

---

## Coverage Summary

| Section | Pages | Referenced by Features |
|---------|-------|-----------------------|
| Task List | 4 | F01 |
| Create Task | 2 | F02 |
| Task Detail | 2 | F03 |
| **Total** | **8** | **3 features** |

All pages referenced. No orphan pages.

---

## Usage

### Get page details
```
Figma MCP: get_figma_data
- fileKey: YOUR_FIGMA_FILE_KEY
- nodeId: <Node ID from table above>
- depth: 3
```

### Download page screenshot
```
Figma MCP: download_figma_images
- fileKey: YOUR_FIGMA_FILE_KEY
- nodes: [{ nodeId: "<Node ID>", fileName: "<name>.png" }]
- localPath: .claude/cache/1.0/figma/
- pngScale: 2
```
