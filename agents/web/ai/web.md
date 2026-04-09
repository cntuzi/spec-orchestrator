# Web Frontend Coding Conventions

> Tool-agnostic Web project constraints. All AI tools (Codex CLI, Claude Code, Cursor, Copilot, etc.) must follow these rules when modifying frontend code.

## Project Overview

- **Language**: TypeScript (strict mode). No `any` unless wrapping untyped third-party code.
- **Framework**: {FRAMEWORK} (e.g., React 18 / Vue 3 / Next.js / Nuxt)
- **Build tool**: {BUILD_TOOL} (e.g., Vite / Next.js / Webpack)
- **Package manager**: {PACKAGE_MANAGER} (e.g., pnpm / npm / yarn)
- **Styling**: {STYLING} (e.g., Tailwind CSS / CSS Modules / styled-components)
- **State management**: {STATE_MANAGEMENT} (e.g., Zustand / Redux Toolkit / Pinia)
- **Node version**: >= 18

---

## Code Style (mandatory)

### Formatting
- Indentation: 2 spaces, no tabs.
- Line length: 100 characters max.
- Semicolons: consistent with project config (Prettier / ESLint).
- Trailing commas: always in multi-line.

### Naming
| Element | Convention | Example |
|---------|-----------|---------|
| Component | PascalCase | `ChatBubble`, `UserProfile` |
| Function / variable | camelCase | `fetchMessages`, `isLoading` |
| Constant | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| CSS class (Tailwind) | kebab-case via utility | `text-sm font-bold` |
| CSS class (Modules) | camelCase | `styles.chatBubble` |
| File (component) | PascalCase | `ChatBubble.tsx` |
| File (utility) | camelCase | `formatDate.ts` |
| Directory | kebab-case | `chat-feature/` |

### TypeScript
- Prefer `interface` for object shapes, `type` for unions and intersections.
- Use discriminated unions for state modeling.
- No `as` type assertions unless interfacing with untyped APIs.
- Explicit return types on exported functions.

---

## Component Rules

### Structure (React)
```tsx
interface Props {
  title: string;
  onSubmit: (data: FormData) => void;
}

export function FeatureCard({ title, onSubmit }: Props) {
  // hooks first
  // derived state
  // handlers
  // render
}
```

### Guidelines
- Functional components only. No class components in new code.
- One component per file. Co-locate styles, tests, and types.
- Extract reusable components into `src/components/`.
- Feature-specific components stay in `src/features/{feature}/components/`.
- Keep components under 200 lines. Extract logic into custom hooks.

---

## i18n Rules (mandatory)

- No hardcoded user-facing strings in source files.
- All strings go through the project's i18n system (e.g., `react-intl`, `i18next`, `vue-i18n`).
- Interpolation variables must match across all locales.
- When adding new UI text, add the key to all locale files simultaneously.

---

## Layout Rules (mandatory)

- Use CSS Grid or Flexbox for layout. No `float` for structural layout.
- Responsive: mobile-first approach. Design for 375px minimum width.
- Spacing: use design tokens (CSS custom properties or Tailwind spacing scale).
- Standard spacing: page margin 16px / component gap 12px / element gap 8px.
- Touch targets: >= 44px on touch devices.

---

## Asset Rules

- SVG for icons and simple graphics (inline or as components).
- WebP for photos and complex images with PNG fallback.
- All images must have `alt` text for accessibility.
- Use `next/image` or equivalent optimized image component when available.
- Lazy-load below-the-fold images.

---

## Build Verification (mandatory)

After every change, run:
```bash
# Replace with your project's commands
{PACKAGE_MANAGER} run build         # Must succeed with zero errors
{PACKAGE_MANAGER} run lint          # Must pass
{PACKAGE_MANAGER} run typecheck     # Must pass (tsc --noEmit)
```

Build loop: modify -> build -> fix errors -> build again. Never accumulate errors.

Keep change scope minimal. Do not refactor unrelated code incidentally.

---

## API Integration

- Use a typed API client (e.g., `fetch` wrapper with generics, `axios` with interceptors).
- API response types must match backend Swagger/OpenAPI definitions.
- Handle loading, error, and empty states for every API call.
- Use `react-query` / `swr` / `tanstack-query` for server state management.

---

## Testing

```bash
{PACKAGE_MANAGER} run test              # Unit tests
{PACKAGE_MANAGER} run test:e2e          # E2E tests (Playwright / Cypress)
```

- Unit test all utility functions and custom hooks.
- Component tests for critical user flows.
- E2E tests for full page interactions.

---

## Git Conventions

- **Commit format**: `type(scope): subject`
- **Types**: feat, fix, refactor, style, test, docs, chore, perf.
- **Subject**: imperative mood, no period, under 72 characters.
- Reference tasks: `Refs T01` or `Closes T01`.

---

## Worktree Environment

External paths (specs, api-doc) are resolved via `.context-resolved.yaml`.
If missing, run `bash {specs_repo}/scripts/resolve-context.sh` to auto-detect paths.
Legacy `specs` symlink still works as fallback.
