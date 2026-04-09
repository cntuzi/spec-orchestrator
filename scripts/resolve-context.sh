#!/usr/bin/env bash
# resolve-context.sh — Resolve external context paths for spec-orchestrator
#
# Reads context.yaml (logical identifiers + pins) and produces
# .context-resolved.yaml (absolute paths + validation status).
#
# Usage:
#   resolve-context.sh                          # auto-detect version from config
#   resolve-context.sh <version>                # explicit version
#   resolve-context.sh <version> --check-only   # validate without writing
#   resolve-context.sh --resolve-repos          # resolve repos section only (no version context)
#
# Resolution order per repo_id:
#   1. Environment variable SPEC_REPO_{REPO_ID}  (uppercase, hyphens → underscores)
#   2. Existing symlink/directory in working directory
#   3. Git worktree discovery: trace back to main repo → parent dir → sibling match
#   4. Hint path from .claude/config.yaml repos[].hint
#   5. Interactive prompt (if TTY available)
#
# Output: .context-resolved.yaml in current working directory

set -euo pipefail

# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[resolve]${NC} $*"; }
ok()    { echo -e "${GREEN}[  ok  ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ warn ]${NC} $*"; }
fail()  { echo -e "${RED}[ fail ]${NC} $*"; }

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Convert repo_id to env var name: api-doc → SPEC_REPO_API_DOC
repo_id_to_env() {
  local id="$1"
  echo "SPEC_REPO_$(echo "$id" | tr '[:lower:]-' '[:upper:]_')"
}

