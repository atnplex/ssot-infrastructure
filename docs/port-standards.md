# Port Standards

> **Rule**: Same host ports everywhere, all services mapped to host.

## Port Range Strategy

| Range | Usage |
|-------|-------|
| 443, 80 | Caddy only (reverse proxy) |
| 9000-9019 | Core services |
| 9020-9030 | **RESERVED: Labs MCP** (Unraid only) |
| 9100-9199 | Monitoring |
| 9700-9799 | Library tools |
| 32400 | Plex (standard) |
| 7878, 8989 | Arr stack (standard) |
| 11434 | Ollama (standard) |

## Service Port Map

| Service | Host Port | Container Port |
|---------|-----------|----------------|
| **Caddy** | 443/80 | 443/80 |
| **AG Manager** | 9045 | 8045 |
| Open WebUI | 9000 | 8080 |
| Uptime Kuma | 9001 | 3001 |
| Logarr Frontend | 9002 | 3000 |
| Headless Frontend | 9003 | 3000 |
| Suggestarr | 9005 | 5000 |
| Headless API | 9008 | 8000 |
| Jellyseerr | 9055 | 5055 |
| Organizr | 9080 | 80 |
| Huntarr | 9705 | 9705 |
| Plex | 32400 | 32400 |
| Radarr | 7878 | 7878 |
| Sonarr | 8989 | 8989 |
| Ollama | 11434 | 11434 |

## Notes

- Keep media apps (Plex, *arr) on standard ports
- Use 9xxx for all custom services
- Same port on ALL servers for same service
