#!/usr/bin/env bash
# init.sh — Initialize a new project in the spec-orchestrator repo
# Usage: ./scripts/init.sh <project-name> [version]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Parse arguments ---
PROJECT="${1:-}"
VERSION="${2:-1.0}"

if [ -z "$PROJECT" ]; then
  echo "Usage: ./scripts/init.sh <project-name> [version]"
  echo ""
  echo "Example:"
  echo "  ./scripts/init.sh my-app"
  echo "  ./scripts/init.sh my-app 2.0"
  exit 1
fi

PROJECT_DIR="$REPO_ROOT/$PROJECT"
VERSION_DIR="$PROJECT_DIR/$VERSION"

if [ -d "$VERSION_DIR" ]; then
  echo "Error: $VERSION_DIR already exists."
  echo "Use /spec-init $VERSION refresh to update incrementally."
  exit 1
fi

echo "Initializing $PROJECT v$VERSION..."
echo ""

# --- Create directory structure ---
mkdir -p "$VERSION_DIR"/{prd,features,tasks,i18n,implementation/{ios,android}}

# --- Generate config.yaml ---
cat > "$VERSION_DIR/config.yaml" << EOF
version: "$VERSION"
codename: ""

figma:
  file_key: ""
  base_url: ""

paths:
  prd: "prd/"
  figma_index: "figma-index.md"
  i18n: "i18n/strings.md"
  features: "features/"
  dashboard: "DASHBOARD.md"
  changelog: "CHANGELOG.md"
  tasks:
    shared: "tasks/shared.md"
    backend: "tasks/backend.md"
    ios: "tasks/ios.md"
    android: "tasks/android.md"

api:
  swagger_files: []

features: []

dependency_index:
  api_to_features: {}
  figma_to_features: {}
  feature_to_backend: {}
EOF

# --- Generate shared.md ---
cat > "$VERSION_DIR/tasks/shared.md" << EOF
# v$VERSION Shared Prerequisites

## Dependency Check

| ID | Item | Status | Notes |
|----|------|--------|-------|
| S1 | PRD Confirmed | :red_circle: | |
| S2 | Design Reviewed | :red_circle: | |
| S3 | API Defined | :red_circle: | |
EOF

# --- Generate backend.md ---
cat > "$VERSION_DIR/tasks/backend.md" << EOF
# v$VERSION Backend API Dependencies

## Metadata

| Field | Value |
|-------|-------|
| **Version** | $VERSION |
| **Swagger Dir** | api-doc/ |

## API Readiness Timeline

| ID | API | Blocking Feature | Status |
|----|-----|-----------------|--------|

(No backend APIs defined yet. Run /spec-init to auto-generate from Swagger.)
EOF

# --- Generate ios.md ---
cat > "$VERSION_DIR/tasks/ios.md" << EOF
# v$VERSION iOS Task Plan

## Metadata

| Field | Value |
|-------|-------|
| **Version** | $VERSION |
| **Platform** | iOS |
| **Created** | $(date +%Y-%m-%d) |

## Dependency Check

| Dependency | Status |
|-----------|--------|
| S1 PRD Confirmed | :red_circle: |
| S2 Design Reviewed | :red_circle: |
| S3 API Defined | :red_circle: |

## Task Overview

| ID | Module | Task | Feature | Priority | Status | Dependencies |
|----|--------|------|---------|----------|--------|-------------|

**Stats**: 0 tasks | :red_circle: Pending: 0 | :large_blue_circle: In Progress: 0 | :green_circle: Completed: 0

(Run /spec-init to auto-generate tasks from PRD.)
EOF

# --- Generate android.md ---
cat > "$VERSION_DIR/tasks/android.md" << EOF
# v$VERSION Android Task Plan

## Metadata

| Field | Value |
|-------|-------|
| **Version** | $VERSION |
| **Platform** | Android |
| **Created** | $(date +%Y-%m-%d) |

## Dependency Check

| Dependency | Status |
|-----------|--------|
| S1 PRD Confirmed | :red_circle: |
| S2 Design Reviewed | :red_circle: |
| S3 API Defined | :red_circle: |

