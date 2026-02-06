# Service Catalog

## HA Services (VPS1/VPS2)

| Service | Port | Domain | Primary | Notes |
|---------|------|--------|---------|-------|
| Organizr | 8080 | organizr.atnplex.com | VPS2 | Dashboard |
| Antigravity | 8045 | ag.atnplex.com | VPS2 | LLM proxy |
| Uptime Kuma | 3001 | status.atnplex.com | VPS1 | Monitoring |
| DNS (AdGuard) | 53 | - | VPS1 | Split DNS |

## Media Services (Unraid)

| Service | Port | Domain | Notes |
|---------|------|--------|-------|
| Plex | 32400 | plex.atnplex.com | Media streaming |
| Radarr | 7878 | radarr.atnplex.com | Movie management |
| Sonarr | 8989 | sonarr.atnplex.com | TV management |
| Tautulli | 8181 | tautulli.atnplex.com | Plex analytics |
| SABnzbd | 8080 | sab.atnplex.com | Usenet downloader |

## Internal Services

| Service | Server | Port | Notes |
|---------|--------|------|-------|
| Headless Builder | VPS2 | 3000/8000 | Agent builder |
| MCP Servers | All | (stdio) | Docker-based |

## Adding a New Service

1. Add Docker Compose file to `services/`
2. Add entry to `caddy/Caddyfile`
3. Update this catalog
4. Run `./scripts/deploy-caddy.sh`
5. Add to CF Tunnel (if external access needed)
