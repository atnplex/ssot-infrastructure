# Server Inventory

## VPS1

| Property | Value |
|----------|-------|
| **Hostname** | vps1 |
| **Tailscale IP** | 100.67.88.109 |
| **Public IP** | (via Cloudflare) |
| **Role** | HA Secondary |
| **OS** | Debian 12 |

### Services

- Caddy (reverse proxy)
- Cloudflare Tunnel
- Tailscale
- lsyncd
- Docker

---

## VPS2 (Condo)

| Property | Value |
|----------|-------|
| **Hostname** | vps2 / condo |
| **Tailscale IP** | 100.102.55.88 |
| **Public IP** | (via Cloudflare) |
| **Role** | HA Primary |
| **OS** | Debian 12 |

### Services

- Caddy (reverse proxy)
- Cloudflare Tunnel
- Tailscale
- lsyncd
- Docker
- Organizr
- Antigravity Manager
- Headless Builder

---

## Unraid

| Property | Value |
|----------|-------|
| **Hostname** | unraid |
| **Tailscale IP** | 100.76.168.116 |
| **Role** | Media Services |
| **OS** | Unraid |

### Services

- Plex
- Radarr
- Sonarr
- Tautulli
- SABnzbd

---

## SSH Access

```bash
# Via Tailscale
ssh alex@100.67.88.109   # VPS1
ssh alex@100.102.55.88   # VPS2
ssh alex@100.76.168.116  # Unraid
```
