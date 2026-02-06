# Server Inventory

## Resource Limitations

| Server | Limitation |
|--------|------------|
| VPS1/VPS2 | OCI Free Tier - limited storage & egress |
| Unraid | Remote location, 350Mbps symmetric |
| Windows | Transient (dev sessions only) |

---

## VPS1 (OCI - Primary Brain)

| Property | Value |
|----------|-------|
| **Tailscale IP** | 100.67.88.109 |
| **Role** | Primary Brain (Always On) |
| **Tier** | OCI Free Tier |
| **RAM** | 24GB |
| **CPU** | 4 cores |
| **Disk** | 52GB free |
| **Limit** | Egress/Storage |

### Running Services

- AG Manager Proxy (8045) ★
- Caddy (443)
- Uptime Kuma (3010)
- Jellyseerr (5055)
- Open WebUI (3000)
- Ollama (11434)
- Logarr stack

---

## VPS2 (Condo - HA Backup)

| Property | Value |
|----------|-------|
| **Tailscale IP** | 100.102.55.88 |
| **Role** | HA Backup Brain |
| **RAM** | 24GB |
| **CPU** | 4 cores |
| **Disk** | 155GB free |

### Running Services

- AG Manager Proxy (8045) ★
- Caddy (443)
- Organizr (8080)
- Headless Builder (3000/8000)

---

## Unraid (Heavy Muscle)

| Property | Value |
|----------|-------|
| **Tailscale IP** | 100.76.168.116 |
| **Role** | Media + Compute |
| **RAM** | 96GB |
| **CPU** | i5-10400 (6C/12T) |
| **GPU** | Intel QuickSync |
| **Availability** | Usually On |
| **Network** | 350Mbps symmetric |

### Unraid-Specific Constraints

> [!WARNING]
> Unraid is RAM-based - config persists differently!

- **Persistence**: USB flash for persistent configs
- **Boot Script**: `go` file must create `/atn` namespace
- **Core Networking**: Static binaries (Caddy, cloudflared) on USB → tmpfs
- **Tailscale**: Already installed as plugin ✓
- **Permissions**: Different ownership model than Linux

### Services

- Plex (32400) + QuickSync transcoding
- Radarr (7878), Sonarr (8989), Tautulli (8181)
- *Potential*: Ollama, Heavy MCPs

---

## Windows Desktop (GPU Muscle)

| Property | Value |
|----------|-------|
| **Role** | GPU Tasks (transient) |
| **RAM** | 32GB |
| **GPU** | RTX 3080 |
| **Availability** | Dev sessions only |

### When Available

- Ollama + GPU (fast inference)
- Playwright browser testing
- Heavy compilations

---

## SSH Access

```bash
ssh alex@100.67.88.109   # VPS1
ssh alex@100.102.55.88   # VPS2
ssh root@100.76.168.116  # Unraid
```
