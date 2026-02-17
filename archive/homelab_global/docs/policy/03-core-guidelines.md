<!--
file: docs/policy/03-core-guidelines.md
repo: homelab_global
owner: alex
created: 2026-01-18
last_reviewed: 2026-01-18
purpose: Canonical rules for all repos and all automation (SSOT). These rules are intended to be machine-followable.
tags: [policy, ssot, guidelines, bash, automation, dry, idempotent]
-->

# Core guidelines (SSOT)

## Scope
These rules apply to:
- Any script in `scripts/` and any repo automation pipeline.
- Any repo content promoted into `templates/`.
- Any AI-assisted editing in this repo and downstream repos.

## Non-negotiables
- DRY: define standards once here; downstream repos consume them.
- Idempotent: scripts must be safe to re-run and must not create duplicate state.
- Deterministic: same inputs -> same outputs (paths, formatting, structure).
- No secrets in Git: never commit tokens, keys, cert private keys, `.env` files.

## Bash / shell safety rules
- Always quote variables unless intentional word splitting is explicitly required and documented.
- Validate inputs early (required vars, required files, required commands); fail fast with a clear error message.
- Avoid parsing `ls`; use `find`, `glob`, or `git ls-files` for file lists.
- Prefer `set -euo pipefail` in executables; libraries must not call `exit`.

## Structural integrity rules
- Do not delete content unless explicitly requested.
- Ensure 2-sided constructs match: quotes, braces, parentheses, heredoc fences, Markdown fences.
- Ensure every referenced function/command is defined or is a declared dependency.
- Preserve interfaces: do not change flags/CLI output formats unless explicitly requested.

## Tooling-first workflow
- Run formatters/linters first (shfmt, shellcheck, gitleaks).
- Only then use AI to interpret warnings/errors and apply minimal diffs.
- Always re-run the gate and review `git diff` before committing.

## Promotion rule (SSOT vs template)
- `docs/policy/`: the rulebook (what must be followed).
- `templates/`: reusable artifacts only after review and intentional promotion.
- `docs/reviews/<repo>/candidates/`: staging area; nothing here is “global” until promoted.
