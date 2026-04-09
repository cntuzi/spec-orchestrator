# Multi-Platform Agent Architecture

> How spec-orchestrator manages AI agent configurations across iOS, Android, and future platforms.

---

## 1. Problem Statement

Each platform repository (iOS, Android, Web) needs an AI agent configuration layer:
- Coding conventions (`ai/*.md`)
- Slash commands (`.claude/commands/`)
- Workflows (`.claude/workflows/`)
- Entry points (`CLAUDE.md`, `AGENTS.md`)
- Project config (`.claude/config.yaml`)

Without a shared system, these files diverge across repositories. Cross-platform conventions (git workflow, spec-driven task protocol, i18n rules) get duplicated and go out of sync. Platform-specific rules (Xcode vs Gradle, SwiftUI vs Compose) need dedicated files.

---

## 2. Current State Analysis

### Shared across all platforms
| Category | Files | Purpose |
|----------|-------|---------|
| Commands | `spec-next.md`, `spec-drive.md` | Spec-driven task execution |
| Workflows | `spec-protocol.md`, `execution-log.template.md` | Execution protocol and logging |
| AI rules | `git.md`, `workflow.md`, `tricks.md`, `api.md` | Git, workflow, API conventions |

### Platform-specific
| Category | iOS | Android |
|----------|-----|---------|
| Conventions | `ai/ios.md` | `ai/android.md` |
| UI rules | `ai/ui.md` (SwiftUI) | `ai/ui.md` (Compose) |
| Entry point | `CLAUDE.md` (xcodebuild) | `CLAUDE.md` (gradlew) |
| Agent entry | `AGENTS.md` (CocoaPods) | `AGENTS.md` (Gradle) |
| Config | `.claude/config.yaml` | `.claude/config.yaml` |
| Skills | `.claude/skills/` | `.claude/skills/` |

---

## 3. Target Architecture

```
agents/
|
+-- _shared/                          Cross-platform (copied to all repos)
|   +-- commands/
|   |   +-- spec-next.md              Task execution command
|   |   +-- spec-drive.md             Orchestration command (optional)
|   +-- workflows/
|   |   +-- spec-protocol.md          Execution protocol
|   |   +-- execution-log.template.md Log template
|   +-- ai/
|       +-- git.md                    Git conventions
|       +-- workflow.md               Workflow conventions
|       +-- tricks.md                 Common tricks and rules
|       +-- api.md                    API development conventions
|
+-- ios/                              iOS-specific layer
|   +-- .claude/
|   |   +-- config.yaml               iOS project config template
|   |   +-- commands/                  iOS-only commands (if any)
|   |   +-- workflows/                iOS-only workflows (if any)
|   |   +-- skills/                   iOS-only skills
|   |   +-- scripts/                  iOS-only scripts
|   +-- ai/
|   |   +-- ios.md                    iOS coding conventions
|   |   +-- ui.md                     SwiftUI/UIKit conventions
|   +-- CLAUDE.md                     Claude Code entry (xcodebuild, pods)
|   +-- AGENTS.md                     Codex CLI entry (iOS)
|
+-- android/                          Android-specific layer
|   +-- .claude/
|   |   +-- config.yaml               Android project config template
|   |   +-- commands/                  Android-only commands (if any)
|   |   +-- workflows/                Android-only workflows (if any)
|   |   +-- skills/                   Android-only skills
|   +-- ai/
|   |   +-- android.md                Android coding conventions
|   |   +-- ui.md                     Compose/Material3 conventions
|   +-- CLAUDE.md                     Claude Code entry (gradlew)
|   +-- AGENTS.md                     Codex CLI entry (Android)
|
+-- sync.sh                           Deployment script
+-- ARCHITECTURE.md                   This document
```

---

## 4. Shared Layer Inheritance

The sync script (`sync.sh`) implements a simple overlay merge:

```
_shared/          Base layer (copied first)
    |
platform/         Override layer (copied second, same-name files win)
    |
target repo/      Final result (shared + platform-specific)
```

### Merge Rules

1. **Shared files are copied first** -- they form the baseline.
2. **Platform files are copied second** -- any file with the same relative path replaces the shared version.
3. **Entry points are platform-only** -- `CLAUDE.md` and `AGENTS.md` are never shared; each platform defines its own.
4. **Config is always platform-specific** -- `.claude/config.yaml` comes from the platform directory only.

### Example: sync android to target

```bash
./agents/sync.sh android ../my-android-app 1.3

# Result in ../my-android-app/:
#
# .claude/
#   config.yaml              <- from agents/android/.claude/config.yaml (version injected)
#   commands/
#     spec-next.md           <- from agents/_shared/commands/
#   workflows/
#     spec-protocol.md       <- from agents/_shared/workflows/
# ai/
#   git.md                   <- from agents/_shared/ai/
#   workflow.md              <- from agents/_shared/ai/
#   android.md               <- from agents/android/ai/
#   ui.md                    <- from agents/android/ai/ (overrides _shared/ai/ui.md if it existed)
# CLAUDE.md                  <- from agents/android/CLAUDE.md
# AGENTS.md                  <- from agents/android/AGENTS.md
```

