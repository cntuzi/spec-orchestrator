# Web UI Development Conventions

> Rules for Figma resource handling, design analysis, and UI implementation on Web.

## Core Principle

**Analyze the design first. Do not blindly reuse historical code.**

Every UI task starts by reading the design spec, not by copying existing implementations that may be outdated or incorrect.

---

## Small UI Task Principles

For minor UI changes (spacing, color, font, single-element tweaks):
1. Identify the exact element in the design.
2. Locate the corresponding source file.
3. Make the minimal change.
4. Build and verify.

Do not restructure unrelated components while making small fixes.

---

## Figma Resource Download (mandatory)

### Image Format

1. **SVG** for icons and vector graphics (inline or as React components).
2. **WebP** for photos and complex images; PNG as fallback.
3. **Reference the design screenshot**: if a screenshot is provided, identify assets from it before downloading from Figma.
4. **Storage location**: `src/assets/` or `public/images/`, following project convention.

### Download Flow

1. Retrieve design data from Figma (via MCP tool or API).
2. Cross-reference with design screenshot to identify correct image nodes.
3. Export icons as SVG; export raster images as WebP/PNG.
4. Optimize SVGs (remove unnecessary metadata) via SVGO or equivalent.
5. For React projects, convert frequently used icons to React components.

### Figma Asset Pitfall Guide

| Problem | How to Identify | Strategy |
|---------|----------------|----------|
| Hidden/deprecated layers | `visible: false` or off-canvas | Ignore; use visible nodes only |
| Duplicate assets | Same `imageRef` or similar naming | Deduplicate; prefer clean name |
| Drafts/backups | Name contains `copy`, `backup`, `old`, `v1` | Ignore; use formal version |
| Component variants | Same component, multiple states | Confirm needed states; download selectively |
| Deeply nested nodes | Many Frame/Group wrappers | Navigate to actual image node |
| Placeholder images | Name contains `placeholder`, abnormal size | Ignore; wait for final assets |

---

## 6-Dimension Design Analysis (mandatory)

Before implementing any UI, analyze the design across these dimensions:

| Dimension | Key Questions |
|-----------|--------------|
| **Structure** | Page layout? Header/sidebar/content/footer? Grid system? |
| **Semantics** | Heading levels? ARIA roles? Semantic HTML tags? |
| **State** | Default / hover / active / focus / disabled / loading / empty / error? |
| **Responsiveness** | Breakpoints? Mobile/tablet/desktop layouts? Fluid vs fixed? |
| **Interaction** | Click / hover / scroll / drag? Keyboard navigation? |
| **Animation** | Transitions? Enter/exit? Scroll-triggered? Skeleton loading? |

---

## Responsive Design

### Breakpoints (customize per project)
```
mobile:  < 768px
tablet:  768px - 1024px
desktop: > 1024px
```

### Strategy
- Mobile-first: start with mobile layout, add complexity at larger breakpoints.
- Use relative units (`rem`, `%`, `vw/vh`) over fixed `px` for fluid layouts.
- Test at 375px, 768px, 1024px, 1440px minimum.
- Container queries for component-level responsiveness when supported.

---

## Accessibility (mandatory)

- All interactive elements must be keyboard accessible.
- Use semantic HTML (`button`, `nav`, `main`, `article`, not `div` for everything).
- All images must have `alt` text; decorative images use `alt=""`.
- Form inputs must have associated `label` elements.
- Color contrast: minimum 4.5:1 for body text, 3:1 for large text (WCAG AA).
- Focus indicators must be visible. Never `outline: none` without a replacement.

---

## Performance Checklist

- [ ] Code-split routes (lazy loading per page/feature).
- [ ] Images optimized and lazy-loaded below the fold.
- [ ] No unnecessary re-renders (React.memo, useMemo, useCallback where measured).
- [ ] Bundle size monitored; no oversized dependencies for simple tasks.
- [ ] Critical CSS inlined or loaded first.
- [ ] Web Vitals targets: LCP < 2.5s, FID < 100ms, CLS < 0.1.

---

## Pitfall Checklist

- Do NOT copy historical code blindly (it may be a flawed implementation).
- Do NOT assume the design is complete (proactively ask about missing states).
- Do NOT treat Figma layer structure as component structure.
- DO analyze first, then code; when uncertain, ask.
- DO test across browsers (Chrome, Safari, Firefox at minimum).
