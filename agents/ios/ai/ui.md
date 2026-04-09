# UI Development Conventions

> Rules for Figma resource handling, design analysis, and UI implementation on iOS.

## Core Principle

**Analyze the design first. Do not blindly reuse historical code.**

Every UI task starts by reading the design spec, not by copying existing implementations that may be outdated or incorrect.

## Small UI Task Principles

For minor UI changes (spacing, color, font, single-element tweaks):
1. Identify the exact element in the design
2. Locate the corresponding source file
3. Make the minimal change
4. Build and verify

Do not restructure unrelated views while making small fixes.

## Figma Resource Download (mandatory)

### Image Format

1. **PNG only** -- SVG is forbidden on iOS
   - SVG: no native support, requires extra dependencies, poor rendering performance
   - PNG: native support, Asset Catalog auto-selects resolution
2. **Reference the design screenshot**: if a design image or screenshot is provided, identify the required assets from the screenshot to avoid downloading wrong nodes from a cluttered Figma file
3. **Storage location**: download images into the `xcassets` directory, creating the appropriate `.imageset` folder

### Download Flow

1. Retrieve design data from Figma (via MCP tool or API)
2. Cross-reference with the design screenshot to identify the correct image nodes
3. Download as PNG at 2x and 3x scales
4. **File name must end with `.png`** -- never `.svg`
5. Place images in `Assets.xcassets` under the matching `.imageset` directory and create `Contents.json`

### Figma Asset Pitfall Guide

| Problem | How to Identify | Strategy |
|---------|----------------|----------|
| Hidden/deprecated layers | `visible: false` or off-canvas | Ignore; only use visible nodes inside the main artboard |
| Duplicate assets | Same `imageRef` or similar naming | Deduplicate; prefer the version with a clean, standard name |
| Drafts/backups | Name contains `copy`, `backup`, `old`, `v1` | Ignore; use the formally named version |
| Component variants | Same component, multiple states | Confirm which states are needed; download selectively |
| Deeply nested nodes | Many layers of Frame/Group wrappers | Navigate to the actual image node, not the container |
| Placeholder images | Name contains `placeholder`, abnormal size | Ignore; wait for final assets |

### Composite Asset Handling (vector icons / combined shapes)

When an icon is composed of multiple sub-elements (path/vector/shape):

**Identifying characteristics**:
- Parent node type is `COMPONENT`, `INSTANCE`, `FRAME`, or `GROUP`
- Contains multiple `VECTOR`, `RECTANGLE`, `ELLIPSE` child nodes
- Parent size matches standard icon sizes (16/20/24/32/40/48pt)
- Name has `ic_`, `icon_`, `ico-` prefix

**Export strategy**:
- Export the **parent container node** (merged into one image)
- Do NOT export individual child elements (produces fragments)

**Priority order**:
```
Design screenshot comparison > Parent node naming > Standard icon size > Node type
```

**When uncertain**: ask the user, providing node name, size, and child element count.

**Key rule**: the design screenshot is the single source of truth; Figma data is merely the download channel.

## 6-Dimension Design Analysis (mandatory)

Before implementing any UI, analyze the design across these dimensions:

| Dimension | Key Questions |
|-----------|--------------|
| **Structure** | What contains what? VC -> View -> Cell hierarchy |
| **Semantics** | Title / body / button type? Map to UI components |
| **State** | Default / pressed / disabled / loading / empty / error? |
| **Responsiveness** | Fixed or adaptive? Small screen compression? Text truncation? |
| **Interaction** | Tap / swipe / long-press? Pull-to-refresh / load-more? |
| **Animation** | Enter / exit / transition effects? |

## Pitfall Checklist

- Do NOT copy historical code blindly (it may be a flawed implementation)
- Do NOT assume the design is complete (proactively ask about missing states)
- Do NOT treat Figma layer structure as code structure
- DO analyze first, then code; when uncertain, ask
