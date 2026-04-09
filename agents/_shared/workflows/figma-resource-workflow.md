# Figma Resource Download Workflow

> Standard flow for downloading and managing Figma design resources.
> Uses Figma MCP (Model Context Protocol) server when available.
> Tool-agnostic: any AI tool with Figma access can follow this workflow.

---

## Prerequisites

| Requirement | Description |
|-------------|-------------|
| Figma file key | From {version}/config.yaml `figma.file_key` |
| Figma MCP server | Running and accessible (preferred method) |
| Node IDs | From Feature YAML `figma.pages[]` or `figma-index.md` |

---

## Resource Directory Structure

```
.claude/cache/{version}/figma/
  {section-name}/
    {node-id-normalized}.png       # Page screenshot
    {node-id-normalized}-detail.png # Zoomed detail (if needed)
  assets/
    {asset-name}.png               # Exported assets (icons, images)
  _manifest.json                   # Resource manifest
```

Node ID normalization: replace `:` with `-` (e.g., `119:370` -> `119-370`).

---

## Download Flow

### Step 1: Resolve Node IDs

```yaml
sources:
  primary:
    - Feature YAML figma.pages[] -> node_id list
    - Each entry has: name, node_id, usage

  supplementary:
    - {version}/figma-index.md -> section/page/node-id mapping
    - Cross-check: pages in figma-index not in Feature YAML = potential omission

  version_config:
    - {version}/config.yaml -> figma.file_key

output:
  - Deduplicated list of node IDs to download
  - file_key for Figma API calls
```

### Step 2: Check Cache

```yaml
for each node_id:
  cache_path = .claude/cache/{version}/figma/{section}/{node-id-normalized}.png
  if cache_path exists and is recent (< 24h):
    mark as cached, skip download
  else:
    add to download queue
```

### Step 3: Download Screenshots

```yaml
method_1_mcp:  # preferred
  - Use Figma MCP tool: get_figma_image(file_key, node_id)
  - Save to cache_path
  - Record in _manifest.json

method_2_api:  # fallback if MCP unavailable
  - Figma REST API: GET /v1/images/{file_key}?ids={node_id}&format=png
  - Download image from returned URL
  - Save to cache_path

method_3_manual:  # last resort
  - Output Figma URL for manual screenshot
  - URL format: https://www.figma.com/design/{file_key}?node-id={node_id}
  - User saves screenshot to cache_path

error_handling:
  - MCP timeout -> retry once, then fall back to method_2
  - API rate limit -> wait and retry
  - Node not found -> warn "node {node_id} not found in Figma file"
  - Network error -> mark as "missing (network error)" in manifest
```

### Step 4: Extract Design Tokens (optional)

When Figma MCP supports node inspection:

```yaml
for each downloaded node:
  extract:
    - Dimensions (width, height)
    - Spacing (padding, margin, gaps)
    - Typography (font family, size, weight, line height)
    - Colors (fill, stroke, text color)
    - Corner radius
    - Shadow/blur effects

  output:
    - Pixel baseline values for ui_contract
    - Key tokens for verification evidence
```

### Step 5: Export Assets (when needed)

```yaml
trigger:
  - Feature requires custom icons or images
  - Asset not already in project resource directory

steps:
  1. Identify exportable nodes from Figma (icons, illustrations, images)
  2. Export at required scales:
     iOS: @1x, @2x, @3x
     Android: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi
  3. Save to:
     .claude/cache/{version}/figma/assets/{asset-name}@{scale}.png
  4. Copy to project resource directory as needed

naming:
  - Use snake_case for asset filenames
  - Prefix with feature/module scope: {module}_{asset_name}
  - Example: chat_send_button.png, profile_avatar_placeholder.png
```

### Step 6: Update Manifest

```yaml
manifest_path: .claude/cache/{version}/figma/_manifest.json

format:
  {
    "file_key": "{figma_file_key}",
    "downloaded_at": "{ISO_TIMESTAMP}",
    "pages": [
      {
        "node_id": "{node_id}",
        "name": "{page_name}",
        "feature": "F{nn}",
        "cache_path": "{relative_path}",
        "status": "cached | missing | stale"
      }
    ],
    "assets": [
      {
        "name": "{asset_name}",
        "node_id": "{node_id}",
        "scales": ["1x", "2x", "3x"],
        "cache_path": "{relative_path}"
      }
    ]
  }
```

---

## Cross-Validation with Feature YAML

After downloading, verify completeness:

```
For each Feature being executed:
  1. Read Feature YAML figma.pages[]
  2. Check each node_id has a cached screenshot
  3. Missing screenshots -> warn in execution log Gate Check:
     "Figma baseline image: missing ({reason})"
  4. Check figma-index.md for pages not referenced in Feature YAML:
     Found omission -> auto-append to Feature YAML with source: figma-index
     Output: "+ F{nn}: added {node_id} {page-name}"
```

---

## Usage During Task Execution

During the Collect phase of task execution:

```
1. Run this workflow to ensure all Figma resources are cached
2. Reference cached screenshots for:
   - Understanding layout structure and visual design
   - Extracting pixel-precise dimensions for ui_contract
   - Comparing implementation screenshots against baseline
3. Record Figma baseline paths in execution log:
   "Figma baseline screenshot: .claude/cache/{version}/figma/{path}"
```

---

## Cache Management

```yaml
cache_policy:
  - Screenshots older than 7 days: mark as stale (re-download on next use)
  - Assets: persist until version is complete
  - Cleanup: after /spec-drive done, cache can be removed

  gitignore:
    - .claude/cache/ should be in .gitignore
    - Cache is local per machine, not committed
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MCP server not running | Fall back to Figma REST API or manual screenshot |
| Node ID not found | Check figma-index.md for updated node IDs; Figma redesign may have changed them |
| Wrong screenshot (shows parent frame) | Use more specific child node ID |
| Low resolution screenshot | Re-download at higher scale factor |
| Rate limited by Figma API | Wait 60s and retry; batch requests if many nodes |
