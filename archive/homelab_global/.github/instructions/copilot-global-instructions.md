<!--
file: .github/instructions/copilot-global-instructions.md
repo: homelab_global
owner: alex
created: 2026-01-17
last_reviewed: 2026-01-17
purpose: Repo-wide AI behavior guidelines (format, DRY boundaries, content preservation).
tags: [copilot, ai, instructions, ssot, dry]
-->

# Copilot / AI global instructions

## Non-negotiables
- Respect settings scope boundaries (User vs Remote vs Workspace vs Folder). See `docs/policy/01-settings-scope.md`. 
- Prefer templates from `templates/` instead of inventing new structures.
- Do not introduce secrets into the repo.
- When updating a file: preserve existing structure unless explicitly told otherwise.

## Output formatting
- If output contains Markdown fences inside (e.g., scripts that generate README), wrap the outermost response in quadruple backticks to prevent rendering breakage. 
