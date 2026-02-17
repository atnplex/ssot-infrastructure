<!--
file: docs/inventory/00-consolidation-plan.md
repo: homelab_global
owner: alex
created: 2026-01-17
last_reviewed: 2026-01-17
purpose: Plan for consolidating many repos into a single SSOT and standardizing templates and policies.
tags: [inventory, consolidation, migration, ssot]
-->

# Consolidation plan (skeleton)

## Goal
Consolidate existing repos (personal `anguy079/*` and org `atnplex/*`) into a clear SSOT with explicit standards and templates. 

## Phases
1) Inventory: list repos, classify by type (device / service / tooling / docs / experiments). 
2) Extract standards: identify your best `.vscode/`, `.github/`, formatting rules, templates, and prompts and centralize them here. 
3) Publish templates: add `templates/repo-bootstrap` and enforce with CI later.
4) Migrate repos: move/rename and update to inherit templates.

## Rules
- Do not commit secrets (PATs, tokens, TLS private keys, `.env`). 
- This repo holds templates + policy; other repos consume them.
