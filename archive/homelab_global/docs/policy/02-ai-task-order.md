<!--
file: docs/policy/02-ai-task-order.md
repo: homelab_global
owner: alex
created: 2026-01-17
last_reviewed: 2026-01-17
purpose: Ordered, deterministic pipeline for AI-assisted repo changes (lint/format first, AI review second).
tags: [policy, ai, workflow, qa, dry]
-->

# AI task order (SSOT)

This file defines the *required order* AI (Copilot/MCP/other) must follow when asked to refactor, standardize, or clean content. 

## Scope rule (DRY boundary)

Before making changes, AI must respect settings scope boundaries:
- User settings = personal global defaults (not committed).
- Workspace/repo settings = portable project defaults in `.vscode/`.
- Host/Remote settings = host-specific, not assumed portable. 

See also: `docs/policy/01-settings-scope.md`.

## Required processing pipeline (in order)

1) Inventory
- Identify file types and intended behavior (script vs doc vs config).
- Identify whether the change is purely formatting vs functional.

2) Run tooling first (mechanical changes)
- Run: `make qa-check`
- If tools are missing, install or use Docker-based equivalents.

3) Apply safe auto-fixes (only if needed)
- Run: `make strip-citations` (remove Perplexity-style markers).
- Run: `make fmt` (formatter; currently shell).
- Re-run: `make qa-check`

4) Fix linter errors/warnings
- If ShellCheck reports issues, apply minimal fixes first (do not rewrite).
- Re-run: `make qa-check` until green. (ShellCheck exit codes are meaningful for gates.) 

5) Review changes vs original (human/AI review step)
- Run: `make diff-status`
- Ensure no sections were accidentally removed.
- Ensure behavior is retained; do not change interfaces unless requested.

6) Commit discipline
- Small commits per logical change.
- Commit message should identify: formatting vs lint fixes vs functional changes.

## MCP usage rule

MCP servers are allowed to assist, but should not replace deterministic tooling.
Tooling output is authoritative; AI should focus on:
- Explaining the warning/error
- Fixing it with minimal diffs
- Verifying no regressions via diff + rerun. 

## 7) Documentation & Metadata Updates (REQUIRED)

Every functional change performed by AI must include documentation updates:
1. **Changelog**: Append a concise entry to `docs/automation/CHANGELOG_AI.md`.
   - Format: `- [timestamp] [Component] Description of fix/refactor.`
2. **README/Docs**: If a script's usage, arguments, or behavior changes, update the corresponding `README.md` or relevant `docs/` file immediately.
   - Constraint: Do not leave documentation stale.

## 8) Automation Portability & Permissions (REQUIRED)

All AI changes that touch automation must follow: `docs/policy/03-automation-portability-and-perms.md`.
