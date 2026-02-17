# Homelab Consolidation Workflow

## Purpose
Evaluate, consolidate, and restructure the entire atnplex homelab infrastructure.

## Steps

1. **Inventory** — Scan all machines (desktop, laptop, UnRAID, Ubuntu server, OCI VPS 1-3) via Tailscale + SSH
2. **GitHub Audit** — Review all 29+ repos in atnplex org, identify duplicates and consolidation targets
3. **Settings Recovery** — Extract useful rules, workflows, knowledge from old AG instances and conversations
4. **Best Practices Research** — Fetch documentation for each service (Cloudflare, Tailscale, UnRAID, etc.)
5. **Gap Analysis** — Compare current setup against best practices
6. **Architecture Design** — Propose optimized infrastructure layout
7. **Implementation** — Generate IaC (Terraform/Ansible/Docker Compose) for the new setup
8. **Migration** — Execute changes incrementally with rollback procedures

## MCP Profile
`core-dev` (for steps 1-6), `infra-admin` (for steps 7-8)

## Estimated Duration
3-7 days with parallel agent execution
