# Infrastructure

Modular infrastructure management for ATN servers.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/atnplex/infrastructure.git /atn/github/infrastructure
cd /atn/github/infrastructure

# Bootstrap a new server
./bootstrap/setup.sh base docker tailscale caddy

# Or install everything
./bootstrap/setup.sh --all
```

## Structure

```
infrastructure/
├── bootstrap/              # Server bootstrap scripts
│   ├── setup.sh            # Main bootstrap script
│   └── modules/            # Modular install scripts
│       ├── base.sh         # Essential packages
│       ├── docker.sh       # Docker + Compose
│       ├── tailscale.sh    # Tailscale VPN
│       ├── caddy.sh        # Caddy web server
│       ├── lsyncd.sh       # File sync daemon
│       └── mcp.sh          # MCP Docker images
├── caddy/                  # Caddy configuration
│   └── Caddyfile           # Shared Caddyfile (HA)
├── mcp/                    # MCP configuration
│   └── mcp_config.json     # MCP server config
├── scripts/                # Utility scripts
│   ├── deploy-caddy.sh     # Deploy Caddyfile
│   └── sync-check.sh       # Check sync status
├── services/               # Docker Compose files
│   └── (service).yml       # Per-service compose
└── docs/                   # Documentation
    ├── architecture.md     # System architecture
    ├── servers.md          # Server inventory
    └── services.md         # Service catalog
```

## Servers

| Server | Tailscale IP | Role |
|--------|-------------|------|
| VPS1 | 100.67.88.109 | HA secondary |
| VPS2 (condo) | 100.102.55.88 | HA primary |
| Unraid | 100.76.168.116 | Media services |

## Documentation

- [Architecture](docs/architecture.md) - System design and topology
- [Servers](docs/servers.md) - Server inventory and roles
- [Services](docs/services.md) - Service catalog with ports
- [Rules](docs/rules.md) - **Infrastructure rules for agents**
- [Port Standards](docs/port-standards.md) - Port assignments (9xxx range)
- [Custom Repos](docs/custom-repos.md) - atnplex forks and customizations

## Bootstrap Modules

| Module | Description |
|--------|-------------|
| `base` | curl, git, jq, vim, htop |
| `docker` | Docker, Compose, atn_bridge network |
| `tailscale` | Tailscale VPN with route acceptance |
| `caddy` | Caddy with Cloudflare DNS |
| `lsyncd` | File sync daemon |
| `mcp` | MCP Docker images |

## Deploy Caddyfile

After modifying `caddy/Caddyfile`:

```bash
./scripts/deploy-caddy.sh
```

This will:

1. Pull latest from git
2. Validate the Caddyfile
3. Backup current config
4. Deploy and reload Caddy

## Sync Configuration

lsyncd syncs service configs between servers in real-time:

- Antigravity Manager config
- DNS resolver config
- Organizr config
