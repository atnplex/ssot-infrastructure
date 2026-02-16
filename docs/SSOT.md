# Single Source of Truth (SSOT)

This document defines the **Single Source of Truth** for the `atnplex` ecosystem.

## Hierarchy

1.  **Meta-SSOT**: [`atnplex/infrastructure`](https://github.com/atnplex/infrastructure)
    -   **Purpose**: governance, organization-wide scripts, and high-level documentation.
    -   **Contents**:
        -   `scripts/`: Global automation (gardener, auditor, deployer).
        -   `docs/`: Standards (`SSOT.md`, `MCP_DEPLOYMENT.md`).
        -   `.github/`: Reusable workflows.

2.  **Domain SSOTs**:
    -   **HomeLab Specifics**: `atnplex/homelab-ssot` (If used, otherwise fold into infrastructure).
    -   **Bootstrap**: `atnplex/atn-bootstrap` (Docker Compose stacks for nodes).
    -   **Secrets**: `atnplex/atn-secrets-manager`.

## Workflow Standard

All changes must flow through the [Command Center Board](https://github.com/orgs/atnplex/projects/4).
-   **Issues**: Created for every task/bug.
-   **PRs**: Linked to issues.
-   **Merge**: Only after CI passes (Governance workflow).

## Infrastructure Standard

-   **Provisioning**: All nodes are provisioned via `setup` (Ansible/Script) or `atn-bootstrap` (Docker).
-   **Configuration**: No manual config on servers. Config must be committed to the relevant repo.
