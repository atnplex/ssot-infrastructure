# atnplex Infrastructure Inventory

**Last Updated**: February 17, 2026  
**Organization**: atnplex  
**Contributors**: anguy079 (alex), atngit2 (Sijia Li)  
**Location**: Torrance, California

---

## Cloud Infrastructure

### Oracle Cloud Infrastructure (OCI)

**Configuration**: 3-account active-active deployment

| Account | Instance Name | Type | vCPU | RAM | Architecture | Pricing |
|---------|---------------|------|------|-----|--------------|----------|
| vps1 | arm1 | Performance | 4 | 24GB | ARM64 | Always Free |
| vps1 | amd1 | Utility | 1 | 1GB | AMD x86-64 | Always Free |
| vps2 | arm2 | Performance | 4 | 24GB | ARM64 | Always Free |
| vps2 | amd2 | Utility | 1 | 1GB | AMD x86-64 | Always Free |
| vps3 | arm3 | Performance | 4 | 24GB | ARM64 | Always Free |
| vps3 | amd3 | Utility | 1 | 1GB | AMD x86-64 | Always Free |

**Networking**:
- VCN Subnets: 10.X.0.0/16 (X=1,2,3)
- Public: 10.X.1.0/24
- Private: 10.X.2.0/24
- Docker Networks: 172.19.0.0/16, 172.20.0.0/16, 172.21.0.0/16


**Storage**: 200GB per account (150GB for ARM instance boot volume, 50GB for AMD instance boot volume)  

**Replication**: Streaming PostgreSQL replicas on vps2 & vps3 from vps1 primary

---

## Databases & Cache

### PostgreSQL

- **Primary**: arm1 (vps1)
- **Replicas**: arm2 (vps2), arm3 (vps3) — streaming, hot-standby enabled
- **Databases**: atn, immich, vaultwarden, nextcloud, paperless, linkwarden
- **Version**: 16 with pgvecto.rs (vector extension)
- **HA Config**: WAL level=replica, max_wal_senders=5, max_replication_slots=3
- **Resources**: 1GB memory, 0.5 CPU, persistent volumes

### Redis

- **Role**: Job coordinator (Celery, Immich ML, Paperless OCR)
- **Location**: arm2 (vps2)
- **Tailscale IP**: 100.102.55.88 (for cross-account access)
- **Use Cases**: Immich ML job queue, Paperless async OCR tasks

---

## Deployed Services

### Tier 1: Shared Infrastructure (All 3 Accounts)

#### Vaultwarden (Password Manager)
- **Deployment**: All 3 accounts (load-balanced via Cloudflare Tunnel)
- **Database**: Shared PostgreSQL
- **Ports**: 8222 (HTTP), 3012 (WebSocket)
- **Features**: Bitwarden-compatible, TOTP, public signups disabled, invitations enabled
- **Resources**: 256MB memory, 0.25 CPU

#### Nextcloud (File Sync)
- **Deployment**: All 3 accounts
- **Database**: Shared PostgreSQL
- **Domain**: cloud.atnplex.cloud
- **Ports**: 8443
- **Resources**: 512MB memory, 0.5 CPU per instance

#### Immich (Photo Management + ML)

**Server Component** (Stateless, load-balanced):
- **Ports**: 2283
- **Database**: Shared PostgreSQL (immich DB)
- **Redis**: Tailscale 100.102.55.88 for job coordination
- **Resources**: 512MB memory, 0.5 CPU

**ML Worker Component** (Distributed):
- **Workers**: 1 per account (3 total)
- **Capabilities**: Face recognition, object detection, clip embeddings
- **Job Source**: Redis queue (account2)
- **Resources**: 3GB memory, 1.5 CPU (GPU-capable if available)
- **Cache**: Per-instance ML model cache volumes

