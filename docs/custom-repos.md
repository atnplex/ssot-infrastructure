# Custom Repositories

> **Source of Truth**: Always use `atnplex/*` repos, not upstream.

## Key Custom Repos

| Repo | Purpose | Custom Changes |
|------|---------|----------------|
| [antigravity-manager](https://github.com/atnplex/antigravity-manager) | LLM account/API gateway | Hardened: localhost-only, disabled auto-updates |
| [organizr](https://github.com/atnplex/organizr) | Dashboard | Custom PHP modifications |
| [infrastructure](https://github.com/atnplex/infrastructure) | This repo | HA config, Caddyfiles, bootstrap |
| [setup](https://github.com/atnplex/setup) | Universal setup | Docker, MCP, Tailscale, Cloudflared |
| [atn-bootstrap](https://github.com/atnplex/atn-bootstrap) | Bootstrap scripts | Per-server initialization |

---

## Antigravity Manager (Hardened Fork)

**Version**: 4.0.11-atnplex

### Key Customizations

- Localhost-only Docker defaults (security)
- Disabled auto-updates
- Secure env-file configuration
- Rate limiting and circuit breaker patterns

### Deployment

```bash
# Clone from atnplex, NOT upstream
git clone https://github.com/atnplex/antigravity-manager.git

# Docker deployment (port 9045 per standard)
docker run -d \
  --name antigravity-manager \
  --restart unless-stopped \
  -p 127.0.0.1:9045:8045 \
  -v ag-data:/app/data \
  ghcr.io/atnplex/antigravity-manager:latest
```

---

## Organizr (Custom Fork)

### Deployment

```bash
# Clone from atnplex
git clone https://github.com/atnplex/organizr.git

# Docker deployment (port 9080 per standard)
docker run -d \
  --name organizr \
  --restart unless-stopped \
  -p 9080:80 \
  -v organizr-config:/config \
  organizr/organizr
```

---

## Rules

1. **Always use atnplex repos** - not upstream
2. **Check for custom branches** before deploying
3. **Follow port standards** - see [port-standards.md](./port-standards.md)
4. **Use high ports (9xxx)** for host binding
5. **Bind to 127.0.0.1** for security-sensitive services
