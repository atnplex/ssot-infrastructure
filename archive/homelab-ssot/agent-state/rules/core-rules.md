# Core Agent Rules

These rules apply to ALL agents in the atnplex ecosystem.

## SSOT Rules

1. **Never manually edit generated configs** — all config changes flow through SSOT files in this repo
2. **Always sync before starting work** — run `sync.ps1` or `sync.sh` before beginning any session
3. **Commit state changes to this repo** — if you update rules, workflows, or knowledge, push to `main`

## MCP Rules

4. **Keep active tool count under 60** — Antigravity hard-limits at ~100; stay well below
5. **Use MCP profiles** — don't enable all servers at once; use profile-based filtering
6. **Never hardcode credentials** — use environment variables or Secret Manager references

## Operational Rules

7. **Ask for credentials, don't guess** — if you need an API key or password, ask the operator
8. **Log progress** — update `logs/setup-log.md` with timestamped entries after completing each phase
9. **Prefer official MCP servers** — use vendor/official MCP servers over community forks for security-sensitive operations
10. **Document decisions** — add rationale to `agent-state/knowledge/` so other agents can learn
