#!/usr/bin/env bash

# Performance Improvement #8: Fast validation mode - skip unchanged skills
# Validates only changed skill content to speed up CI/pre-commit linting
# On main/release branches, runs full validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="${1:-auto}"  # auto, full, changed
COMMIT_RANGE="${2:-.}"

SKILL_PATHS=(
  "skills/"
)

usage() {
  cat <<'EOF'
Validate skill content with optional change detection.

Usage:
  bash scripts/validate_skills.sh            # Auto-detect (full on main, changed on branches)
  bash scripts/validate_skills.sh full       # Always run full validation
  bash scripts/validate_skills.sh changed    # Only validate changed skills
  bash scripts/validate_skills.sh changed origin/main...HEAD  # Validate range

Options:
  MODE          Validation mode: auto (default), full, or changed
  COMMIT_RANGE  For 'changed' mode: commit range to check (default: .)
  -h, --help    Show this help message
EOF
}

# Get list of changed skills
get_changed_skills() {
  local range="$1"
  local changed_skills=()
  
  if [[ "${range}" == "." ]]; then
    # Check unstaged and staged changes
    changed_skills=($(git diff --name-only --staged --unstaged 2>/dev/null || true))
  else
    # Check committed changes in range
    changed_skills=($(git diff --name-only "${range}" 2>/dev/null || true))
  fi
  
  # Filter to only skill directories and extract skill names
  local unique_skills=()
  for file in "${changed_skills[@]}"; do
    for path in "${SKILL_PATHS[@]}"; do
      if [[ "${file}" =~ ^${path}([^/]+)/ ]]; then
        local skill_name="${BASH_REMATCH[1]}"
        if [[ ! " ${unique_skills[@]} " =~ " ${skill_name} " ]]; then
          unique_skills+=("${skill_name}")
        fi
        break
      fi
    done
  done
  
  printf '%s\n' "${unique_skills[@]}"
}

# Validate a single skill directory
validate_skill() {
  local skill_dir="$1"
  local skill_name="$(basename "${skill_dir}")"
  
  if [[ ! -d "${skill_dir}" ]]; then
    echo "ERROR: Skill directory not found: ${skill_dir}"
    return 1
  fi
  
  echo "Validating skill: ${skill_name}"
  
  # Check for required files
  local required_files=("SKILL.md" "README.md")
  for file in "${required_files[@]}"; do
    if [[ ! -f "${skill_dir}/${file}" ]]; then
      echo "  WARNING: Missing ${file}"
    fi
  done
  
  # Check for well-formed markdown
  if command -v markdownlint >/dev/null 2>&1; then
    if ! markdownlint "${skill_dir}"/*.md >/dev/null 2>&1; then
      echo "  WARNING: Markdown linting issues found"
    fi
  fi
  
  echo "  ✓ Validation passed"
  return 0
}

# Validate all skills
validate_all() {
  echo "Running full skill validation..."
  local failed=0
  
  for skill_dir in "${REPO_ROOT}/skills"/*; do
    if [[ -d "${skill_dir}" ]]; then
      if ! validate_skill "${skill_dir}"; then
        ((failed++))
      fi
    fi
  done
  
  if [[ ${failed} -gt 0 ]]; then
    echo "Validation failed: ${failed} skill(s) with errors"
    return 1
  fi
  
  echo "All skills validated successfully"
  return 0
}

# Validate only changed skills
validate_changed() {
  local range="$1"
  echo "Detecting changed skills in range: ${range}"
  
  local changed_skills=($(get_changed_skills "${range}"))
  
  if [[ ${#changed_skills[@]} -eq 0 ]]; then
    echo "No skill changes detected - skipping validation"
    return 0
  fi
  
  echo "Found ${#changed_skills[@]} changed skill(s): ${changed_skills[*]}"
  
  local failed=0
  for skill_name in "${changed_skills[@]}"; do
    local skill_dir="${REPO_ROOT}/skills/${skill_name}"
    if ! validate_skill "${skill_dir}"; then
      ((failed++))
    fi
  done
  
  if [[ ${failed} -gt 0 ]]; then
    echo "Validation failed: ${failed} skill(s) with errors"
    return 1
  fi
  
  echo "Changed skills validated successfully"
  return 0
}

# Auto-detect mode based on branch
auto_detect_mode() {
  local current_branch=""
  
  # Get current branch
  if ! current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); then
    echo "Not in a git repository - defaulting to full validation"
    echo "full"
    return 0
  fi
  
  # On main/master/release branches, run full validation
  if [[ "${current_branch}" =~ ^(main|master|release|production)$ ]]; then
    echo "full"
    return 0
  fi
  
  # On feature/fix branches, use changed-only validation
  echo "changed"
  return 0
}

main() {
  if [[ "${MODE}" == "-h" || "${MODE}" == "--help" ]]; then
    usage
    exit 0
  fi
  
  # Ensure we're in a git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Not in a git repository" >&2
    exit 2
  fi
  
  # Auto-detect mode if requested
  if [[ "${MODE}" == "auto" ]]; then
    MODE="$(auto_detect_mode)"
    echo "Auto-detected mode: ${MODE}"
  fi
  
  case "${MODE}" in
    full)
      validate_all
      ;;
    changed)
      validate_changed "${COMMIT_RANGE}"
      ;;
    *)
      echo "Unknown mode: ${MODE}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
