<!--
file: docs/policy/05-service-script-patterns.md
repo: homelab_global
owner: alex
created: 2026-01-18
last_reviewed: 2026-01-18
purpose: SSOT patterns for service wrappers, rc.d scripts, and watchdogs.
tags: [policy, bash, service, idempotent, security]
-->

# Service script patterns (SSOT)

## Goals
- Idempotent start/stop/restart/status.
- No secrets in process args or logs.
- Clear validation + clear failure modes.

## Required patterns
- Wrapper indirection: rc.d entrypoint calls a single authoritative control script (one source of truth).
- Token handling:
  - Store tokens in a root-owned file with restrictive permissions (0600).
  - Prefer `--token-file` style flags (never `--token <value>`).
  - Validate token file exists, is non-empty, and contains non-comment content.
- PID + process checks:
  - Use PIDfile; validate with `kill -0`.
  - If process is running without PIDfile, repair PIDfile (optional but recommended).
- Logging:
  - Write logs to a known location; ensure directory exists; avoid log spam.
- Safety:
  - Quote all variables.
  - Fail fast with explicit error messages.
