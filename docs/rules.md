# Infrastructure Rules

> **Agents must follow these rules when deploying or modifying infrastructure.**

## 1. Discovery First

> [!IMPORTANT]
> **Always run `/inventory` before any infrastructure work.**

```bash
# Discover all Tailscale devices
tailscale status

# Full service discovery (includes stopped containers)
docker ps -a
docker volume ls
ls /srv/compose/
```

## 2. Port Standards

Use **high ports (9xxx)** for host binding:

| Service | Host Port | Container Port |
|---------|-----------|----------------|
| AG Manager | 9045 | 8045 |
| Organizr | 9080 | 80 |
| Open WebUI | 9000 | 8080 |
| Uptime Kuma | 9001 | 3001 |

See [port-standards.md](./port-standards.md) for full list.

## 3. Compute Priority

Use resources in this order:

1. **VPS1/VPS2** (Always On) - Max out these first
2. **Windows Desktop** (Transient) - For temp/GPU tasks
3. **Unraid** (Media Server) - Only if specifically needed

## 4. Custom Repos

**Always use `atnplex/*` repos**, not upstream:

- `atnplex/antigravity-manager` - Hardened fork
- `atnplex/organizr` - Custom PHP modifications

See [custom-repos.md](./custom-repos.md) for details.

## 5. Docker Networking

- All services must map container ports to host ports
- Use same host port across all servers
- Bind security-sensitive services to `127.0.0.1`

```bash
# Good - mapped to host
docker run -p 9045:8045 ...

# Good - localhost only for sensitive services
docker run -p 127.0.0.1:9045:8045 ...

# Bad - no host mapping
docker run ... (no -p flag)
```

## 6. Unraid Specifics

- RAM-based OS - config persists via USB
- Use `go` file for boot-time setup
- Static binaries on USB → tmpfs
- SSH as `root`, not `alex`

## 7. Secrets

Never hardcode secrets. Use Bitwarden Secrets Manager:

```bash
source /atn/github/atn/lib/ops/secrets_bws.sh
TOKEN=$(bws_get_secret "GITHUB_PAT")
```