# Get the main repo root from a possible worktree
get_main_repo_root() {
  local git_common_dir
  git_common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1

  # Normalize to absolute path
  if [[ "$git_common_dir" == /* ]]; then
    echo "${git_common_dir%/.git}"
  else
    echo "$(cd "$git_common_dir/.." && pwd)"
  fi
}

# Get the parent directory where sibling repos live
get_repos_parent() {
  local main_root
  main_root="$(get_main_repo_root)" || return 1
  dirname "$main_root"
}

# Check if current directory is a git worktree (not the main repo)
is_worktree() {
  local git_dir git_common_dir
  git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1
  git_common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1

  # In a worktree, .git is a file pointing elsewhere; git-dir != git-common-dir
  [[ "$git_dir" != "$git_common_dir" ]]
}

# Get current commit of a repo at a given path
get_repo_commit() {
  local repo_path="$1"
  git -C "$repo_path" rev-parse HEAD 2>/dev/null || echo "unknown"
}

# Read a YAML value (simple single-line, no dependencies beyond grep/sed)
# Usage: yaml_value file key    → reads "key: value" from file
yaml_value() {
  local file="$1" key="$2"
  grep -E "^\s*${key}:" "$file" 2>/dev/null | head -1 | sed "s/.*${key}:\s*//" | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/' | xargs
}

# Read nested YAML value: yaml_nested file "parent.child"
yaml_nested() {
  local file="$1"
  local keypath="$2"
  local IFS='.'
  read -ra keys <<< "$keypath"

  local indent=0
  local result=""
  local in_section=false
  local target_key="${keys[-1]}"
  local depth=${#keys[@]}

  if [[ $depth -eq 1 ]]; then
    yaml_value "$file" "$target_key"
    return
  fi

  # For nested keys, use a simple awk approach
  local awk_pattern=""
  for ((i=0; i<depth-1; i++)); do
    awk_pattern+="/${keys[$i]}:/"
    if ((i < depth-2)); then
      awk_pattern+=","
    fi
  done

  # Simple approach: find lines after parent key, look for child
  local parent_key="${keys[0]}"
  local child_key="${keys[-1]}"

  awk "
    /^[[:space:]]*${parent_key}:/ { in_parent=1; next }
    in_parent && /^[^ ]/ && !/^[[:space:]]/ { in_parent=0 }
    in_parent && /^[[:space:]]*${child_key}:/ {
      sub(/.*${child_key}:[[:space:]]*/, \"\")
      gsub(/^[\"']|[\"']$/, \"\")
      print
      exit
    }
  " "$file" 2>/dev/null
}

# Read repo hints from .claude/config.yaml
# Returns: repo_id hint_path (one per line)
read_repo_hints() {
  local config="$1"
  [[ -f "$config" ]] || return 0

  awk '
    /^repos:/ { in_repos=1; next }
    in_repos && /^[^ ]/ { in_repos=0 }
    in_repos && /^  [a-zA-Z]/ {
      # repo entry like "  api-doc:" or "  ios:"
      gsub(/[: ]/, "")
      current_repo=$0
    }
    in_repos && /hint:/ {
      sub(/.*hint:[[:space:]]*/, "")
      gsub(/^[\"'"'"']|[\"'"'"']$/, "")
      print current_repo " " $0
    }
  ' "$config" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Resolve a single repo_id to an absolute path
# Returns 0 on success (path printed to stdout), 1 on failure
# -----------------------------------------------------------------------------
resolve_repo() {
  local repo_id="$1"
  local hint="${2:-}"
  local resolved=""

  # Strategy 1: Environment variable
  local env_name
  env_name="$(repo_id_to_env "$repo_id")"
  local env_val="${!env_name:-}"
  if [[ -n "$env_val" && -d "$env_val" ]]; then
    resolved="$(cd "$env_val" && pwd)"
    ok "$repo_id → env \$$env_name → $resolved"
    echo "$resolved"
    return 0
  fi

  # Strategy 2: Symlink or directory in current working directory
  if [[ -d "./$repo_id" ]]; then
    resolved="$(cd "./$repo_id" && pwd)"
    ok "$repo_id → local ./$repo_id → $resolved"
    echo "$resolved"
    return 0
  fi
  # Also check common symlink names (e.g., "specs" for specs repo)
  local alt_name="$repo_id"
  if [[ -L "./$alt_name" && -d "./$alt_name" ]]; then
    resolved="$(cd "./$alt_name" && pwd)"
    ok "$repo_id → symlink ./$alt_name → $resolved"
    echo "$resolved"
    return 0
  fi

  # Strategy 3: Git worktree discovery → parent dir → sibling repos
  local parent_dir
  parent_dir="$(get_repos_parent 2>/dev/null)" || true
  if [[ -n "$parent_dir" ]]; then
    # Try exact match
    if [[ -d "$parent_dir/$repo_id" ]]; then
      resolved="$(cd "$parent_dir/$repo_id" && pwd)"
      ok "$repo_id → sibling $resolved"
      echo "$resolved"
      return 0
    fi
    # Try with common prefixes/suffixes stripped or added
    for candidate in "$parent_dir"/*; do
      [[ -d "$candidate" ]] || continue
      local basename
      basename="$(basename "$candidate")"
      # Match if basename contains repo_id or vice versa
      if [[ "$basename" == *"$repo_id"* || "$repo_id" == *"$basename"* ]]; then
        resolved="$(cd "$candidate" && pwd)"
        ok "$repo_id → sibling match $resolved"
        echo "$resolved"
        return 0
      fi
    done
  fi

  # Strategy 4: Hint path from config
  if [[ -n "$hint" ]]; then
    # Resolve hint relative to main repo root
    local base_dir
    base_dir="$(get_main_repo_root 2>/dev/null)" || base_dir="$(pwd)"
    local hint_abs
    if [[ "$hint" == /* ]]; then
      hint_abs="$hint"
    else
      hint_abs="$base_dir/$hint"
    fi
    if [[ -d "$hint_abs" ]]; then
      resolved="$(cd "$hint_abs" && pwd)"
      ok "$repo_id → hint $hint → $resolved"
      echo "$resolved"
      return 0
    fi
  fi

  # Strategy 5: Interactive prompt (only if TTY available)
  if [[ -t 0 && -t 1 ]]; then
    warn "$repo_id → all strategies failed"
    echo -en "${YELLOW}  Enter path for '$repo_id' (or press Enter to skip): ${NC}" >&2
    local user_path
    read -r user_path
    if [[ -n "$user_path" && -d "$user_path" ]]; then
      resolved="$(cd "$user_path" && pwd)"
      ok "$repo_id → user input → $resolved"
      echo "$resolved"
      return 0
    fi
  fi

  fail "$repo_id → could not resolve"
  return 1
}

# -----------------------------------------------------------------------------
# Parse context.yaml sources and extract repo_ids
# Returns: repo_id (one per line, deduplicated)
# -----------------------------------------------------------------------------
extract_repo_ids_from_context() {
  local context_file="$1"
  grep -E '^\s+repo_id:' "$context_file" 2>/dev/null \
    | sed 's/.*repo_id:\s*//' \
    | sed 's/^["'"'"']\(.*\)["'"'"']$/\1/' \
    | xargs -n1 \
    | sort -u
}

# -----------------------------------------------------------------------------
# Check pin drift for a resolved repo
# Returns: "match" | "drifted" | "unknown"
# -----------------------------------------------------------------------------
check_drift() {
  local repo_path="$1"
  local pinned_commit="$2"

  [[ -z "$pinned_commit" || "$pinned_commit" == "{COMMIT_HASH}" ]] && echo "unknown" && return 0

  local current_commit
  current_commit="$(get_repo_commit "$repo_path")"

  if [[ "$current_commit" == "$pinned_commit" ]]; then
    echo "match"
  elif git -C "$repo_path" merge-base --is-ancestor "$pinned_commit" "$current_commit" 2>/dev/null; then
    echo "drifted"
  else
    echo "drifted"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

VERSION=""
CHECK_ONLY=false
REPOS_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)   CHECK_ONLY=true; shift ;;
    --resolve-repos) REPOS_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: resolve-context.sh [version] [--check-only] [--resolve-repos]"
      exit 0
      ;;
    *)
      VERSION="$1"; shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_FILE="$REPO_ROOT/.claude/config.yaml"

info "Repository root: $REPO_ROOT"

# Detect environment
if is_worktree; then
  ENVIRONMENT="worktree"
  MAIN_ROOT="$(get_main_repo_root)"
  info "Environment: worktree (main repo: $MAIN_ROOT)"
else
  ENVIRONMENT="main"
  MAIN_ROOT="$REPO_ROOT"
  info "Environment: main repository"
fi

# Read config
if [[ ! -f "$CONFIG_FILE" ]]; then
  fail ".claude/config.yaml not found at $CONFIG_FILE"
  exit 1
fi

PROJECT_NAME="$(yaml_value "$CONFIG_FILE" "name" 2>/dev/null || yaml_nested "$CONFIG_FILE" "project.name")"
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="$(yaml_nested "$CONFIG_FILE" "project.name")"

# Determine role (orchestrator has platforms section, worker has platform field)
if grep -q "^platforms:" "$CONFIG_FILE" 2>/dev/null; then
  ROLE="orchestrator"
else
  ROLE="worker"
fi
info "Role: $ROLE"

# Read version
if [[ -z "$VERSION" ]]; then
  VERSION="$(yaml_nested "$CONFIG_FILE" "version.current")"
fi
[[ -z "$VERSION" ]] && { fail "Cannot determine version"; exit 1; }
info "Version: $VERSION"

# Collect repo hints from config
declare -A REPO_HINTS
while IFS=' ' read -r rid hpath; do
  [[ -n "$rid" ]] && REPO_HINTS["$rid"]="$hpath"
done < <(read_repo_hints "$CONFIG_FILE")

# Also read platform repo paths as hints (orchestrator mode)
if [[ "$ROLE" == "orchestrator" ]]; then
  for platform in ios android; do
    repo_path="$(yaml_nested "$CONFIG_FILE" "platforms.${platform}.repo" 2>/dev/null || true)"
    if [[ -n "$repo_path" ]]; then
      REPO_HINTS["$platform"]="${repo_path}"
    fi
  done
fi

# Determine which repos to resolve
declare -A RESOLVED_REPOS
declare -A REPO_STATUS
declare -A REPO_DRIFT

# If repos-only mode, just resolve repos from config and exit
if [[ "$REPOS_ONLY" == true ]]; then
  info "Resolving repos from config only (no version context)"
  for rid in "${!REPO_HINTS[@]}"; do
    hint="${REPO_HINTS[$rid]}"
    path="$(resolve_repo "$rid" "$hint" 2>/dev/null)" && {
      RESOLVED_REPOS["$rid"]="$path"
      REPO_STATUS["$rid"]="ok"
    } || {
      REPO_STATUS["$rid"]="missing"
    }
  done

  # Write output
  OUTPUT_FILE="$REPO_ROOT/.context-resolved.yaml"
  if [[ "$CHECK_ONLY" == true ]]; then
    info "Check-only mode, not writing file"
  else
    cat > "$OUTPUT_FILE" << YAML
# Auto-generated by resolve-context.sh — do not edit
# Re-run: scripts/resolve-context.sh --resolve-repos

resolved_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
environment: $ENVIRONMENT
repo_root: "$REPO_ROOT"
role: $ROLE

repos:
YAML
    for rid in $(echo "${!RESOLVED_REPOS[@]}" | tr ' ' '\n' | sort); do
      echo "  $rid: \"${RESOLVED_REPOS[$rid]}\"" >> "$OUTPUT_FILE"
    done

    echo "" >> "$OUTPUT_FILE"
    echo "validation:" >> "$OUTPUT_FILE"
    for rid in $(echo "${!REPO_STATUS[@]}" | tr ' ' '\n' | sort); do
      echo "  $rid: ${REPO_STATUS[$rid]}" >> "$OUTPUT_FILE"
    done

    ok "Wrote $OUTPUT_FILE"
  fi
  exit 0
fi

# Full resolution: read context.yaml
if [[ "$ROLE" == "orchestrator" ]]; then
  # Orchestrator: context.yaml is local
  CONTEXT_FILE="$REPO_ROOT/$PROJECT_NAME/$VERSION/context.yaml"
else
  # Worker: context.yaml is in specs repo
  SPECS_PATH=""
  # Try resolving specs first
  specs_hint="${REPO_HINTS[specs]:-}"
  SPECS_PATH="$(resolve_repo "specs" "$specs_hint" 2>/dev/null)" || true

  if [[ -z "$SPECS_PATH" ]]; then
    fail "Cannot resolve specs repo — needed to find context.yaml"
    exit 1
  fi
  RESOLVED_REPOS["specs"]="$SPECS_PATH"
  REPO_STATUS["specs"]="ok"
  CONTEXT_FILE="$SPECS_PATH/$PROJECT_NAME/$VERSION/context.yaml"
fi

if [[ ! -f "$CONTEXT_FILE" ]]; then
  warn "context.yaml not found at $CONTEXT_FILE"
  warn "Falling back to repos-only resolution"

  # Still resolve what we can from config hints
  for rid in "${!REPO_HINTS[@]}"; do
    hint="${REPO_HINTS[$rid]}"
    path="$(resolve_repo "$rid" "$hint" 2>/dev/null)" && {
      RESOLVED_REPOS["$rid"]="$path"
      REPO_STATUS["$rid"]="ok"
    } || {
      REPO_STATUS["$rid"]="missing"
    }
  done
else
  info "Context manifest: $CONTEXT_FILE"

  # Extract repo_ids from context.yaml
  CONTEXT_REPO_IDS="$(extract_repo_ids_from_context "$CONTEXT_FILE")"

  # Merge with config hints — context repos + config repos
  ALL_REPO_IDS="$(echo -e "$CONTEXT_REPO_IDS\n$(echo "${!REPO_HINTS[@]}" | tr ' ' '\n')" | sort -u)"

  # Resolve each repo
  for rid in $ALL_REPO_IDS; do
    [[ -z "$rid" ]] && continue
    [[ -n "${RESOLVED_REPOS[$rid]:-}" ]] && continue  # already resolved (e.g., specs)

    hint="${REPO_HINTS[$rid]:-}"
    path="$(resolve_repo "$rid" "$hint")" && {
      RESOLVED_REPOS["$rid"]="$path"
      REPO_STATUS["$rid"]="ok"
    } || {
      REPO_STATUS["$rid"]="missing"
    }
  done

  # Drift check for resolved repos with pins
  DRIFT_POLICY="$(yaml_value "$CONTEXT_FILE" "drift_policy" 2>/dev/null || echo "warn")"

  for rid in "${!RESOLVED_REPOS[@]}"; do
    repo_path="${RESOLVED_REPOS[$rid]}"
    # Try to find pinned commit for this repo_id in context.yaml
    pinned_commit="$(awk "
      /repo_id:.*${rid}/ { found=1 }
      found && /commit:/ {
        sub(/.*commit:[[:space:]]*/, \"\")
        gsub(/[\"']/, \"\")
        print
        exit
      }
      found && /^[^ ]/ && !/^[[:space:]]/ { found=0 }
    " "$CONTEXT_FILE" 2>/dev/null)"

    if [[ -n "$pinned_commit" && "$pinned_commit" != "{COMMIT_HASH}" ]]; then
      drift="$(check_drift "$repo_path" "$pinned_commit")"
      REPO_DRIFT["$rid"]="$drift"
      case "$drift" in
        match)   ok "$rid pin: $pinned_commit (current)" ;;
        drifted)
          current="$(get_repo_commit "$repo_path")"
          case "$DRIFT_POLICY" in
            block)
              fail "$rid pin DRIFTED: pinned=$pinned_commit current=$current — blocking"
              ;;
            warn)
              warn "$rid pin drifted: pinned=$pinned_commit current=$current"
              ;;
            ignore) ;;
          esac
          ;;
        unknown) ;;
      esac
    fi
  done

  # Validate artifacts
  info "Validating artifacts..."
  # Extract artifact paths from context.yaml and check they exist
  # For local type, check relative to version dir
  # For git-repo type, check relative to resolved repo path
  VERSION_DIR="$(dirname "$CONTEXT_FILE")"

  awk '
    /^  [a-z_]+:/ { current_source=$0; gsub(/[: ]/, "", current_source) }
    /type:/ { sub(/.*type:[[:space:]]*/, ""); type=$0 }
    /repo_id:/ { sub(/.*repo_id:[[:space:]]*/, ""); gsub(/[\"'"'"']/, ""); repo_id=$0 }
    /artifacts:/ { in_artifacts=1; next }
    in_artifacts && /^      - / {
      sub(/^      - /, "")
      gsub(/[\"'"'"']/, "")
      print type "\t" (repo_id ? repo_id : "local") "\t" $0
    }
    in_artifacts && /^  [^ ]/ { in_artifacts=0; repo_id="" }
  ' "$CONTEXT_FILE" 2>/dev/null | while IFS=$'\t' read -r atype arepo apath; do
    # Skip template placeholders
    [[ "$apath" == *"{"* ]] && continue

    if [[ "$atype" == "local" || "$arepo" == "local" ]]; then
      if [[ -f "$VERSION_DIR/$apath" ]]; then
        ok "artifact $apath (local)"
      else
        warn "artifact $apath (local) — not found at $VERSION_DIR/$apath"
      fi
    else
      local_repo="${RESOLVED_REPOS[$arepo]:-}"
      if [[ -n "$local_repo" ]]; then
        if [[ -f "$local_repo/$apath" ]]; then
          ok "artifact $arepo:$apath"
        else
          warn "artifact $arepo:$apath — not found at $local_repo/$apath"
        fi
      else
        warn "artifact $arepo:$apath — repo not resolved"
      fi
    fi
  done
fi

# Figma cache validation
FIGMA_CACHE=""
if [[ "$ROLE" == "worker" ]]; then
  FIGMA_CACHE="$REPO_ROOT/.claude/cache/$VERSION/figma"
elif [[ "$ROLE" == "orchestrator" ]]; then
  # Orchestrator doesn't usually have figma cache, but check anyway
  FIGMA_CACHE=""
fi

# -----------------------------------------------------------------------------
# Write .context-resolved.yaml
# -----------------------------------------------------------------------------

OUTPUT_FILE="$REPO_ROOT/.context-resolved.yaml"

if [[ "$CHECK_ONLY" == true ]]; then
  info "Check-only mode — not writing output file"
  echo ""
  info "=== Resolution Summary ==="
  for rid in $(echo "${!REPO_STATUS[@]}" | tr ' ' '\n' | sort); do
    status="${REPO_STATUS[$rid]}"
    path="${RESOLVED_REPOS[$rid]:-N/A}"
    drift="${REPO_DRIFT[$rid]:-N/A}"
    echo "  $rid: status=$status path=$path drift=$drift"
  done

  # Exit with error if any required repo is missing
  for rid in $(echo "${!REPO_STATUS[@]}" | tr ' ' '\n' | sort); do
    [[ "${REPO_STATUS[$rid]}" == "missing" ]] && exit 1
  done
  exit 0
fi

info "Writing $OUTPUT_FILE"

cat > "$OUTPUT_FILE" << YAML
# Auto-generated by resolve-context.sh — do not edit manually
# Re-run: scripts/resolve-context.sh $VERSION
# Delete this file to force re-resolution on next execution

resolved_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
environment: $ENVIRONMENT
repo_root: "$REPO_ROOT"
role: $ROLE
version: "$VERSION"
YAML

# Write repos section
echo "" >> "$OUTPUT_FILE"
echo "repos:" >> "$OUTPUT_FILE"
for rid in $(echo "${!RESOLVED_REPOS[@]}" | tr ' ' '\n' | sort); do
  echo "  $rid: \"${RESOLVED_REPOS[$rid]}\"" >> "$OUTPUT_FILE"
done

# Write validation section
echo "" >> "$OUTPUT_FILE"
echo "validation:" >> "$OUTPUT_FILE"
for rid in $(echo "${!REPO_STATUS[@]}" | tr ' ' '\n' | sort); do
  echo "  $rid: ${REPO_STATUS[$rid]}" >> "$OUTPUT_FILE"
done

# Write drift section if any
has_drift=false
for rid in "${!REPO_DRIFT[@]}"; do
  has_drift=true
  break
done
if [[ "$has_drift" == true ]]; then
  echo "" >> "$OUTPUT_FILE"
  echo "drift:" >> "$OUTPUT_FILE"
  for rid in $(echo "${!REPO_DRIFT[@]}" | tr ' ' '\n' | sort); do
    echo "  $rid: ${REPO_DRIFT[$rid]}" >> "$OUTPUT_FILE"
  done
fi

# Write figma cache info if applicable
if [[ -n "$FIGMA_CACHE" ]]; then
  echo "" >> "$OUTPUT_FILE"
  echo "figma_cache:" >> "$OUTPUT_FILE"
  echo "  path: \"$FIGMA_CACHE\"" >> "$OUTPUT_FILE"
  if [[ -d "$FIGMA_CACHE" ]]; then
    local_count="$(find "$FIGMA_CACHE" -name '*.png' 2>/dev/null | wc -l | xargs)"
    echo "  status: ok" >> "$OUTPUT_FILE"
    echo "  cached_files: $local_count" >> "$OUTPUT_FILE"
  else
    echo "  status: missing" >> "$OUTPUT_FILE"
    echo "  cached_files: 0" >> "$OUTPUT_FILE"
  fi
fi

echo "" >> "$OUTPUT_FILE"
ok "Wrote $OUTPUT_FILE"

# Summary
echo ""
info "=== Resolution Summary ==="
total=0
resolved_count=0
missing_count=0
drifted_count=0
for rid in $(echo "${!REPO_STATUS[@]}" | tr ' ' '\n' | sort); do
  total=$((total + 1))
  status="${REPO_STATUS[$rid]}"
  path="${RESOLVED_REPOS[$rid]:-N/A}"
  drift="${REPO_DRIFT[$rid]:-}"

  if [[ "$status" == "ok" ]]; then
    resolved_count=$((resolved_count + 1))
    drift_info=""
    [[ "$drift" == "drifted" ]] && drift_info=" (DRIFTED)" && drifted_count=$((drifted_count + 1))
    ok "$rid → $path$drift_info"
  else
    missing_count=$((missing_count + 1))
    fail "$rid → not resolved"
  fi
done

echo ""
info "Total: $total | Resolved: $resolved_count | Missing: $missing_count | Drifted: $drifted_count"

if [[ $missing_count -gt 0 ]]; then
  warn "Some repos could not be resolved. Set environment variables or provide paths."
  warn "Example: export SPEC_REPO_API_DOC=/path/to/api-doc"
  exit 1
fi

if [[ $drifted_count -gt 0 && "$DRIFT_POLICY" == "block" ]]; then
  fail "Pin drift detected with block policy. Re-pin with /spec-init refresh."
  exit 1
fi

exit 0
