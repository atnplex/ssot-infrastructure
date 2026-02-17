<!--
file: docs/policy/01-settings-scope.md
repo: homelab_global
owner: alex
created: 2026-01-17
last_reviewed: 2026-01-17
purpose: Defines where settings live (User vs Remote vs Workspace vs Folder) to enforce DRY and prevent configuration drift.
tags: [policy, vscode, scopes, dry, ssot]
-->

# Settings scope policy

This repo treats configuration scope as a hard boundary to keep things DRY and predictable. 

## Scope definitions (VS Code)

- User settings: Personal defaults across all projects; not stored in Git; should be managed via Settings Sync. 
- Remote settings (Remote-SSH): Host-specific behavior for a given remote (e.g., server install path); not assumed portable; avoid committing unless explicitly intended. 
- Workspace settings (repo-level): Shared, project/workspace defaults that SHOULD be consistent wherever the repo is opened; stored in `.vscode/settings.json`. 
- Folder settings (multi-root workspaces): Overrides that apply only to a specific folder within a `.code-workspace`; use sparingly and document why. 

## DRY rules (hard)

- If a setting should apply everywhere: it belongs in User settings.
- If a setting is host-specific: it belongs in Remote settings and must be documented as host-specific.
- If a setting is repo-specific and should travel with the repo: it belongs in `.vscode/`.
- Any exception must be documented in this file.
