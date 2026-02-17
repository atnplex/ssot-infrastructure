# Repository Governance Standards

> [!IMPORTANT]
> **Single Source of Truth (SSOT)**: This list defines which repositories are ACTIVE and which are DEPRECATED.
> Agents MUST check this list before cloning or performing work.

## ✅ Active Repositories (The "SSOT" Set)

| Repository                | Purpose                                                                                  | Primary Consumer     |
| :------------------------ | :--------------------------------------------------------------------------------------- | :------------------- |
| **`ssot-infrastructure`** | **The Core Infrastructure SSOT**. All OCI, Tailscale, BWS, and Docker configs live here. | Desktop, Laptop, VPS |
| `ssot-bootstrap`          | Zero-dependency bootstrap scripts for new devices.                                       | Provisioning         |
| `ssot-secrets`            | Secret management logic (BWS wrappers).                                                  | All Agents           |
| `ssot-core`               | Core governance rules and documentation.                                                 | Governance           |
| `ssot-ai`                 | MCP servers and AI configuration.                                                        | AI Agents            |

## ❌ Archived / Legacy Repositories (DO NOT USE)

| Repository | Status                                | Replacement                        |
| :--------- | :------------------------------------ | :--------------------------------- |
| **`atn`**  | **ARCHIVED**. Legacy monolithic repo. | `ssot-infrastructure`, `ssot-core` |
| `homelab`  | Inactive.                             | `ssot-infrastructure`              |
| `setup`    | Inactive.                             | `ssot-bootstrap`                   |

## rules for Agents

1.  **Check Status**: Before cloning a repo, verify it is in the "Active" list above.
2.  **Ignore Archived**: If a search result returns an archived repo, **ignore it**.
3.  **Consolidate**: If you find valuable code in a legacy repo, propose executing a **migration** to the appropriate `ssot-*` repo, then verify the legacy repo is archived.
