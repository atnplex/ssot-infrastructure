# Automation Portability & Permissions Contract

## Goals
- Automation must run on: GitHub Actions (github-hosted runners), VPS (Debian), and other Linux hosts without editing paths.
- Avoid ownership drift and permission breakage over time.

## Portability rules (REQUIRED)
- Never hardcode absolute host paths (e.g. `/srv/...`) in automation scripts unless gated by an environment switch.
- Derive repo root dynamically:
  - `REPO="${REPO:-$(git rev-parse --show-toplevel)}"`
- GitHub Actions:
  - Use `GITHUB_WORKSPACE` as the checked-out repo path.
  - Use `RUNNER_TEMP` (fallback `/tmp`) for writable scratch/log/worktree directories.
- Provide overrides:
  - `RUN_BASE` may be set externally; otherwise choose a safe default based on environment.

## Idempotency rules (REQUIRED)
- Scripts must be safe to run repeatedly:
  - Use `mkdir -p`.
  - Only delete within directories the script created (under `RUN_BASE`).
  - Prefer `mktemp -d` + `trap` cleanup for ephemeral work.
- Before pushing branches/PRs, scripts must detect “no-op” changes and skip branch creation.

## Shell safety rules (REQUIRED)
- After any change to `scripts/automation/*.sh`, run `make qa-check`.
- Do not introduce broken quoting patterns (ShellCheck SC2027), e.g. never generate `""$VAR""`; use `"${VAR}"` or `"${VAR}/suffix"`.

## Permissions model (VPS)
- VPS canonical group for repo workspace: `dev`.
- Enforce group inheritance using setgid on directories.
- Enforce group-writable defaults using ACLs (default ACLs prevent drift for new files/dirs).

## Cross-host notes
- unRAID may expect `nobody:users` on shares; automation must not assume `dev` exists on all hosts.
- Scripts should default to the current user’s primary group when host-specific groups are unknown.
