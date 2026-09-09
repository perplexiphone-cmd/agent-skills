#!/usr/bin/env bash

# Performance Improvement #9: Normalize manifest generation
# Generates .mcp.json and plugin.json from templates to reduce duplication
# and prevent metadata drift between Codex and Claude variants.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
PLUGIN_NAME="integrate-jupiter"
PLUGIN_CATEGORY="Developer Tools"
CODEX_MARKETPLACE_NAME="local-plugins"
CODEX_MARKETPLACE_DISPLAY_NAME="Local Plugins"
CLAUDE_MARKETPLACE_NAME="integrate-jupiter-marketplace"

# Skill names to include in manifests
SKILLS=(
  "integrating-jupiter"
  "jupiter-lend"
  "jupiter-swap-migration"
  "jupiter-vrfd"
)

generate_mcp_json() {
  local provider="$1"
  local output_file="$2"
  
  cat > "${output_file}" <<EOF
{
  "mcpServers": {
    "${PLUGIN_NAME}": {
      "command": "node",
      "args": ["path/to/server.js"],
      "env": {
        "PLUGIN_PROVIDER": "${provider}"
      }
    }
  }
}
EOF
  
  echo "Generated MCP manifest: ${output_file}"
}

generate_claude_plugin_json() {
  local output_file="$1"
  
  {
    printf '{\n'
    printf '  "name": "%s",\n' "${CLAUDE_MARKETPLACE_NAME}"
    printf '  "displayName": "%s",\n' "${PLUGIN_NAME}"
    printf '  "category": "%s",\n' "${PLUGIN_CATEGORY}"
    printf '  "skills": [\n'

    local skill=""
    local first_skill=1
    for skill in "${SKILLS[@]}"; do
      if [[ "${first_skill}" -eq 0 ]]; then
        printf ',\n'
      fi
      first_skill=0
      printf '    {\n'
      printf '      "name": "%s",\n' "${skill}"
      printf '      "description": "Jupiter %s skill",\n' "${skill}"
      printf '      "capabilities": ["read", "execute"]\n'
      printf '    }'
    done

    printf '\n  ]\n'
    printf '}\n'
  } > "${output_file}"
  
  echo "Generated Claude plugin manifest: ${output_file}"
}

generate_codex_plugin_json() {
  local output_file="$1"

  {
    printf '{\n'
    printf '  "name": "%s",\n' "${PLUGIN_NAME}"
    printf '  "displayName": "%s",\n' "${PLUGIN_NAME}"
    printf '  "category": "%s",\n' "${PLUGIN_CATEGORY}"
    printf '  "version": "1.0.0",\n'
    printf '  "description": "Jupiter integration plugin for agent skills",\n'
    printf '  "author": "Perplexiphone",\n'
    printf '  "repository": "https://github.com/perplexiphone-cmd/agent-skills",\n'
    printf '  "license": "MIT"\n'
    printf '}\n'
  } > "${output_file}"
  
  echo "Generated Codex plugin manifest: ${output_file}"
}

main() {
  echo "Generating normalized plugin manifests..."
  
  # Create templates directory if needed
  mkdir -p "${REPO_ROOT}/.plugins/templates"
  
  # Generate MCP manifests for each provider
  generate_mcp_json "codex" "${REPO_ROOT}/.plugins/integrate-jupiter/codex/.mcp.json"
  generate_mcp_json "claude" "${REPO_ROOT}/.plugins/integrate-jupiter/claude/.mcp.json"
  
  # Generate plugin-specific manifests
  generate_claude_plugin_json "${REPO_ROOT}/.claude-plugin/marketplace.json"
  generate_codex_plugin_json "${REPO_ROOT}/.plugins/integrate-jupiter/codex/.codex-plugin/plugin.json"
  
  echo "All manifests generated successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
