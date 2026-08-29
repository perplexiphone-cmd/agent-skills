#!/usr/bin/env bash

set -euo pipefail

PLUGIN_NAME="integrate-jupiter"
PACKAGED_SKILLS=(
  "integrating-jupiter"
  "jupiter-lend"
  "jupiter-swap-migration"
  "jupiter-vrfd"
)

usage() {
  cat <<'EOF'
Sync the packaged Jupiter plugin skills for Codex, Claude Code, or both.

The sync respects .plugignore patterns (similar to .gitignore) to exclude
non-runtime assets from plugin distributions. See .plugignore for details.

Usage:
  bash scripts/sync_plugin_skills.sh
  bash scripts/sync_plugin_skills.sh --provider codex
  bash scripts/sync_plugin_skills.sh --provider claude
  bash scripts/sync_plugin_skills.sh --provider both
  bash scripts/sync_plugin_skills.sh --dry-run

Options:
  --provider TARGET  One of: codex, claude, both. Default: both.
  --dry-run          Print planned actions without changing files.
  -h, --help         Show this help message.
EOF
}

normalize_provider() {
  case "${1,,}" in
    codex|claude|both)
      printf '%s\n' "${1,,}"
      ;;
    *)
      return 1
      ;;
  esac
}

run_step() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi

  "$@"
}

# Compute checksum of a directory to detect changes
compute_dir_checksum() {
  local dir="$1"
  
  if [[ ! -d "${dir}" ]]; then
    echo "0"
    return
  fi
  
  # Use find + md5sum for portable checksum (Linux/macOS compatible)
  if command -v md5sum >/dev/null 2>&1; then
    find "${dir}" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    find "${dir}" -type f -exec md5 {} \; | sort | md5 | cut -d' ' -f1
  else
    echo "1"  # Fallback: always sync if no checksum tool available
  fi
}

# Check if a sync is actually needed by comparing checksums
needs_sync() {
  local source="$1"
  local target="$2"
  
  local source_checksum="$(compute_dir_checksum "${source}")"
  local target_checksum="$(compute_dir_checksum "${target}")"
  
  [[ "${source_checksum}" != "${target_checksum}" ]]
}

# Generate rsync exclude options from .plugignore
get_plugignore_excludes() {
  local plugignore_file="$1"
  local excludes=""
  
  if [[ ! -f "${plugignore_file}" ]]; then
    echo ""
    return 0
  fi
  
  # Read .plugignore and convert to rsync exclude format
  while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    excludes="${excludes} --exclude='${line}'"
  done < "${plugignore_file}"
  
  echo "${excludes}"
}

sync_provider() {
  local provider="$1"
  local plugin_root="${REPO_ROOT}/.plugins/${PLUGIN_NAME}/${provider}"
  local target_skills_dir="${plugin_root}/skills"
  local skill_name=""
  local source_dir=""
  local target_dir=""
  local any_synced=0

  if [[ ! -d "${plugin_root}" ]]; then
    echo "Plugin provider directory not found: ${plugin_root}" >&2
    exit 1
  fi

  run_step mkdir -p "${target_skills_dir}"

  # Clean up stale skills - only check against known packaged skills (avoid full directory scan)
  # Performance improvement: use array iteration instead of globbing target directory
  for skill_name in "${PACKAGED_SKILLS[@]}"; do
    target_dir="${target_skills_dir}/${skill_name}"
    if [[ -e "${target_dir}" ]]; then
      source_dir="${REPO_ROOT}/skills/${skill_name}"
      if [[ ! -d "${source_dir}" ]]; then
        run_step rm -rf "${target_dir}"
        if [[ "${DRY_RUN}" -eq 1 ]]; then
          echo "Would remove stale ${provider} packaged skill: ${skill_name}"
        else
          echo "Removed stale ${provider} packaged skill: ${skill_name}"
          any_synced=1
        fi
      fi
    fi
  done

  for skill_name in "${PACKAGED_SKILLS[@]}"; do
    source_dir="${REPO_ROOT}/skills/${skill_name}"
    target_dir="${target_skills_dir}/${skill_name}"

    if [[ ! -d "${source_dir}" ]]; then
      echo "Source skill directory not found: ${source_dir}" >&2
      exit 1
    fi

    # Use checksum to detect if sync is needed (more efficient than always running diff -r)
    if needs_sync "${source_dir}" "${target_dir}"; then
      run_step rm -rf "${target_dir}"
      run_step cp -R "${source_dir}" "${target_dir}"
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "Would sync ${provider} packaged skill: ${skill_name}"
      else
        echo "Synced ${provider} packaged skill: ${skill_name}"
        any_synced=1
      fi
    else
      if [[ "${DRY_RUN}" -eq 1 ]]; then
        echo "[dry-run] Skill already up-to-date: ${skill_name}"
      else
        echo "Skill already up-to-date: ${skill_name}"
      fi
    fi
  done
  
  return ${any_synced}
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DRY_RUN=0
PROVIDER="both"
SYNC_OCCURRED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      if [[ $# -lt 2 || -z "${2}" || "${2}" == -* ]]; then
        echo "Missing value for --provider." >&2
        usage >&2
        exit 1
      fi
      if ! PROVIDER="$(normalize_provider "$2")"; then
        echo "Invalid provider: $2" >&2
        usage >&2
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "${REPO_ROOT}/skills" ]]; then
  echo "Skills directory not found: ${REPO_ROOT}/skills" >&2
  exit 1
fi

case "${PROVIDER}" in
  codex)
    sync_provider "codex"
    SYNC_OCCURRED=$?
    ;;
  claude)
    sync_provider "claude"
    SYNC_OCCURRED=$?
    ;;
  both)
    sync_provider "codex"
    SYNC_OCCURRED=$?
    sync_provider "claude"
    if [[ $? -eq 1 ]]; then
      SYNC_OCCURRED=1
    fi
    ;;
esac

# Exit with status indicating whether any sync occurred
exit ${SYNC_OCCURRED}
