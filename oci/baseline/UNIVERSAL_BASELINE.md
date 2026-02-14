# Universal OCI Baseline v3.0 - Account 3 Deployment

**Version**: 3.0.0  
**Date**: 2026-02-14  
**Scope**: Account 3 (Initial), extendable to 1 & 2  
**Status**: Ready for Deployment

---

## Architectural Changes from v2.0

### 1. Simplified `/atn` Structure

**OLD** (v2.0):

```
/atn/
└── .ignore/        # Hidden middleman
    ├── secrets/
    └── state/
```

**NEW** (v3.0):

```
/atn/
├── .secrets/       # Direct dotfolder (700 perms)
├── .state/         # Direct dotfolder (700 perms)
├── tmp/            # tmpfs (50% RAM, cleared on reboot)
├── logs/           # tmpfs (1GB, cleared on reboot)
├── appdata/        # Persistent container data
├── config/         # Service configs
└── github/         # Git repos
```

**Rationale**: Removed unnecessary `.ignore` nesting. All private/sensitive data goes in `.secrets`, state tracking in `.state`. Both are hidden dotfolders with restrictive permissions.

### 2. Security-First Cloud-Init Flow

**Process** (was: install everything, then harden):

1. ✅ Install BWS CLI
2. ✅ Setup age encryption (generate key in `/atn/.secrets/age.key`)
3. ✅ Install Tailscale + authenticate (fetch auth key from BWS)
4. ✅ **WAIT** → Verify Tailscale connected
5. ✅ Harden SSH → `ListenAddress <tailscale_ip>` (DISABLE public SSH)
6. ✅ Install Docker + create `atn_bridge` network
7. ✅ Configure firewall (UFW disabled, OCI security lists handle ingress)

**Key Change**: SSH hardening happens **AFTER** Tailscale confirmed, not before. This prevents lockout if Tailscale fails.

### 3. Consolidated Code from Existing Repos

**Sources**:

- **oracle-cloud-vps/BASELINE.md** → Cloud-init structure, network config, validation checklist
- **atn/scripts/setup/setup_bws.sh** → BWS installer logic (checksum verification, token management)
- **atn/lib/ops/secrets_bws.sh** → BWS secret fetching (`bws_get_secret`, `bws_export_dotenv`)
- **atn/scripts/setup/refresh_secrets.sh** → Force refresh secrets from BWS

**Consolidation**: Merged all logic into `cloud-init/base-template.yml` for idempotent deployment.

### 4. Storage Allocation (Final)

**Account 3** (Free Tier):

- **AMD Boot**: 50 GB (Ubuntu 24.04 LTS Minimal)
- **ARM Boot**: 150 GB (expanded boot volume, NO separate block volume)
- **Total**: 200 GB ✅ (within Always Free limit)

**Block Volumes**: REMOVED (simplified to expanded boot volumes only)

### 5. Galera Clustering (Deferred to Phase 2)

**Current** (Account 3 only): No Galera cluster (single account, single ARM instance)  
**Future** (Accounts 1+2+3): Equal weights + Galera Arbitrator on AMD

**Rationale**: Start simple with Account 3, add HA after validating baseline.

---

## Account 3 Deployment Spec

### Naming Convention

| Resource       | Name               | CIDR/IP         | Notes                                 |
| -------------- | ------------------ | --------------- | ------------------------------------- |
| VCN            | `vcn3`             | `10.12.0.0/16`  | Updated to start at 10.10.x.x         |
| Public Subnet  | `public-subnet-3`  | `10.12.1.0/24`  | AMD instance                          |
| Private Subnet | `private-subnet-3` | `10.12.2.0/24`  | ARM instance (future Galera node)     |
| AMD Instance   | `amd3`             | `10.12.1.10`    | VM.Standard.E2.1.Micro (1 OCPU, 1 GB) |
| ARM Instance   | `arm3`             | `10.12.2.20`    | VM.Standard.A1.Flex (4 OCPU, 24 GB)   |
| Docker Bridge  | `atn_bridge`       | `172.25.0.0/16` | Custom network (not docker0)          |

**Note**: CIDR scheme updated to `10.10-12.0.0/16` (was `10.1-3.0.0/16` in old baseline)

