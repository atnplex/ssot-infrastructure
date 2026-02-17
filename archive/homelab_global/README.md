<!--
file: README.md
repo: homelab_global
owner: alex
created: 2026-01-17
last_reviewed: 2026-01-17
purpose: SSOT for standards, templates, AI prompts, and consolidation guidance across Unraid/VPS/Windows.
tags: [homelab, ssot, vps, unraid, vscode, mcp, copilot, git]
-->

# homelab_global (SSOT)

This repository is the SSOT for global standards, templates, and documentation across hosts (Windows control plane, Unraid, Debian VPS), and it exists to reduce drift by making standards explicit and versioned. 

## Goals

- Determinism: same inputs → same outputs (paths, permissions, repo layout).
- DRY: standards are defined once here and consumed elsewhere (not duplicated).
- AI-friendly: structure + rules are explicit so Copilot/MCP can follow them consistently. 

## Repository layout

```text
.
├── README.md
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .vscode/                     # Workspace/repo-scoped settings (portable). [code.visualstudio](https://code.visualstudio.com/docs/configure/settings)
├── .github/                     # Repo automation + AI assets (portable).
├── docs/
│   ├── policy/                  # Hard rules (scopes, naming, DRY boundaries).
│   └── inventory/               # Consolidation tracker and repo inventory.
├── templates/                   # Canonical templates to apply to other repos.
└── scripts/                     # Helper scripts for maintenance/bootstrap (optional).
```

## Settings scope (critical)

VS Code and tooling settings are intentionally scoped; this repo enforces scope boundaries to prevent accidental global drift. 

See: `docs/policy/01-settings-scope.md`.

## MCP (Awesome Copilot)

MCP servers can be configured at workspace/repo scope via `.vscode/mcp.json`.   
This repo includes a Docker-based `awesome-copilot` MCP definition; it will work when VS Code is connected to a host that can run Docker (e.g., VPS/Unraid Remote-SSH sessions with Docker available). 

## Consolidation workflow (current focus)

Start here: `docs/inventory/00-consolidation-plan.md` to capture repo lists and classify them before migrating content. 
