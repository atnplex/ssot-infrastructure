# Multi-Agent SSOT Architecture

## Overview

atnplex runs a distributed multi-agent system where:
- **1 Antigravity orchestrator** (`ag-laptop`) on Windows 11 laptop
- **3 Perplexity Pro accounts** (Comet browser agents: `comet-atnp1`, `comet-atnp2`, `comet-atnp3`)
- **Occasional agents**: GitHub Copilot, Jules, OpenWebUI

All agents share a **Single Source of Truth (SSOT)** via this GitHub repository.

## Synchronization (Day 1: Git-Poll)

Agents sync by running `scripts/sync.ps1` (Windows) or `scripts/sync.sh` (Linux) every 60 seconds. This performs a `git pull --ff-only` to get the latest state.

**Why not a custom notification server?** It's unnecessary complexity on Day 1. Git-poll gives sub-minute sync with zero custom infrastructure. When we need instant push notifications (Day 7+), we'll deploy a notification MCP server to Cloud Run.

## MCP Layer

### Registry

All MCP server definitions live in `config/mcp_registry.json` with metadata:
- `status`: active / planned / deprecated
- `impact`: high / medium / low
- `hosting`: local-stdio / cloud-run / remote-http
- `domain`: what the server covers
- `profileTags`: which profiles include this server

### Profiles

| Profile | Use Case | Servers |
|---------|----------|--------|
| `core-dev` | Code eval, repo consolidation, research | GitHub, Perplexity, Sequential Thinking |
| `infra-admin` | Homelab, networking, secrets | GitHub, Bitwarden, SSH, Tailscale |
| `research` | Best practices, documentation | GitHub, Perplexity, Sequential Thinking |

### Cloud Hosting

Self-hosted MCPs run on Cloud Run in a single GCP project ($300 trial credit):
- Bitwarden MCP — vault/secrets access
- SSH MCP — cross-platform Linux remote execution
- Tailscale MCP — network device management

## Agent Profiles

Each agent has a JSON profile in `config/agent_profiles/` defining:
- Which workflows it can run
- Which MCP profile to use
- Whether auto-sync is enabled

## Adding/Updating Rules

1. Edit files in `agent-state/rules/`, `agent-state/workflows/`, or `agent-state/skills/`
2. Commit and push to `main`
3. All agents pick up changes within 60 seconds

## Adding New MCP Servers

1. Add entry to `config/mcp_registry.json` with full metadata
2. If self-hosted: deploy to Cloud Run, update `remoteUrl`
3. Add to relevant profile(s)
4. Commit and push

---

*Last updated: 2026-02-15*
*Maintained by: ag-laptop orchestrator*