### Instance Details

#### AMD3 (Utility Instance)

**Purpose**: Always-on gateway, networking services, MCP servers (external + local fallback)

**Boot Volume**: 50 GB (Ubuntu 24.04 LTS Minimal)

**Services** (systemd, NOT Docker to avoid host dependency):

- **Tailscale**: Subnet routing for `10.12.0.0/16` + `172.25.0.0/16`
- **Cloudflare Tunnel**: Ingress for web services
- **CoreDNS**: DNS resolver (systemd service, NOT Docker)
- **Vector**: Log sink (receives from ARM3)

**MCP Servers** (Docker on `atn_bridge`):

- External: Perplexity, GitHub (already available)
- Local fallback: TBD (if Google Cloud HA not deployed yet)

**Ports** (standardized 9xxx-9999):

- MCP servers: TBD (will define per service)

#### ARM3 (Performance Instance)

**Purpose**: Compute workloads, databases, web services

**Boot Volume**: 150 GB (expanded, Ubuntu 24.04 LTS Minimal)

**Services** (Docker on `atn_bridge`):

- **Vaultwarden** → 9900 (host) → 80 (container)
- **SimpleLogin** → 9901 (host) → 7777 (container)
- **Open WebUI** → 9902 (host) → 8080 (container)
- **Paperless-NGX** → 9903 (host) → 8000 (container)
- **PostgreSQL** → 9920 (host) → 5432 (container) (for Vaultwarden, Paperless)

**Future** (when Accounts 1+2 deployed):

- **MariaDB Galera** → 9930 (host) → 3306 (container) (cluster node arm3)

**Networking**:

- Tailscale: Management access (no subnet routing)
- All services exposed via Cloudflare Tunnel (from AMD3)

### Networking

**VCN**: `vcn3` (`10.12.0.0/16`)

**Subnets**:

- **Public** (`10.12.1.0/24`): AMD3 (+ Internet Gateway)
- **Private** (`10.12.2.0/24`): ARM3 (+ NAT Gateway via AMD3)

**Security Lists**:

- **Public (AMD3)**:
  - Inbound: Port 22 (SSH) from Tailscale ONLY (after hardening)
  - Outbound: All (0.0.0.0/0)
- **Private (ARM3)**:
  - Inbound: Port 22 (SSH) from AMD3 (`10.12.1.10`), All from Tailscale subnet
  - Outbound: All

**Firewall** (UFW):

- **AMD3**: Disabled (OCI security lists handle ingress, Tailscale handles access)
- **ARM3**: Disabled

**DNS**:

- **AMD3**: CoreDNS (systemd, `127.0.0.1:53`) → forwards to `1.1.1.1`/`8.8.8.8`
- **ARM3**: Uses AMD3 CoreDNS (`10.12.1.10:53`)

### Docker Networking

**Custom Bridge**: `atn_bridge`

- **AMD3**: `172.25.0.0/16` (NOT using docker0)
- **ARM3**: `172.25.0.0/16` (shared network name, isolated by VCN)

**Rationale**: Consistent naming across all accounts. No CIDR conflicts (VCNs isolated).

---

## Cloud-Init Template

**Location**: `infrastructure/oci/cloud-init/base-template.yml`

**Features**:

- Idempotent bootstrap (checks existing state)
- Security-first flow (Tailscale before SSH hardening)
- State tracking (`/atn/.state/bootstrap.json`)
- Modular scripts (easy to debug, extend)

**Usage**:

1. Replace placeholders: `{{ACCOUNT_NUM}}`, `{{INSTANCE_TYPE}}`, `{{BWS_TOKEN}}`, `{{SSH_PUBLIC_KEY}}`
2. Upload to OCI as user-data during instance creation
3. Monitor `/var/log/cloud-init-bootstrap.log` for progress

**Validation**:

```bash
# SSH via Tailscale
ssh alex@amd3

# Check bootstrap status
jq . /atn/.state/bootstrap.json

# Verify services
tailscale status
docker ps
systemctl status coredns
```

---

## Deployment Checklist (Account 3 Only)

### Prerequisites

