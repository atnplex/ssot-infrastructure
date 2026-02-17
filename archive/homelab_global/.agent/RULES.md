# UNIVERSAL NAMESPACE RULES

**Version**: 1.6.0 | **Authority**: [R0: Precedence](#r0)

### R0: PRECEDENCE

**Global Namespace Rules (this ecosystem) prevail over repo-specific rules.** Conflicts resolve to Global unless `[OVERRIDE_ALLOWED]` is specified.

---

## Core Principles (AI-FAST)

1. **Env-First**: Detect (system|wsl|target) before acting.
2. **No Hardcoding**: Derive via `namespace_env.py` (Respect `$NAMESPACE`).
3. **Canonical**: Use UTC (ISO8601Z) and smallest integer units (bytes, ms).
4. **Python-Spine**: All logic in Python (Modular|Deterministic|Idempotent).
5. **Stability**: Enforce stable workspace modes (Local|Remote-WSL).

---

## Rule Modules (Dense)

- [01: Environment & Stability](file:///namespace/github/atnplex/repo-integrations/00-baseline/rules/environment.md)
- [02: Paths & Canonicals](file:///namespace/github/atnplex/repo-integrations/00-baseline/rules/paths.md)
- [03: Execution & Autonomy](file:///namespace/github/atnplex/repo-integrations/00-baseline/rules/execution.md)
- [04: Governance & Health](file:///namespace/github/atnplex/repo-integrations/00-baseline/rules/governance.md)
- [05: Formatting Standards](file:///namespace/github/atnplex/repo-integrations/00-baseline/rules/formatting.md)
- [06: Scripting Standards](file:///namespace/github/atnplex/repo-integrations/00-baseline/rules/scripting.md)

---

## Dynamic Variables

| Target | Variable | Default |
| :--- | :--- | :--- |
| Config | `NAMESPACE` | `atn` |
| Windows | `$ROOT_WIN` | `C:\$NAMESPACE` |
| Linux | `$ROOT` | `/$NAMESPACE/` |
