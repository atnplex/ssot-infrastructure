# System Architecture

## Network Topology

```
                 ┌─────────────────┐
                 │  Cloudflare     │
                 │  Zero Trust     │
                 └────────┬────────┘
                          │
              ┌───────────┴───────────┐
              │                       │
     ┌────────▼────────┐    ┌────────▼────────┐
     │ CF Tunnel (VPS1)│    │ CF Tunnel (VPS2)│
     └────────┬────────┘    └────────┬────────┘
              │                       │
     ┌────────▼────────┐    ┌────────▼────────┐
     │   Caddy (VPS1)  │◄──►│   Caddy (VPS2)  │
     │ 100.67.88.109   │    │ 100.102.55.88   │
     └────────┬────────┘    └────────┬────────┘
              │                       │
              └───────────┬───────────┘
                          │ Tailscale Mesh
              ┌───────────▼───────────┐
              │      Unraid           │
              │   100.76.168.116      │
              │  (Media Services)     │
              └───────────────────────┘
```

## Access Patterns

### External (Internet)

```
User → Cloudflare Edge → Zero Trust Auth → CF Tunnel → Caddy → Service
```

### Internal (Tailscale)

```
User (on Tailscale) → Split DNS → Tailscale IP → Service (bypasses CF)
```

## HA Failover

Caddy uses `lb_policy first` with health checks:

1. Primary server handles all traffic
2. If primary fails health check (10s interval)
3. Traffic automatically routes to fallback
4. Recovers when primary is healthy again

## Service Placement

### VPS Services (HA)

- Organizr (VPS2 primary, VPS1 fallback)
- Uptime Kuma (VPS1 primary, VPS2 fallback)
- DNS Resolver (both)
- Antigravity Manager (both)

### Unraid Services (Direct)

- Plex, Radarr, Sonarr, Tautulli, SABnzbd
- No failover (media requires local storage)

## Sync Strategy

| Item | Method | Direction |
|------|--------|-----------|
| Caddyfile | Git + deploy | VPS2 → all |
| MCP config | Git | VPS2 → all |
| Antigravity config | lsyncd | Bidirectional |
| DNS resolver | lsyncd | VPS1 ↔ VPS2 |
