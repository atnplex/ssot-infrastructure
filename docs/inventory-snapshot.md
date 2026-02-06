# Server Inventory Snapshot

> Generated: 2026-02-06T01:35Z

## VPS1 (100.67.88.109) - Primary Brain

| Container | Status | Ports |
|-----------|--------|-------|
| antigravity-manager | Up 3 days | 0.0.0.0:8045→8045 |
| caddy | Up 3 weeks | 80, 443 |
| ollama | Up 4 days | 11434 |
| open-webui | Up 3 weeks | 0.0.0.0:3000→8080 |
| uptime-kuma | Up 3 weeks | 0.0.0.0:3010→3001 |
| jellyseerr | Up 3 weeks | 5055 |
| logarr-frontend | Up 3 weeks | 0.0.0.0:3002→3000 |
| logarr-backend | Up 3 weeks | 127.0.0.1:4001→4000 |
| logarr-redis | Up 8 days | 6379 |
| logarr-db | Up 8 days | 5432 |
| vector-receiver | Up 9 days | 0.0.0.0:9000→9000 |
| suggestarr | Up 7 days | 0.0.0.0:5000→5000 |
| huntarr | Up 3 weeks | 0.0.0.0:9705→9705 |
| watchtower | Up 3 weeks | 8080 |

## VPS2 (100.102.55.88) - HA Backup

| Container | Status | Ports |
|-----------|--------|-------|
| antigravity-manager | Up 16 hours | 0.0.0.0:8045→8045 |
| organizr | Up 46 min | 0.0.0.0:8080→80 |
| headless-builder-frontend | Up 18 hours | 0.0.0.0:3000→3000 |
| headless-builder-backend | Up 17 hours | 0.0.0.0:8000→8000 |
| friendly_wescoff | Up 1 hour | (MCP filesystem - orphan) |

## Unraid (100.76.168.116) - Heavy Muscle

### Running Containers

| Container | Status | Ports |
|-----------|--------|-------|
| plex | Up 7 days | (host network) |
| radarr | Up 3 days | 0.0.0.0:7878→7878 |
| sonarr | Up 2 weeks | 0.0.0.0:8989→8989 |
| bazarr | Up 37 hours | 0.0.0.0:6767→6767 |
| prowlarr | Up 37 hours | 0.0.0.0:9696→9696 |
| tautulli | Up 6 days | 0.0.0.0:8181→8181 |
| sabnzbd | Up 13 hours | 0.0.0.0:8081→8080 |
| autoscan | Up 2 weeks | 0.0.0.0:3030→3030 |
| flaresolverr | Up 2 weeks | 0.0.0.0:8191→8191 |
| github-runner | Up 13 hours | - |
| autoheal | Up 13 hours | - |
| vector | Up 39 hours | - |
| postgres | Up 2 weeks | 5432 |
| ddclient | Up 2 days | - |

### Appdata Directories (/mnt/user/appdata/)

autoscan, bazarr, bin, code-server, containers_backup, czkawka, ddclient, duplicati, fileflows, github_runner, huntarr, immich, jellyfin, jellyseerr, npm, organizr, overseerr, pihole, plex, plextraktsync, postgres, prowlarr, python-task-runner, radarr, recyclarr, redis, renamarr, sabnzbd, shoko, sonarr, suggestarr, tautulli, uptimekuma, vector

### Boot Config

- `/boot/config/go` - ATN v10.4 (Golden Master)
- `/boot/config/plugins/dockerMan/templates-user/` - 30+ Docker Manager templates
- Volume `labs_session_data` - Pre-allocated for future Labs MCP
