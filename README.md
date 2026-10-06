# Agent Skills

Skills and packaged plugin metadata for Jupiter-focused AI agents.

The repository follows the [Agent Skills](https://agentskills.io/) format and keeps the source-of-truth documentation under `skills/`, while provider-specific packaged installs live under `.plugins/integrate-jupiter/{codex,claude}`.

## Repository layout

- `skills/` — canonical skill content and examples
- `.plugins/integrate-jupiter/codex/` — Codex plugin bundle used by the local marketplace installer
- `.plugins/integrate-jupiter/claude/` — Claude Code plugin bundle and marketplace metadata
- `scripts/install_plugin.sh` — install or update the packaged plugin for Codex, Claude Code, or both
- `scripts/sync_plugin_skills.sh` — sync `skills/` into the packaged provider folders
- `.agents/plugins/marketplace.json` and `.claude-plugin/marketplace.json` — local marketplace manifests used during development and installation

## Install from GitHub

```bash
git clone https://github.com/perplexiphone-cmd/agent-skills.git
cd agent-skills
bash scripts/install_plugin.sh
```

The installer is interactive by default and lets you choose `codex`, `claude`, or `both`. For a non-interactive setup:

```bash
bash scripts/install_plugin.sh --provider codex
bash scripts/install_plugin.sh --provider claude
bash scripts/install_plugin.sh --provider both
```

## Manual provider installs

Claude Code:

```bash
claude plugin marketplace add /path/to/agent-skills
claude plugin install integrate-jupiter@integrate-jupiter-marketplace
```

Codex:

```bash
bash scripts/install_plugin.sh --provider codex
```

Repo-local Codex install:

1. Open this repository root in Codex.
2. Restart Codex if the workspace was already open so it reloads the local marketplace definition.
3. Open `/plugins`.
4. Install `integrate-jupiter` from the local marketplace.

## Available skills

### integrating-jupiter

Covers the complete Jupiter API surface: swap, lend, perps, trigger, recurring buys, token metadata, pricing, portfolio, prediction markets, send, studio, lock, and routing.

```bash
npx skills add perplexiphone-cmd/agent-skills --skill "integrating-jupiter"
```

### jupiter-lend

Deep integration guidance for Jupiter Lend, including earn, borrow, vault management, and jlToken workflows.

```bash
npx skills add perplexiphone-cmd/agent-skills --skill "jupiter-lend"
```

### jupiter-vrfd

Guidance for Jupiter token verification and metadata submission flows.

```bash
npx skills add perplexiphone-cmd/agent-skills --skill "jupiter-vrfd"
```

### jupiter-swap-migration

Migration guidance for older Metis and Ultra swap integrations moving to Swap API v2.

```bash
npx skills add perplexiphone-cmd/agent-skills --skill "jupiter-swap-migration"
```

## Quick install

```bash
npx skills add perplexiphone-cmd/agent-skills
```

## License

MIT
