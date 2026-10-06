#!/usr/bin/env bash

# Performance Improvement #4: Skill deduplication helper
# Detects duplicate skills across plugin variants and provides statistics

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLUGIN_NAME="integrate-jupiter"

usage() {
  cat <<'EOF'
Analyze skill tree duplication and provide deduplication metrics.

Usage:
  bash scripts/analyze_skill_duplication.sh
  bash scripts/analyze_skill_duplication.sh --verbose
  bash scripts/analyze_skill_duplication.sh --check-convergence
  bash scripts/analyze_skill_duplication.sh --estimate-savings

Options:
  --verbose              Show detailed file-by-file comparison
  --check-convergence    Check if all variants are identical
  --estimate-savings     Calculate potential space savings
  -h, --help            Show this help message
EOF
}

compute_dir_size() {
  local dir="$1"
  
  if [[ ! -d "${dir}" ]]; then
    echo "0"
    return 0
  fi
  
  if command -v du >/dev/null 2>&1; then
    du -sb "${dir}" 2>/dev/null | cut -f1
  else
    find "${dir}" -type f -exec stat -c%s {} + 2>/dev/null | awk '{s+=$1} END {print s}'
  fi
}

compute_dir_checksum() {
  local dir="$1"
  
  if [[ ! -d "${dir}" ]]; then
    echo "0"
    return 0
  fi
  
  if command -v md5sum >/dev/null 2>&1; then
    find "${dir}" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    find "${dir}" -type f -exec md5 {} \; | sort | md5 | cut -d' ' -f1
  else
    echo "1"
  fi
}

analyze_deduplication() {
  local verbose="${1:-0}"
  
  echo "========================================="
  echo "Skill Tree Deduplication Analysis"
  echo "========================================="
  echo ""
  
  local canonical="${REPO_ROOT}/skills"
  local codex="${REPO_ROOT}/.plugins/${PLUGIN_NAME}/codex/skills"
  local claude="${REPO_ROOT}/.plugins/${PLUGIN_NAME}/claude/skills"
  
  # Check if directories exist
  if [[ ! -d "${canonical}" ]]; then
    echo "ERROR: Canonical skills directory not found: ${canonical}"
    return 1
  fi
  
  echo "📊 Directory Structure:"
  echo "  Canonical: ${canonical}"
  echo "  Codex:     ${codex}"
  echo "  Claude:    ${claude}"
  echo ""
  
  # Calculate sizes
  echo "📈 Directory Sizes:"
  local canonical_size=$(compute_dir_size "${canonical}")
  local codex_size=$(compute_dir_size "${codex}")
  local claude_size=$(compute_dir_size "${claude}")
  
  echo "  Canonical: $(numfmt --to=iec-i --suffix=B ${canonical_size} 2>/dev/null || echo ${canonical_size} bytes)"
  echo "  Codex:     $(numfmt --to=iec-i --suffix=B ${codex_size} 2>/dev/null || echo ${codex_size} bytes)"
  echo "  Claude:    $(numfmt --to=iec-i --suffix=B ${claude_size} 2>/dev/null || echo ${claude_size} bytes)"
  echo ""
  
  # Compare checksums
  echo "🔍 Content Verification:"
  local canonical_hash=$(compute_dir_checksum "${canonical}")
  local codex_hash=$(compute_dir_checksum "${codex}")
  local claude_hash=$(compute_dir_checksum "${claude}")
  
  if [[ -z "${canonical_hash}" ]] || [[ "${canonical_hash}" == "1" ]]; then
    echo "  WARNING: Cannot compute checksums on this system"
    return 1
  fi
  
  echo "  Canonical hash: ${canonical_hash}"
  echo "  Codex hash:     ${codex_hash}"
  echo "  Claude hash:    ${claude_hash}"
  echo ""
  
  # Check convergence
  if [[ "${canonical_hash}" == "${codex_hash}" ]] && [[ "${canonical_hash}" == "${claude_hash}" ]]; then
    echo "  ✅ All variants are IDENTICAL - safe to deduplicate"
  else
    echo "  ⚠️  Variants DIFFER - cannot safely deduplicate yet"
    if [[ "${verbose}" -eq 1 ]]; then
      echo ""
      echo "  Differences:"
      [[ "${canonical_hash}" != "${codex_hash}" ]] && echo "    - Canonical vs Codex differ"
      [[ "${canonical_hash}" != "${claude_hash}" ]] && echo "    - Canonical vs Claude differ"
    fi
  fi
  echo ""
  
  # Estimate savings
  if [[ "${canonical_hash}" == "${codex_hash}" ]] && [[ "${canonical_hash}" == "${claude_hash}" ]]; then
    echo "💾 Deduplication Potential:"
    local total_size=$((canonical_size + codex_size + claude_size))
    local savings=$((codex_size + claude_size))
    local percent=$((savings * 100 / total_size))
    
    echo "  Total current usage: $(numfmt --to=iec-i --suffix=B ${total_size} 2>/dev/null || echo ${total_size} bytes)"
    echo "  Potential savings:   $(numfmt --to=iec-i --suffix=B ${savings} 2>/dev/null || echo ${savings} bytes) (~${percent}%)"
    echo "  After dedup:         $(numfmt --to=iec-i --suffix=B ${canonical_size} 2>/dev/null || echo ${canonical_size} bytes)"
    echo ""
  fi
  
  # File count analysis
  echo "📁 File Counts:"
  local canonical_files=$(find "${canonical}" -type f | wc -l)
  local codex_files=$(find "${codex}" -type f 2>/dev/null | wc -l || echo 0)
  local claude_files=$(find "${claude}" -type f 2>/dev/null | wc -l || echo 0)
  
  echo "  Canonical: ${canonical_files} files"
  echo "  Codex:     ${codex_files} files"
  echo "  Claude:    ${claude_files} files"
  echo ""
  
  if [[ "${verbose}" -eq 1 ]]; then
    echo "📝 Detailed Breakdown:"
    echo ""
    find "${canonical}" -type d -name "*" | while read -r dir; do
      local name=$(basename "${dir}")
      local count=$(find "${dir}" -type f | wc -l)
      if [[ ${count} -gt 0 ]]; then
        echo "  ${name}: ${count} files"
      fi
    done
  fi
}

