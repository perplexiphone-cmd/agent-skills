#!/usr/bin/env bash

# Performance Improvement #7: Skip plugin packaging steps if no skill content changed
# This script checks if any skill files have been modified in the current commit/diff.
# Use in CI workflows to avoid unnecessary build/package steps.
#
# Usage:
#   bash scripts/check_skill_changes.sh [<commit-range>]
#   bash scripts/check_skill_changes.sh origin/main...HEAD  # Check changes from main to current branch
#   bash scripts/check_skill_changes.sh                      # Check unstaged changes

set -euo pipefail

# Detect if we're in a git repo
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not in a git repository" >&2
  exit 2
fi

COMMIT_RANGE="${1:-.}"  # Default to current working directory

# Paths to monitor for skill changes
SKILL_PATHS=(
  "skills/"
  ".plugins/integrate-jupiter/codex/skills/"
  ".plugins/integrate-jupiter/claude/skills/"
)

skill_files_changed() {
  local range="$1"

  # Check if we're looking at a range or working directory
  if [[ "${range}" == "." ]]; then
    # Check staged and unstaged changes in one pass, but only for skill paths.
    if ! git diff --quiet -- "${SKILL_PATHS[@]}" 2>/dev/null; then
      return 0
    fi

    if ! git diff --cached --quiet -- "${SKILL_PATHS[@]}" 2>/dev/null; then
      return 0
    fi
  else
    # Check committed changes in range, filtered to skill paths only.
    if ! git diff --quiet "${range}" -- "${SKILL_PATHS[@]}" 2>/dev/null; then
      return 0
    fi
  fi

  return 1
}

if skill_files_changed "${COMMIT_RANGE}"; then
  echo "Skill content changed - plugin packaging required"
  exit 0
else
  echo "No skill content changed - plugin packaging can be skipped"
  exit 1
fi
