#!/usr/bin/env bash
# sync.sh -- Sync agent configuration to a platform repository
#
# Usage:
#   ./agents/sync.sh <platform> <target_repo> [version]
#
# Examples:
#   ./agents/sync.sh ios ../my-ios-app 1.0
#   ./agents/sync.sh android ../my-android-app
#   ./agents/sync.sh android ../my-android-app 2.0
#
# What it does:
#   1. Copies _shared/commands/   -> target/.claude/commands/
#   2. Copies _shared/workflows/  -> target/.claude/workflows/
#   3. Copies _shared/ai/         -> target/ai/
#   4. Copies _shared/adapters/   -> target/.claude/adapters/
#   5. Overlays platform-specific files (same-name files override shared)
#   6. Copies CLAUDE.md to target root
#   7. Copies AGENTS.md to target root (includes Codex execution protocol)
#   8. Injects version into .claude/config.yaml
#   9. Prints summary of synced files
#
# The synced target repo works with BOTH Claude Code and Codex CLI:
#   - Claude Code: reads CLAUDE.md, auto-discovers .claude/commands/
#   - Codex CLI: reads AGENTS.md, follows .claude/commands/spec-next.md via reference

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="${SCRIPT_DIR}/_shared"

# ── Argument parsing ──────────────────────────────────────────────────────
FILL_MODE=false
SPECS_REPO=""

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fill)
            FILL_MODE=true
            shift
            ;;
        --specs)
            SPECS_REPO="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 <platform> <target_repo> [version] [--fill] [--specs <path>]"
            echo ""
            echo "Platforms: ios, android"
            echo ""
            echo "Options:"
            echo "  --fill         Auto-fill template placeholders from PROJECT.md"
            echo "  --specs <path> Path to specs repo (for locating PROJECT.md)"
            echo ""
            echo "Examples:"
            echo "  $0 ios ../my-ios-app 1.0"
            echo "  $0 android ../my-android-app 1.0 --fill --specs ../specs-repo"
            echo ""
            echo "The synced repo works with both Claude Code and Codex CLI."
            exit 0
            ;;
        *)
            if [[ -z "${PLATFORM:-}" ]]; then
                PLATFORM="$1"
            elif [[ -z "${TARGET_REPO:-}" ]]; then
                TARGET_REPO="$1"
            elif [[ -z "${VERSION:-}" ]]; then
                VERSION="$1"
            fi
            shift
            ;;
    esac
done

VERSION="${VERSION:-1.0}"

if [[ -z "${PLATFORM:-}" || -z "${TARGET_REPO:-}" ]]; then
    echo "Usage: $0 <platform> <target_repo> [version] [--fill] [--specs <path>]"
    echo ""
    echo "Platforms: ios, android"
    echo "Use --fill to auto-fill templates from PROJECT.md"
    exit 1
fi

PLATFORM_DIR="${SCRIPT_DIR}/${PLATFORM}"

