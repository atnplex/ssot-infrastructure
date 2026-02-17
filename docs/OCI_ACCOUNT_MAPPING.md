# OCI Account Mapping — Single Source of Truth

> [!CAUTION]
> **ALWAYS verify OCI account identity before provisioning or modifying instances.**

## Account Ownership

| Account       | Username      | Email                 | Region       | Tenancy OCID                                                                      |
| :------------ | :------------ | :-------------------- | :----------- | :-------------------------------------------------------------------------------- |
| **Account 1** | `oracleangu`  | anguy079@gmail.com    | us-sanjose-1 | _TBD_                                                                             |
| **Account 2** | `wongkm1alex` | wongkm1alex@gmail.com | us-sanjose-1 | _TBD_                                                                             |
| **Account 3** | `anhnguy079`  | anhnguy079@gmail.com  | us-sanjose-1 | `ocid1.tenancy.oc1..aaaaaaaamtuba2oq276am74zc3a4z4gr32ripzdm63jwpxwygx7g4proxxca` |

## Instance Inventory

| Account | Instance | Shape      | OCPUs | RAM   | Public IP     | Tailscale IP  | Role                                          |
| :------ | :------- | :--------- | :---- | :---- | :------------ | :------------ | :-------------------------------------------- |
| 1       | vps1     | A1.Flex    | 4     | 24 GB | _varies_      | 100.67.88.109 | Primary: streaming, media, PostgreSQL primary |
| 2       | vps2     | A1.Flex    | 4     | 24 GB | _varies_      | 100.102.55.88 | Secondary: secrets, HA, Redis                 |
| 3       | arm3     | A1.Flex    | 4     | 24 GB | 159.54.177.75 | _pending_     | Tertiary: failover, staging                   |
| 3       | amd3     | E2.1.Micro | 1     | 1 GB  | _varies_      | _none_        | Utility (Always Free)                         |

## Pre-Provisioning Checklist

Before any OCI provisioning:

1. **Verify account**: `oci iam tenancy get` → confirm username matches
2. **Verify email**: `oci iam user list` → confirm email matches
3. **List existing instances**: avoid duplicates
4. **Retrieve SSH key**: from BWS or local `~/.ssh/`
5. **Retrieve Tailscale auth key**: from BWS or Tailscale admin console
6. **Document changes**: update this file after provisioning

## MCP Container Config

| Container | Port | OCI Profile | Tenancy                |
| :-------- | :--- | :---------- | :--------------------- |
| `mcp-oci` | 9006 | DEFAULT     | Account 3 (anhnguy079) |
| `mcp-bws` | 9000 | —           | Bitwarden org          |

## Naming Convention

- ARM instances: `arm{N}` (e.g., arm3 = Account 3 ARM)
- AMD instances: `amd{N}` (e.g., amd3 = Account 3 AMD Free Tier)
- Ansible hosts: `vps{N}` (e.g., vps3 = Account 3 primary)
