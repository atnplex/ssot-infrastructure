# homelab-ssot

Single Source of Truth (SSOT) for the atnplex multi-agent homelab infrastructure.

## What This Repo Does

Every agent in the atnplex ecosystem — Antigravity (AG), Perplexity/Comet browsers, GitHub Copilot, etc. — pulls its settings, rules, workflows, and MCP server definitions from this repository.

## How Sync Works (Day 1)

Agents run `scripts/sync.ps1` (Windows) or `scripts/sync.sh` (Linux) every 60 seconds to `git pull` the latest state. No custom notification server required on Day 1.

**Future**: Upgrade to push-based notification server on Cloud Run when agent count or update frequency demands it.

## Project Management

All tasks, features, and bugs are tracked in the **[atnplex Command Center](https://github.com/orgs/atnplex/projects/4)**. This project board is the Single Source of Truth for work status.

## Directory Structure

```
homelab-ssot/
├── config/                  # MCP and agent configuration
│   ├── mcp_registry.json    # All MCP server definitions + metadata
│   └── agent_profiles/      # Per-agent settings
├── agent-state/             # Shared agent state
│   ├── rules/               # Shared rules all agents follow
│   ├── workflows/           # Shared workflow definitions
│   ├── skills/              # Shared skill/tool definitions
│   └── knowledge/           # Shared knowledge base
├── scripts/                 # Sync and utility scripts
├── docs/                    # Architecture and reference docs
└── logs/                    # Setup and progress logs
```

## Quick Start

1. Clone: `git clone https://github.com/atnplex/homelab-ssot.git`
2. Copy your agent profile from `config/agent_profiles/`
3. Run sync: `./scripts/sync.sh` or `.\scripts\sync.ps1`

## Rules

- **Never manually edit** generated configs — use the SSOT files
- **Always commit** changes via PR or direct push to `main`
- **Keep tool count < 60** per agent to stay under Antigravity's 100-tool limit