# ── Validation ────────────────────────────────────────────────────────────
if [[ ! -d "${PLATFORM_DIR}" ]]; then
    echo "ERROR: Platform directory not found: ${PLATFORM_DIR}"
    echo "Available platforms:"
    ls -d "${SCRIPT_DIR}"/*/ 2>/dev/null | grep -v _shared | xargs -I{} basename {} | sed 's/^/  /'
    exit 1
fi

if [[ ! -d "${TARGET_REPO}" ]]; then
    echo "ERROR: Target repository not found: ${TARGET_REPO}"
    exit 1
fi

TARGET_REPO="$(cd "${TARGET_REPO}" && pwd)"

echo "================================================================"
echo "Agent Sync: ${PLATFORM} -> ${TARGET_REPO}"
echo "Version: ${VERSION}"
echo "Tools:   Claude Code + Codex CLI"
echo "================================================================"
echo ""

SYNCED_COUNT=0

# ── Helper: sync directory ────────────────────────────────────────────────
# Usage: sync_dir <source_dir> <target_dir> <label>
sync_dir() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [[ ! -d "${src}" ]]; then
        return
    fi

    # Count files in source
    local count
    count=$(find "${src}" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "${count}" -eq 0 ]]; then
        return
    fi

    mkdir -p "${dst}"
    cp -R "${src}/"* "${dst}/" 2>/dev/null || true
    SYNCED_COUNT=$((SYNCED_COUNT + count))
    echo "  [+] ${label}: ${count} file(s)"
}

# ── Helper: sync single file ─────────────────────────────────────────────
# Usage: sync_file <source_file> <target_path> <label>
sync_file() {
    local src="$1"
    local dst="$2"
    local label="$3"

    if [[ ! -f "${src}" ]]; then
        return
    fi

    local dst_dir
    dst_dir="$(dirname "${dst}")"
    mkdir -p "${dst_dir}"
    cp "${src}" "${dst}"
    SYNCED_COUNT=$((SYNCED_COUNT + 1))
    echo "  [+] ${label}"
}

# ── Step 1-3: Copy shared layer ──────────────────────────────────────────
echo "Shared layer (_shared/):"
sync_dir "${SHARED_DIR}/commands"  "${TARGET_REPO}/.claude/commands"  "commands"
sync_dir "${SHARED_DIR}/workflows" "${TARGET_REPO}/.claude/workflows" "workflows"
sync_dir "${SHARED_DIR}/ai"        "${TARGET_REPO}/ai"               "ai"
sync_dir "${SHARED_DIR}/adapters"  "${TARGET_REPO}/.claude/adapters"  "adapters"

if [[ ${SYNCED_COUNT} -eq 0 ]]; then
    echo "  (no shared files found)"
fi
echo ""

# ── Step 4: Overlay platform-specific files ───────────────────────────────
# Platform files with the same name override shared files.
PLATFORM_COUNT=0

echo "Platform layer (${PLATFORM}/):"
if [[ -d "${PLATFORM_DIR}/.claude/commands" ]]; then
    sync_dir "${PLATFORM_DIR}/.claude/commands" "${TARGET_REPO}/.claude/commands" "commands (override)"
fi
if [[ -d "${PLATFORM_DIR}/.claude/workflows" ]]; then
    sync_dir "${PLATFORM_DIR}/.claude/workflows" "${TARGET_REPO}/.claude/workflows" "workflows (override)"
fi
if [[ -d "${PLATFORM_DIR}/.claude/skills" ]]; then
    sync_dir "${PLATFORM_DIR}/.claude/skills" "${TARGET_REPO}/.claude/skills" "skills"
fi
if [[ -d "${PLATFORM_DIR}/.claude/scripts" ]]; then
    sync_dir "${PLATFORM_DIR}/.claude/scripts" "${TARGET_REPO}/.claude/scripts" "scripts"
fi
if [[ -d "${PLATFORM_DIR}/ai" ]]; then
    sync_dir "${PLATFORM_DIR}/ai" "${TARGET_REPO}/ai" "ai (override)"
fi
echo ""

# ── Step 5: Copy CLAUDE.md and AGENTS.md ──────────────────────────────────
echo "Entry points:"
sync_file "${PLATFORM_DIR}/CLAUDE.md"  "${TARGET_REPO}/CLAUDE.md"  "CLAUDE.md (Claude Code entry)"
sync_file "${PLATFORM_DIR}/AGENTS.md"  "${TARGET_REPO}/AGENTS.md"  "AGENTS.md (Codex CLI entry)"
echo ""

# ── Step 6: Copy and inject version into config.yaml ─────────────────────
echo "Configuration:"
if [[ -f "${PLATFORM_DIR}/.claude/config.yaml" ]]; then
    mkdir -p "${TARGET_REPO}/.claude"
    # Copy config then inject version
    sed "s/current: \"1.0\"/current: \"${VERSION}\"/" \
        "${PLATFORM_DIR}/.claude/config.yaml" > "${TARGET_REPO}/.claude/config.yaml"
    SYNCED_COUNT=$((SYNCED_COUNT + 1))
    echo "  [+] .claude/config.yaml (version: ${VERSION})"
else
    echo "  (no config.yaml template found)"
fi
echo ""

# ── Step 7: Ensure Figma cache directory exists ──────────────────────────
echo "Cache directories:"
mkdir -p "${TARGET_REPO}/.claude/cache/${VERSION}/figma"
echo "  [+] .claude/cache/${VERSION}/figma/ (for cached Figma screenshots)"
echo ""

# ── Step 8: Auto-fill from PROJECT.md (--fill mode) ─────────────────────
if [[ "${FILL_MODE}" == true ]]; then
    echo "Auto-fill mode:"

    # Locate PROJECT.md
    PROJECT_MD=""
    if [[ -n "${SPECS_REPO}" && -f "${SPECS_REPO}/PROJECT.md" ]]; then
        PROJECT_MD="${SPECS_REPO}/PROJECT.md"
    elif [[ -f "${TARGET_REPO}/../PROJECT.md" ]]; then
        PROJECT_MD="${TARGET_REPO}/../PROJECT.md"
    elif [[ -f "${TARGET_REPO}/../specs/PROJECT.md" ]]; then
        PROJECT_MD="${TARGET_REPO}/../specs/PROJECT.md"
    fi

    if [[ -z "${PROJECT_MD}" ]]; then
        echo "  [!] PROJECT.md not found. Skipping auto-fill."
        echo "      Provide --specs <path> or place PROJECT.md in parent directory."
    else
        echo "  [i] Reading ${PROJECT_MD}"
        FILL_COUNT=0

        # Extract platform-specific info from PROJECT.md
        # Uses awk to parse the markdown structure
        if [[ "${PLATFORM}" == "ios" ]]; then
            AI_FILE="${TARGET_REPO}/ai/ios.md"
            if [[ -f "${AI_FILE}" ]]; then
                # Extract iOS tech stack from PROJECT.md
                WORKSPACE=$(awk '/## iOS/,/## Android|## Backend/{
                    if (/Workspace:/) { sub(/.*Workspace:[[:space:]]*`/, ""); sub(/`.*/, ""); print; exit }
                }' "${PROJECT_MD}")
                UI_FW=$(awk '/## iOS/,/## Android|## Backend/{
                    if (/UI Framework:/) { sub(/.*UI Framework:[[:space:]]*/, ""); print; exit }
                }' "${PROJECT_MD}")
                ARCH=$(awk '/## iOS/,/## Android|## Backend/{
                    if (/Architecture:/) { sub(/.*Architecture:[[:space:]]*/, ""); print; exit }
                }' "${PROJECT_MD}")
                NET=$(awk '/## iOS/,/## Android|## Backend/{
                    if (/Networking|Client:/) { sub(/.*Client:[[:space:]]*/, ""); sub(/.*Networking.*:[[:space:]]*/, ""); print; exit }
                }' "${PROJECT_MD}")

                # Fill placeholders if values found
                if [[ -n "${WORKSPACE}" ]]; then
                    sed -i '' "s|{WORKSPACE}\.xcworkspace|${WORKSPACE}|g; s|{WORKSPACE}|${WORKSPACE%.xcworkspace}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                if [[ -n "${UI_FW}" ]]; then
                    sed -i '' "s|{UI_FRAMEWORK}[^}]*|${UI_FW}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                if [[ -n "${ARCH}" ]]; then
                    sed -i '' "s|{ARCHITECTURE_DESCRIPTION}[^}]*|${ARCH}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                if [[ -n "${NET}" ]]; then
                    sed -i '' "s|{NETWORKING_LAYER}[^}]*|${NET}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                echo "  [+] ai/ios.md: ${FILL_COUNT} placeholder(s) filled"
            fi

        elif [[ "${PLATFORM}" == "android" ]]; then
            AI_FILE="${TARGET_REPO}/ai/android.md"
            if [[ -f "${AI_FILE}" ]]; then
                # Extract Android tech stack from PROJECT.md
                LANG=$(awk '/## Android/,/## Backend|## Private/{
                    if (/Language:/) { sub(/.*Language:[[:space:]]*/, ""); print; exit }
                }' "${PROJECT_MD}")
                UI_FW=$(awk '/## Android/,/## Backend|## Private/{
                    if (/UI Framework:/) { sub(/.*UI Framework:[[:space:]]*/, ""); print; exit }
                }' "${PROJECT_MD}")
                ARCH=$(awk '/## Android/,/## Backend|## Private/{
                    if (/Architecture:/) { sub(/.*Architecture:[[:space:]]*/, ""); print; exit }
                }' "${PROJECT_MD}")
                NET=$(awk '/## Android/,/## Backend|## Private/{
                    if (/Client:|Networking/) { sub(/.*Client:[[:space:]]*/, ""); print; exit }
                }' "${PROJECT_MD}")

                if [[ -n "${LANG}" ]]; then
                    sed -i '' "s|Kotlin (100%)[^.]*|${LANG}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                if [[ -n "${UI_FW}" ]]; then
                    sed -i '' "s|Jetpack Compose (preferred)[^.]*|${UI_FW}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                if [[ -n "${ARCH}" ]]; then
                    sed -i '' "s|MVVM + Clean Architecture[^.]*|${ARCH}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                if [[ -n "${NET}" ]]; then
                    sed -i '' "s|Retrofit + OkHttp + kotlinx.serialization[^.]*|${NET}|g" "${AI_FILE}" 2>/dev/null && FILL_COUNT=$((FILL_COUNT + 1))
                fi
                echo "  [+] ai/android.md: ${FILL_COUNT} placeholder(s) filled"
            fi
        fi

        # Fill {PROJECT_NAME} in all synced files
        PROJECT_NAME=$(awk '/^#.*Project Overview/{
            sub(/^#[[:space:]]*/, ""); sub(/[[:space:]]*—.*/, ""); print; exit
        }' "${PROJECT_MD}")
        if [[ -n "${PROJECT_NAME}" ]]; then
            find "${TARGET_REPO}" -maxdepth 2 -name '*.md' -exec \
                sed -i '' "s|{PROJECT_NAME}|${PROJECT_NAME}|g" {} \; 2>/dev/null
            echo "  [+] {PROJECT_NAME} → '${PROJECT_NAME}' in all .md files"
        fi
    fi
    echo ""
fi

# ── Step 9: Summary ──────────────────────────────────────────────────────
echo "================================================================"
echo "Sync complete: ${SYNCED_COUNT} file(s) synced to ${TARGET_REPO}"
echo ""
echo "Tool support:"
echo "  Claude Code: reads CLAUDE.md + auto-discovers .claude/commands/"
echo "  Codex CLI:   reads AGENTS.md + follows .claude/commands/spec-next.md"
echo "  Other tools: reads AGENTS.md + follows .claude/commands/spec-next.md"
if [[ "${FILL_MODE}" == true ]]; then
echo ""
echo "Auto-fill: templates populated from PROJECT.md"
echo "  Review ai/${PLATFORM}.md for accuracy."
else
echo ""
echo "Next steps:"
echo "  1. Run with --fill to auto-populate from PROJECT.md, or manually fill placeholders"
echo "  2. Update .claude/config.yaml with project-specific values"
echo "  3. Ensure specs/ symlink or .context-resolved.yaml exists"
echo "  4. Cache Figma screenshots to .claude/cache/${VERSION}/figma/ if needed"
fi
echo "================================================================"