#### Paperless-NGX (Document Management + OCR)
- **Deployment**: All 3 accounts
- **Components**: App server + Async OCR workers
- **Database**: Shared PostgreSQL
- **Job Queue**: Redis/Celery for task distribution (2 task workers per instance)
- **Domain**: docs.atnplex.cloud
- **Ports**: 8000
- **OCR**: English language support
- **Resources**: 1GB memory, 0.5 CPU per instance

#### Linkwarden (Bookmarks + Notes)
- **Deployment**: All 3 accounts
- **Database**: Shared PostgreSQL (linkwarden DB)
- **Domain**: links.atnplex.cloud
- **Ports**: 3000
- **Features**: Bookmark management, note-taking, AI integration
- **Resources**: 256MB memory, 0.2 CPU

### Tier 2: Account-Specific Services (Account1 Only)

#### Antigravity Manager (AI Model Gateway)
- **Image**: atnplex/antigravity-manager:v4.0.11-atnplex-stable
- **Purpose**: Transform Google Gemini + Anthropic Claude → OpenAI-compatible API
- **Ports**: 127.0.0.1:9045→8045 (localhost-only)
- **Configuration**: Hardened fork with auto-update disabled, rate limiting 100/min
- **Features**:
  - Multi-account management (unlimited Gemini/Claude accounts)
  - Real-time quota monitoring
  - Automatic account rotation
  - OpenAI /v1/chat/completions endpoint
  - Image generation passthrough (when supported by upstream provider)
  - Vision model request passthrough (capabilities depend on upstream models)
  - Basic prompt/context size management
  - Note: Specific model capabilities (e.g., particular image/vision models or compression behavior) depend on configured Gemini/Claude accounts and are not guaranteed by this fork or image tag.
- **Resources**: 128MB memory, 0.15 CPU

#### Jellyseerr (Media Request Interface)
- **Purpose**: User interface for media requests (integrates with unRAID *arr stack)
- **Ports**: 9055→5055
- **Resources**: 384MB memory, 0.25 CPU
- **Note**: Account1 only (single instance)

#### LiteLLM Routing Proxy
- **Purpose**: Intelligent AI model routing across Gemini/Claude
- **Ports**: 4000
- **Configuration**: YAML-based with env file secrets
- **Model Mapping**:
  - gpt-4 → gemini-2.0-flash
  - gpt-4-vision → gemini-2.0-flash (4K vision)
  - claude-3-5-sonnet → gemini-2.0-flash (routes Claude 3.5 Sonnet requests to Gemini 2.0 Flash)
- **Resources**: 256MB memory, 0.2 CPU

### Tier 3: Monitoring & Utilities (Account1)

#### Uptime Kuma (Availability Monitoring)
- **Ports**: 9001→3001
- **Resources**: 256MB memory, 0.2 CPU

#### AdGuard Home (Split DNS)
- **Ports**: 53 TCP/UDP (DNS), 3053→3000 (UI)
- **Resources**: 128MB memory, 0.1 CPU

#### Logarr (Log Aggregation)
- **Ports**: 9002→80
- **Resources**: 128MB memory, 0.1 CPU

### Tier 4: Ingress & Networking (All Accounts)

#### Caddy Reverse Proxy
- **Purpose**: HTTP/HTTPS ingress for all services
- **Ports**: 80, 443
- **Integration**: Routes to Cloudflare Tunnel
- **Resources**: 64MB memory, 0.1 CPU

#### Cloudflared Tunnel Connector
- **Deployment**: Replicated across all 3 OCI accounts
- **Architecture**: 1 tunnel, 3 connectors for high availability
- **Authentication**: TUNNEL_TOKEN (environment variable)
- **Resources**: 64MB memory, 0.1 CPU per instance

#### Watchtower (Container Auto-Update)
- **Schedule**: 0 0 4 * * * (4 AM daily)
- **Cleanup**: Enabled (unused image cleanup)

#### Dozzle (Container Log Viewer)
- **Ports**: 9010→8080
- **Resources**: 64MB memory, 0.05 CPU

---

## Network Architecture