check_convergence() {
  echo "Checking skill variant convergence..."
  
  local canonical_hash=$(compute_dir_checksum "${REPO_ROOT}/skills")
  local codex_hash=$(compute_dir_checksum "${REPO_ROOT}/.plugins/${PLUGIN_NAME}/codex/skills")
  local claude_hash=$(compute_dir_checksum "${REPO_ROOT}/.plugins/${PLUGIN_NAME}/claude/skills")
  
  if [[ "${canonical_hash}" == "${codex_hash}" ]] && [[ "${canonical_hash}" == "${claude_hash}" ]]; then
    echo "✅ All variants are converged and identical"
    return 0
  else
    echo "❌ Variants are not identical - sync required"
    return 1
  fi
}

estimate_savings() {
  echo "Estimating deduplication savings..."
  
  local canonical_size=$(compute_dir_size "${REPO_ROOT}/skills")
  local codex_size=$(compute_dir_size "${REPO_ROOT}/.plugins/${PLUGIN_NAME}/codex/skills")
  local claude_size=$(compute_dir_size "${REPO_ROOT}/.plugins/${PLUGIN_NAME}/claude/skills")
  
  local total=$((canonical_size + codex_size + claude_size))
  local savings=$((codex_size + claude_size))
  
  echo "Current usage: $(numfmt --to=iec-i --suffix=B ${total} 2>/dev/null || echo ${total} bytes)"
  echo "Savings:       $(numfmt --to=iec-i --suffix=B ${savings} 2>/dev/null || echo ${savings} bytes)"
  echo "Reduction:     ~$((savings * 100 / total))%"
}

main() {
  local verbose=0
  local check_conv=0
  local estimate=0
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose)
        verbose=1
        shift
        ;;
      --check-convergence)
        check_conv=1
        shift
        ;;
      --estimate-savings)
        estimate=1
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
  
  if [[ ${check_conv} -eq 1 ]]; then
    check_convergence
  elif [[ ${estimate} -eq 1 ]]; then
    estimate_savings
  else
    analyze_deduplication "${verbose}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
