#!/usr/bin/env bash
# lint-i18n-refs.sh — validate i18n single-source-of-truth invariants
# Exit 0 = all checks passed, Exit 1 = violations found
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Skip test/demo versions (cc-* directories)
EXCLUDE_PATTERN="cc-"
errors=0

red()   { printf '\033[31m%s\033[0m\n' "$1"; }
green() { printf '\033[32m%s\033[0m\n' "$1"; }
warn()  { printf '\033[33m%s\033[0m\n' "$1"; }

# Auto-detect project directory (first non-hidden, non-underscore dir with features/)
PROJECT_DIR=""
for dir in "$REPO_ROOT"/*/; do
  basename=$(basename "$dir")
  [[ "$basename" == _* ]] && continue
  [[ "$basename" == .* ]] && continue
  [[ "$basename" == examples ]] && continue
  [[ "$basename" == templates ]] && continue
  [[ "$basename" == workflows ]] && continue
  [[ "$basename" == docs ]] && continue
  [[ "$basename" == scripts ]] && continue
  [[ "$basename" == adapters ]] && continue
  if [ -d "$dir" ]; then
    PROJECT_DIR="$dir"
    break
  fi
done

if [ -z "$PROJECT_DIR" ]; then
  echo "No project directory found. Run ./scripts/init.sh first."
  exit 0
fi

# --- Check 1: Feature YAMLs must NOT contain i18n_keys (should use i18n_ref) ---
echo "--- Check 1: No i18n_keys in feature YAMLs ---"
while IFS= read -r yaml; do
  if grep -q '^i18n_keys:' "$yaml" 2>/dev/null; then
    if grep -qE '^i18n_keys:[[:space:]]*\[\]' "$yaml" 2>/dev/null; then
      warn "WARN: $yaml has i18n_keys: [] — consider converting to i18n_ref: null"
    else
      red "FAIL: $yaml still contains inline i18n_keys"
      ((errors++))
    fi
  fi
done < <(find "$PROJECT_DIR" -path '*/features/F*.yaml' 2>/dev/null | grep -v "$EXCLUDE_PATTERN")
[ $errors -eq 0 ] && green "PASS: No inline i18n_keys found in feature YAMLs"

# --- Check 2: Task MDs must NOT contain inline i18n tables ---
echo ""
echo "--- Check 2: No inline i18n tables in task MDs ---"
prev_errors=$errors
while IFS= read -r md; do
  if awk '/^#### i18n/{found=1; next} /^####/{found=0} found && /^\|.*`.*`.*\|/' "$md" | grep -q .; then
    red "FAIL: $md contains inline i18n table (should be a reference link)"
    ((errors++))
  fi
done < <(find "$PROJECT_DIR" -path '*/tasks/*.md' \( -name 'ios.md' -o -name 'android.md' \) 2>/dev/null | grep -v "$EXCLUDE_PATTERN")
[ $errors -eq $prev_errors ] && green "PASS: No inline i18n tables in task MDs"

# --- Check 3: i18n_ref anchors point to existing strings.md sections ---
echo ""
echo "--- Check 3: i18n_ref anchors resolve to strings.md sections ---"
prev_errors=$errors
while IFS= read -r yaml; do
  ref=$(grep '^i18n_ref:' "$yaml" 2>/dev/null | head -1 | sed 's/^i18n_ref:\s*//' | tr -d '"' | tr -d "'" || true)
  [ -z "$ref" ] || [ "$ref" = "null" ] && continue

  fnum=$(echo "$ref" | sed -n 's/.*#F\([0-9]*\).*/\1/p')
  [ -z "$fnum" ] && continue

  version_dir=$(dirname "$(dirname "$yaml")")
  strings_file="$version_dir/i18n/strings.md"

  if [ ! -f "$strings_file" ]; then
    red "FAIL: $yaml references $strings_file but file does not exist"
    ((errors++))
    continue
  fi

  if ! grep -qE "^## .*F0*$fnum" "$strings_file"; then
    red "FAIL: $yaml references F$fnum but no matching section in $strings_file"
    ((errors++))
  fi
done < <(find "$PROJECT_DIR" -path '*/features/F*.yaml' 2>/dev/null | grep -v "$EXCLUDE_PATTERN")
[ $errors -eq $prev_errors ] && green "PASS: All i18n_ref anchors resolve correctly"

# --- Summary ---
echo ""
if [ $errors -eq 0 ]; then
  green "All checks passed."
  exit 0
else
  red "$errors violation(s) found."
  exit 1
fi
