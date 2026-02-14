# Infrastructure

**Single Source of Truth** for atnplex infrastructure configurations, automation, and deployment baselines.

## Structure

```
infrastructure/
├── oci/                    # Oracle Cloud Infrastructure
│   ├── baseline/           # Universal baseline configurations
│   ├── terraform/          # IaC modules per account
│   └── scripts/            # Deployment and automation scripts
├── mcp/                    # MCP Server configurations
│   ├── registry/           # MCP registry (YAML definitions)
│   ├── servers/            # Custom MCP server code
│   └── profiles/           # Agent profiles (tool subsets)
├── homelab/                # Homelab configurations
│   ├── vps-stack/          # VPS application stacks
│   └── monitoring/         # Monitoring and alerting
└── docs/                   # Documentation
```

## Quick Start

### OCI Deployment

See [`oci/baseline/UNIVERSAL_BASELINE.md`](oci/baseline/UNIVERSAL_BASELINE.md) for complete configuration guide covering:

- 3 accounts (vps1, vps2, vps3)
- AMD utility instances (1OCPU/1GB) + ARM performance instances (4OCPU/24GB)
- Networking, storage (150GB+50GB), security, monitoring
- VPS stack: Paperless-NGX, Vaultwarden, Linkwarden, SimpleLogin

### MCP Servers

See [`mcp/README.md`](mcp/README.md) for MCP architecture and deployment.

## Naming Conventions

- **Instances**: `arm1`, `arm2`, `arm3`, `amd1`, `amd2`, `amd3`
- **VCNs**: `vps1`, `vps2`, `vps3`
- **VNICs**: `vnic1-arm`, `vnic1-amd`, etc.
- **Volumes**: `vol1-perf`, `vol2-perf`, `vol3-perf`

## CIDR Allocation

| Account | VCN         | Public Subnet | Private Subnet | Docker        |
| :------ | :---------- | :------------ | :------------- | :------------ |
| 1       | 10.1.0.0/16 | 10.1.1.0/24   | 10.1.2.0/24    | 172.17.0.0/16 |
| 2       | 10.2.0.0/16 | 10.2.1.0/24   | 10.2.2.0/24    | 172.18.0.0/16 |
| 3       | 10.3.0.0/16 | 10.3.1.0/24   | 10.3.2.0/24    | 172.19.0.0/16 |

## Links

- [OCI Console](https://cloud.oracle.com/)
- [Tailscale Admin](https://login.tailscale.com/admin)
- [Cloudflare Dashboard](https://dash.cloudflare.com/)
- [Bitwarden Secrets Manager](https://vault.bitwarden.com/)