## Task Overview

| ID | Module | Task | Feature | Priority | Status | Dependencies |
|----|--------|------|---------|----------|--------|-------------|

**Stats**: 0 tasks | :red_circle: Pending: 0 | :large_blue_circle: In Progress: 0 | :green_circle: Completed: 0

(Run /spec-init to auto-generate tasks from PRD.)
EOF

# --- Generate i18n/strings.md ---
cat > "$VERSION_DIR/i18n/strings.md" << EOF
# $PROJECT v$VERSION Internationalization

> Single source of truth for all i18n strings.
> Add strings when each feature completes, no separate scheduling.

### Platform Format Conversion

| Generic | iOS | Android | Example |
|---------|-----|---------|---------|
| %s | %@ | %s | Username |
| %d | %d | %d | Number |
| %1\$s | %1\$@ | %1\$s | First param |

(Run /spec-init to auto-generate strings from PRD.)
EOF

# --- Generate CHANGELOG.md ---
cat > "$VERSION_DIR/CHANGELOG.md" << EOF
# v$VERSION Change Log

> CR (Change Request) numbers are globally incrementing.
> Types: PRD / Figma / API / i18n / Feature / Requirement / Workflow
> Status: Done / Partial / Pending

---

(No CR entries - initial version)
EOF

# --- Generate empty figma-index.md ---
cat > "$VERSION_DIR/figma-index.md" << EOF
# Figma Page Index - v$VERSION

## Basic Info
- **Figma File**: (not configured)
- **File Key**: \`\`
- **Version**: $VERSION
- **Created**: $(date +%Y-%m-%d)

---

(Run /spec-init with a Figma file key to auto-generate the page index.)
EOF

# --- Generate .gitkeep files ---
touch "$VERSION_DIR/implementation/ios/.gitkeep"
touch "$VERSION_DIR/implementation/android/.gitkeep"

# --- Generate PRD placeholder ---
cat > "$VERSION_DIR/prd/README.md" << EOF
# v$VERSION Product Requirements

> Place your PRD here (Markdown preferred, PDF supported).
> Then run /spec-init $VERSION to auto-generate feature specs.

## Version Info

| Field | Value |
|-------|-------|
| Version | $VERSION |
| Codename | |
| Test Date | |

## Features

(Define your features here, then run /spec-init to generate Feature YAMLs.)
EOF

# --- Update repo-level config.yaml ---
if [ -f "$REPO_ROOT/.claude/config.yaml" ]; then
  echo "Note: .claude/config.yaml already exists. Update project.name and version.current manually if needed."
else
  mkdir -p "$REPO_ROOT/.claude"
  cat > "$REPO_ROOT/.claude/config.yaml" << EOF
# Spec Orchestrator Configuration
project:
  name: $PROJECT

version:
  current: "$VERSION"

platforms:
  ios:
    repo: ../${PROJECT}_ios
    build_cmd: ./scripts/build.sh
  android:
    repo: ../${PROJECT}_android
    build_cmd: ./gradlew assembleDebug

branch:
  pattern: "feat/{project}/{version}"
EOF
fi

# --- Summary ---
echo "Done! Created project structure:"
echo ""
echo "  $PROJECT/$VERSION/"
echo "  ├── config.yaml"
echo "  ├── prd/README.md"
echo "  ├── features/              (empty, run /spec-init to generate)"
echo "  ├── tasks/"
echo "  │   ├── shared.md"
echo "  │   ├── backend.md"
echo "  │   ├── ios.md"
echo "  │   └── android.md"
echo "  ├── i18n/strings.md"
echo "  ├── figma-index.md"
echo "  ├── CHANGELOG.md"
echo "  └── implementation/"
echo ""
echo "Next steps:"
echo "  1. Add your PRD to $PROJECT/$VERSION/prd/"
echo "  2. Run /spec-init $VERSION to auto-generate feature specs"
echo "  3. Run /spec-drive setup to create version branches"
echo "  4. Run /spec-drive next to start development"