- [ ] BWS Access Token created in Bitwarden
- [ ] Tailscale auth key generated (`TAILSCALE_AUTH_KEY_amd3`, `TAILSCALE_AUTH_KEY_arm3`)
- [ ] SSH public key available
- [ ] Age public key (if using encrypted backups)

### OCI Setup

- [ ] Create `vcn3` (`10.12.0.0/16`)
- [ ] Create public subnet (`10.12.1.0/24`)
- [ ] Create private subnet (`10.12.2.0/24`)
- [ ] Create Internet Gateway (attach to public subnet)
- [ ] Create NAT Gateway (attach to public subnet)
- [ ] Configure security lists (SSH from Tailscale only)

### Instance Deployment

- [ ] Create AMD3 instance (VM.Standard.E2.1.Micro, 50 GB boot)
- [ ] Assign reserved public IP to AMD3
- [ ] Apply cloud-init user-data (from base-template.yml)
- [ ] Wait for bootstrap (~5-10 min)
- [ ] Verify Tailscale connection: `tailscale status`
- [ ] Verify SSH works ONLY via Tailscale IP

- [ ] Create ARM3 instance (VM.Standard.A1.Flex, 4 OCPU, 24 GB, 150 GB boot)
- [ ] Apply cloud-init user-data
- [ ] Verify Tailscale connection
- [ ] Test ARM3 → AMD3 connectivity (`ping 10.12.1.10`)

### Service Deployment

- [ ] Deploy CoreDNS on AMD3 (systemd)
- [ ] Deploy Cloudflare Tunnel on AMD3 (systemd)
- [ ] Deploy Vector on AMD3 (systemd)
- [ ] Deploy Docker services on ARM3 (Vaultwarden, SimpleLogin, Open WebUI, Paperless-NGX)
- [ ] Configure Cloudflare Tunnel ingress rules (point to ARM3 services)

### Validation

- [ ] Access Vaultwarden via Cloudflare Tunnel: `https://vault.example.com`
- [ ] Check logs via Vector (AMD3 syslog + ARM3 container logs)
- [ ] Verify all services accessible via Tailscale

---

## Next Steps

### Phase 2: Multi-Account Expansion (Accounts 1 + 2)

1. Deploy AMD1, ARM1 (Account 1) using same cloud-init template
2. Deploy AMD2, ARM2 (Account 2) using same cloud-init template
3. Form MariaDB Galera cluster (ARM1 + ARM2 + ARM3)
4. Deploy Galera Arbitrator on AMD1 (or Unraid)
5. Test cross-account failover
6. Update Vector to ship logs to centralized sink (Unraid or Object Storage)

### Phase 3: MCP Google Cloud HA

1. Create 10-15 Google Cloud accounts
2. Deploy MCP servers on Google Cloud Run (Always Free tier)
3. Configure Antigravity Manager to rotate across accounts
4. Set $1/month budget alerts on all accounts

### Phase 4: Production Hardening

1. Enable OCI Monitoring (Always Free)
2. Set up automated backups (Galera dumps to Unraid via NFS)
3. Document runbooks (Galera failover, instance rebuild, service deployment)
4. Create disaster recovery plan (restore Galera from backup, rebuild from scratch)

---

## Key Improvements Over v2.0

✅ **Simplified file structure** (no `.ignore` middleman)  
✅ **Security-first cloud-init** (Tailscale before public SSH disabled)  
✅ **Consolidated existing code** (BWS, Tailscale, Docker from atn repo)  
✅ **Correct storage allocation** (50 GB AMD + 150 GB ARM = 200 GB total)  
✅ **Standardized port mappings** (9xxx-9999 range)  
✅ **Idempotent bootstrap** (state tracking, module completion markers)  
✅ **AMD focus on systemd services** (CoreDNS, CF Tunnel, Vector NOT in Docker)  
✅ **Tailscale + CF Tunnel on every instance** (no single point of failure)

---

## Files Created/Updated

1. **cloud-init/base-template.yml** ← Production-ready cloud-init template
2. **baseline/UNIVERSAL_BASELINE.md** ← This document
3. **docs/GALERA_SPLIT_BRAIN.md** ← Explanation of node weights + arbitrator recommendation

Ready for deployment to Account 3! 🚀