---

## 5. Per-Platform Agent Planning

### iOS Agent
- **Build tool**: xcodebuild (workspace-based, CocoaPods or SPM).
- **UI framework**: SwiftUI (new screens) + UIKit (legacy).
- **Key conventions**: 4-space indent, PascalCase types, lowerCamelCase members, `@testable import` for unit tests.
- **Build verification**: `xcodebuild -workspace ... -scheme ... build` or custom `./scripts/build.sh`.
- **i18n**: `Localizable.strings` per .lproj directory.

### Android Agent
- **Build tool**: Gradle via `./gradlew` wrapper.
- **UI framework**: Jetpack Compose (new screens) + XML Views (legacy).
- **Key conventions**: 4-space indent, Kotlin idioms, sealed classes for UI state, Hilt DI.
- **Build verification**: `./gradlew assembleDebug`.
- **i18n**: `strings.xml` per `values-{locale}/` directory.

### Future: Web Agent
- **Build tool**: npm/pnpm + Vite/Next.js.
- **UI framework**: React + TypeScript.
- **Key conventions**: 2-space indent, ESLint + Prettier, functional components.
- **Build verification**: `npm run build` or `pnpm build`.
- **i18n**: JSON locale files or i18next.

To add a new platform:
1. Create `agents/{platform}/` with the same structure as `ios/` or `android/`.
2. Add platform-specific `ai/{platform}.md`, `ai/ui.md`, `CLAUDE.md`, `AGENTS.md`, `.claude/config.yaml`.
3. Run `./agents/sync.sh {platform} ../target-repo`.

---

## 6. Integration with spec-drive

The agent configuration feeds into the spec-drive orchestration pipeline:

```
spec-orchestrator/
|
+-- .claude/commands/
|   +-- spec-drive.md          Reads platforms from config, dispatches Workers
|   +-- spec-init.md           Generates spec skeleton
|
+-- agents/                    Agent configuration templates (this system)
|   +-- sync.sh                Deploys config to platform repos
|
+-- {project}/{version}/       Spec layer (features, tasks, i18n, etc.)

Platform repo (after sync):
|
+-- .claude/
|   +-- config.yaml            Points to specs path, version, platform
|   +-- commands/spec-next.md  Worker execution protocol
+-- ai/                        Coding conventions
+-- CLAUDE.md                  Entry point
+-- specs/ -> ../specs/{project}  Symlink to spec repository
```

### Worker Execution Flow

1. **spec-drive** reads `spec-orchestrator/.claude/config.yaml` to identify platform repos.
2. **spec-drive** creates worktree in the platform repo and launches a Worker.
3. **Worker** reads platform repo's `.claude/config.yaml` to find spec paths.
4. **Worker** follows `spec-next.md` protocol: lock task, collect context, implement, build, update.
5. **Worker** uses `ai/{platform}.md` and `ai/ui.md` for coding standards.

---

## 7. Implementation Roadmap

### Phase 1: Templates (current)
- [x] Define `agents/` directory structure.
- [x] Create Android agent template (`config.yaml`, `android.md`, `ui.md`, `CLAUDE.md`, `AGENTS.md`).
- [ ] Create iOS agent template (mirror from existing iOS project configs).
- [ ] Populate `_shared/` with cross-platform commands and conventions.

### Phase 2: Sync Script
- [x] Implement `sync.sh` with overlay merge logic.
- [ ] Add `--dry-run` flag for preview without file changes.
- [ ] Add `--diff` flag to show what would change vs current target state.
- [ ] Add placeholder replacement (`{PROJECT_NAME}`, `{PROJECT_DESCRIPTION}`).

### Phase 3: Automation
- [ ] Integrate `sync.sh` into `scripts/init.sh` for new project setup.
- [ ] Add version bump propagation (update all platform config.yaml versions).
- [ ] Git hooks to warn when agent files change without re-syncing.

### Phase 4: Additional Platforms
- [ ] Web agent template (React + TypeScript).
- [ ] Backend agent template (if needed for API-first development).
- [ ] Flutter agent template (single codebase, dual platform).

---

## 8. File Inventory

| File | Type | Purpose |
|------|------|---------|
| `agents/_shared/commands/*.md` | Shared | Spec-driven slash commands |
| `agents/_shared/workflows/*.md` | Shared | Execution protocols |
| `agents/_shared/ai/*.md` | Shared | Cross-platform conventions (git, workflow, API) |
| `agents/{platform}/.claude/config.yaml` | Template | Platform project config with placeholders |
| `agents/{platform}/ai/{platform}.md` | Platform | Language and architecture conventions |
| `agents/{platform}/ai/ui.md` | Platform | UI framework conventions |
| `agents/{platform}/CLAUDE.md` | Platform | Claude Code entry point |
| `agents/{platform}/AGENTS.md` | Platform | Codex CLI entry point |
| `agents/sync.sh` | Script | Deploy agent config to target repository |
| `agents/ARCHITECTURE.md` | Docs | This architecture document |
