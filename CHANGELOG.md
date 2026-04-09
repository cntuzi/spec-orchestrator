# Changelog

## [0.2.0] - 2026-04-02

### Added
- **Capability system**: i18n, analytics, dark_mode, accessibility as pluggable capabilities
  - Declared at version-level in context.yaml, referenced at feature-level in Feature YAML
  - Each capability hooks into init/collect/execute/verify phases
- **Project bootstrap** (Step 1.5): scan platform repos to generate PROJECT.md with architecture overview
- **Backend Code Scan** (Step 5.5): discover existing API endpoints when Swagger unavailable
- **scope-change mode**: cascade feature removal/modification across all spec files
- **sync.sh --fill**: auto-fill agent template placeholders from PROJECT.md
- **build_prerequisites**: declare environment requirements in context.yaml
- Worker execution flag documentation (`--dangerously-skip-permissions`)

### Changed
- Feature ID validation relaxed: gaps allowed after scope-change (warn instead of error)
- i18n extracted from core pipeline into capability system (opt-in, not default)
- analytics moved to capability system (enabled by default)

## [0.1.0] - 2026-04-01

### Added
- **Context Manifest**: `context.yaml` for declarative external dependency management
  - Logical repo IDs + version pins, no filesystem paths
  - `resolve-context.sh`: 5-strategy resolution chain (env var -> symlink -> git-worktree-discovery -> hint -> prompt)
  - `.context-resolved.yaml` output with absolute paths (gitignored)
  - Drift detection: pin.commit vs current commit comparison
- Integration into spec-init, spec-drive, spec-next

## [0.0.1] - 2026-03-31

### Added
- Initial framework release
- Three-layer architecture: spec-init (generation) -> spec-drive (orchestration) -> spec-next (execution)
- Feature YAML schema with What + Constraint structure
- Task file format with status lifecycle (pending -> in-progress -> done -> rework)
- Dependency index for impact analysis (api_to_features, figma_to_features, feature_to_backend)
- Change management: CR recording + propagation
- Multi-platform agent templates (iOS, Android) with sync.sh
- Execution log template + workflow protocol
- Complete documentation (tutorial, architecture, glossary, exec-protocol)
- Example project (todo-app)
