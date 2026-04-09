# Figma Page Index - {VERSION}

## Basic Info
- **Figma File**: [{PROJECT_NAME}]({FIGMA_URL})
- **File Key**: `{FIGMA_FILE_KEY}`
- **Version**: {VERSION}
- **Created**: {DATE}
- **Exclusion Scope**: {EXCLUDE_DESCRIPTION}

---

## Page Structure

### 1. {SECTION_NAME} (Section: `{SECTION_NODE_ID}`)

| # | Page Name | Node ID | Usage |
|---|-----------|---------|-------|
| 1 | {PAGE_NAME} | `{PAGE_NODE_ID}` | {PAGE_DESCRIPTION} |

**Excluded**:
- ~~{EXCLUDED_PAGE} (`{EXCLUDED_NODE_ID}`)~~

---

## Statistics

| Section | Pages | Excluded |
|---------|-------|----------|
| {SECTION_NAME} | {COUNT} | {EXCLUDED_COUNT} |
| **Total** | **{TOTAL}** | **{TOTAL_EXCLUDED}** |

---

## Usage

### Get Single Page Details
```
mcp__figma-developer__get_figma_data
- fileKey: {FIGMA_FILE_KEY}
- nodeId: <Page Node ID>
- depth: 3
```

### Download Page Screenshots
```
mcp__figma-developer__download_figma_images
- fileKey: {FIGMA_FILE_KEY}
- nodes: [{ nodeId: "<Node ID>", fileName: "<name>.png" }]
- localPath: .claude/cache/{VERSION}/figma/<section-name>/
- pngScale: 2
```

### Quick Access Links
- [{SECTION_NAME}]({FIGMA_URL}?node-id={SECTION_NODE_ID})