### Public Access
- **Method**: Cloudflare Tunnel (primary)
- **Domains**: atnplex.cloud, cloud.atnplex.cloud, docs.atnplex.cloud, links.atnplex.cloud
- **Exposure**: No direct public IPs; all services behind Tunnel

### Private Access
- **VPN**: Tailscale mesh network
- **Nodes**: Torrance homelab + all 3 OCI instances
- **Security**: OCI security lists + Tailscale ACLs

---

## Subscriptions & API Access

### Perplexity
- **Accounts**: 3+ Pro subscriptions
- **Integration**: Antigravity Manager, ssot-ai multi-agent system

### Google Services
- **Gemini API**: Multi-account, OAuth 2.0, quota monitoring via Antigravity Manager
- **Imagen 3**: Image generation (via Gemini, exposed as OpenAI Images API)
- **Google Cloud**: Available for integrations (project details in OCI/cloud providers)

### Anthropic
- **Claude API**: Multi-account via Antigravity Manager
- **Model**: claude-3-5-sonnet (mapped via Gemini for unified access)
- **Quota Management**: Automatic account rotation when limits reached

---

## AI & ML Infrastructure

### Distributed ML Workers
- **Immich ML**: 3 workers (one per OCI account), coordinated via Redis job queue
- **Paperless OCR**: 2 workers per instance (6 total across 3 accounts), Celery + Redis

### LiteLLM Smart Routing
- Centralized proxy for all model requests
- Automatically route requests across Gemini, Claude, OpenAI-compatible endpoints
- Thinking model support (Opus 4.6 thinking budget injection by default)

---

## Infrastructure Management

### Single Source of Truth (SSOT) Repos
- `ssot-infrastructure`: IaC, bootstrap scripts, MCP configs, deployment manifests
- `ssot-ai`: Agent coordination, MCP registry (13 active servers), Perplexity multi-agent system
- `ssot-secrets`: Zero-touch secrets pipeline for Antigravity Manager + MCP
- `ssot-unraid`: unRAID native configs and homelab state

### CI/CD
- `ssot-actions`: Organization-wide reusable GitHub Actions workflows
- `ssot-bootstrap` & `atn-bootstrap`: Universal setup automation (Docker, MCP servers, Tailscale, Cloudflare)

### MCP Servers
- **Count**: 13 active MCP servers
- **Coordination**: Unified registry in ssot-ai/config/
- **Deployment**: Cloud Run (serverless) + on-premise Tailscale-connected runners

---

## Design Philosophy

✅ **Always-Free Tier Focused**: All OCI instances within Always Free quotas for cost optimization  
✅ **Active-Active Pattern**: Stateless services replicated across 3 accounts for resilience  
✅ **GitOps-First**: Infrastructure as Code (Terraform), version-controlled deployments  
✅ **Minimal Public Exposure**: Cloudflare Tunnel only public entry point; no firewall holes  
✅ **Distributed, Coordinated**: Shared database with streaming replicas; Redis job coordination  
✅ **Automation-Heavy**: Bootstrap scripts, MCP automation, CI/CD workflows

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Cloud Accounts | 3 (OCI) |
| Performance Instances | 3 (arm1-3, 4C/24GB each) |
| Utility Instances | 3 (amd1-3, 1C/1GB each) |
| Database Replicas | 2 (streaming) |
| Active Services | 5 (all 3 accounts) + 3 account-specific = 8 total |
| Cloudflare Connectors | 3 |
| Tailscale Devices | 4+ (homelab + OCI) |
| Total Docker Containers | 55+ (across 3 accounts) |
| MCP Servers | 13 active |
| Monitoring Tools | 3 (Uptime Kuma, AdGuard, Logarr) |

---

## Related Documentation

- [OCI Universal Baseline](https://github.com/atnplex/ssot-infrastructure/blob/main/oci/baseline/UNIVERSAL_BASELINE.md)
- [Architecture Diagram](./ARCHITECTURE.json)
- [Runbooks](https://github.com/atnplex/ssot-infrastructure/blob/main/docs/)
