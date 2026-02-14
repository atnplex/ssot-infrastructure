# Universal OCI Baseline Configuration

**Version**: 3.0.0  
**Date**: 2026-02-14  
**Scope**: Accounts 1, 2, 3 (Always Free Tier)  
**Status**: Production Ready

> [!IMPORTANT]
> **v3.0 Merge**: This baseline combines the **Strict Architect** design (/atn file system, Galera HA, Vector logging, modular bootstrap) with **v2.0 improvements** (better CIDR allocation, standardized ports, MCP HA across 10-15 Google accounts).

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Identity & File System Standard](#identity--file-system-standard)
3. [Network Architecture](#network-architecture)
4. [Instance Configurations](#instance-configurations)
5. [Database: MariaDB Galera HA](#database-mariadb-galera-ha)
6. [Logging: Vector Infrastructure](#logging-vector-infrastructure)
7. [Service Distribution](#service-distribution)
8. [Standardized Port Mappings](#standardized-port-mappings)
9. [Bootstrap Framework](#bootstrap-framework)
10. [MCP Infrastructure](#mcp-infrastructure)
11. [Deployment Checklist](#deployment-checklist)

---

## Architecture Overview

### Per-Account Resources (Always Free Tier)

| Component         | Quantity | Purpose                                    | Specifications                 |
| :---------------- | :------- | :----------------------------------------- | :----------------------------- |
| **VCN**           | 1        | Shared network for both instances          | `10.{10+N}.0.0/16`             |
| **ARM Instance**  | 1        | Performance: Databases, heavy apps, media  | 4 OCPU, 24 GB RAM, 150 GB boot |
| **AMD Instance**  | 1        | Utility: Networking, logs, lightweight svc | 1 OCPU, 1 GB RAM, 50 GB boot   |
| **Total Storage** | 200 GB   | AMD boot (50) + ARM boot (150)             | No block volumes               |

### The "2+1" HA Philosophy

**Per Account**: 2 instances (ARM + AMD) connected via private VCN  
**Across Accounts**: 3 ARM nodes form Galera cluster, 3 AMD nodes provide edge/logging  
**Result**: Multi-account HA with no single point of failure

### Core Principles

1. **Universal Identity**: `alex:atn` (1114:1114) on ALL nodes
2. **Standard File System**: `/atn` hierarchy on ALL nodes
3. **Every Instance is Self-Sufficient**: Tailscale + CF Tunnel everywhere
4. **Shared State**: Galera (ARM) + Vector Logs (AMD)
5. **Standardized Ports**: 9xxx-9999 range, same everywhere

---

## Identity & File System Standard

### User & Group (Universal)

**CRITICAL**: All nodes MUST use these exact IDs for file permissions to work across NFS/rsync.

| Identity | UID/GID | Shell            | Sudo     |
| :------- | :------ | :--------------- | :------- |
| **alex** | 1114    | `/bin/bash`      | NOPASSWD |
| **atn**  | 1114    | N/A (group only) | N/A      |

**Creation**:

```bash
groupadd -g 1114 atn
useradd -u 1114 -g 1114 -m -s /bin/bash alex
usermod -aG sudo alex
echo "alex ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/alex
```

### The `/atn` File System Hierarchy

**Philosophy**: Single source of truth, strict separation of concerns.

| Path                   | Owner    | Perms | Purpose                                         | Persistence         |
| :--------------------- | :------- | :---- | :---------------------------------------------- | :------------------ |
| `/atn`                 | alex:atn | 775   | Root of infrastructure                          | Permanent           |
| `/atn/github`          | alex:atn | 775   | **Git repos** (ONLY place `git pull` happens)   | Permanent           |
| `/atn/config`          | alex:atn | 775   | **Live configs** (symlinked or generated)       | Permanent           |
| `/atn/appdata`         | alex:atn | 775   | **Docker volumes** (DB files, app data)         | Permanent           |
| `/atn/scripts`         | alex:atn | 775   | **Helper scripts** (deployed from github)       | Permanent           |
| `/atn/.ignore`         | alex:atn | 700   | **Secrets & state** (API keys, Tailscale)       | Permanent           |
| `/atn/.ignore/secrets` | alex:atn | 700   | **Secret files** (fetched from Bitwarden)       | Permanent           |
| `/atn/.ignore/state`   | alex:atn | 700   | **Runtime state** (module artifacts, inventory) | Permanent           |
| `/atn/tmp`             | root     | 1777  | **Volatile cache** (tmpfs, 50% RAM)             | **WIPED ON REBOOT** |
| `/atn/logs`            | alex:atn | 775   | **Log storage** (tmpfs, 1GB or 50% RAM)         | **WIPED ON REBOOT** |

**Setup Script**:

```bash
# Create directories
mkdir -p /atn/{github,config,appdata,scripts,tmp,logs}
mkdir -p /atn/.ignore/{secrets,state}

# Set ownership
chown -R alex:atn /atn
chmod -R 775 /atn
chmod -R 700 /atn/.ignore

# Create tmpfs mounts
echo "tmpfs /atn/tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777,size=50% 0 0" >> /etc/fstab
echo "tmpfs /atn/logs tmpfs defaults,noatime,nosuid,nodev,mode=1777,size=1G 0 0" >> /etc/fstab
mount -a

# Convenience symlinks
ln -sfn /atn /home/alex/atn
ln -sfn /atn/github /home/alex/repos

# Environment variables
echo 'export TMPDIR=/atn/tmp' >> /etc/environment
echo 'export NAMESPACE=atn' >> /etc/environment
```

---

## Network Architecture

### Naming Conventions

| Account | VCN    | ARM Instance | AMD Instance | ARM VNIC    | AMD VNIC    | ARM Private IP | AMD Private IP |
| :------ | :----- | :----------- | :----------- | :---------- | :---------- | :------------- | :------------- |
| **1**   | `vcn1` | `arm1`       | `amd1`       | `vnic1-arm` | `vnic1-amd` | `10.10.1.20`   | `10.10.1.10`   |
| **2**   | `vcn2` | `arm2`       | `amd2`       | `vnic2-arm` | `vnic2-amd` | `10.11.1.20`   | `10.11.1.10`   |
| **3**   | `vcn3` | `arm3`       | `amd3`       | `vnic3-arm` | `vnic3-amd` | `10.12.1.20`   | `10.12.1.10`   |

### CIDR Allocation (Non-Overlapping, Future-Proof)

| Account | VCN CIDR       | Public Subnet  | Private Subnet | Docker Bridge   | atn_bridge       | Tailscale                |
| :------ | :------------- | :------------- | :------------- | :-------------- | :--------------- | :----------------------- |
| **1**   | `10.10.0.0/16` | `10.10.1.0/24` | `10.10.2.0/24` | `172.25.0.0/16` | `172.25.10.0/24` | `100.64.0.0/10` (shared) |
| **2**   | `10.11.0.0/16` | `10.11.1.0/24` | `10.11.2.0/24` | `172.26.0.0/16` | `172.26.10.0/24` | `100.64.0.0/10` (shared) |
| **3**   | `10.12.0.0/16` | `10.12.1.0/24` | `10.12.2.0/24` | `172.27.0.0/16` | `172.27.10.0/24` | `100.64.0.0/10` (shared) |

**Rationale**: `10.10-12.0.0/16` avoids overlap with common home/corp VPNs (`10.0.x.x`, `10.1.x.x`)

### Docker Custom Bridge Network

**Name**: `atn_bridge` (consistent across ALL instances)

**Configuration** (Account 1):

```yaml
networks:
  atn_bridge:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.10.0/24
          gateway: 172.25.10.1
```

_(Adjust to 172.26 for Account 2, 172.27 for Account 3)_

### IPv6 Configuration

**Enable on ALL VCNs and subnets** (free, improves performance):

```bash
VCN_OCID="<vcn_ocid>"
oci network ipv6 create --vcn-id $VCN_OCID

SUBNET_OCID="<subnet_ocid>"
oci network ipv6 create --subnet-id $SUBNET_OCID
```

---

## Instance Configurations

### AMD Utility Instance (amd1, amd2, amd3)

**Shape**: `VM.Standard.E2.1.Micro` (Always Free)

| Setting                 | Value                    | Notes                |
| :---------------------- | :----------------------- | :------------------- |
| **OCPU**                | 1                        | Always Free limit    |
| **Memory**              | 1 GB                     | Fixed for this shape |
| **Boot Volume**         | 50 GB @ 10 VPU           | OCI default          |
| **Image**               | Ubuntu 24.04 LTS Minimal | Or Oracle Linux 9    |
| **Availability Domain** | "assigned"               | Avoid charges        |
| **Public IP**           | Ephemeral                | For direct access    |
| **Private IP**          | `10.{10+N}.1.10`         | .10 offset for AMD   |
| **Hostname**            | `amd{N}`                 | Matches convention   |

**System Services** (systemd, NOT Docker):

- ✅ Tailscale (VPN mesh)
- ✅ Cloudflare Tunnel (public ingress)
- ✅ Caddy (reverse proxy)
- ✅ CoreDNS (DNS resolver, systemd service)
- ✅ Vector (log sink, receives from ARM)

**Docker Services** (on `atn_bridge`):

- Vaultwarden (9300)
- SimpleLogin (9400)
- Open WebUI (9100)
- Antigravity Manager Proxy (9200)
- MCP Servers (9050-9052, local fallback)
- Uptime Kuma (9800)

**Total RAM**: ~850 MB Docker + ~100 MB system services = **~950 MB**

### ARM Performance Instance (arm1, arm2, arm3)

**Shape**: `VM.Standard.A1.Flex` (Always Free)

| Setting                 | Value                    | Notes                    |
| :---------------------- | :----------------------- | :----------------------- |
| **OCPU**                | 4                        | Maximum Always Free      |
| **Memory**              | 24 GB                    | Maximum (6 GB per OCPU)  |
| **Boot Volume**         | 150 GB @ 10 VPU          | Maximized!               |
| **Image**               | Ubuntu 24.04 LTS Minimal | Or Oracle Linux 9        |
| **Availability Domain** | "assigned"               | Avoid charges, match AMD |
| **Public IP**           | Ephemeral                | Backup access            |
| **Private IP**          | `10.{10+N}.1.20`         | .20 offset for ARM       |
| **Hostname**            | `arm{N}`                 | Matches convention       |

**System Services** (systemd, NOT Docker):

- ✅ Tailscale (VPN mesh)
- ✅ Cloudflare Tunnel (expose services)
- ✅ Caddy (reverse proxy)
- ✅ CoreDNS (DNS resolver, systemd service)
- ✅ Vector (shipper, sends logs to AMD sink)

**Docker Services** (on `atn_bridge`):

- **MariaDB Galera** (9900, 3-node cluster member) ⭐
- Paperless-NGX (9500)
- Immich (9600)
- Linkwarden (9700)
- Open WebUI (9100)
- Antigravity Manager Proxy (9200)
- PostgreSQL (9901, localhost only)
- Redis (9902, localhost only)

**Total RAM**: ~8-12 GB Docker + ~100 MB system services = **~8-12 GB**

---

## Database: MariaDB Galera HA

### 3-Node Active-Active Cluster

**Topology**: `arm1` ↔ `arm2` ↔ `arm3` (all nodes are writers)

**Cluster Name**: `atn-galera-cluster`

**Configuration** (`/etc/mysql/mariadb.conf.d/galera.cnf`):

```ini
[galera]
wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smr.so
wsrep_cluster_name="atn-galera-cluster"
wsrep_cluster_address="gcomm://10.10.1.20,10.11.1.20,10.12.1.20"
wsrep_node_address="10.10.1.20"  # Change per node
wsrep_node_name="arm1"  # Change per node
wsrep_sst_method=rsync

binlog_format=ROW
default_storage_engine=InnoDB
innodb_autoinc_lock_mode=2
```

**Bootstrap Sequence**:

1. On `arm1` (first node): `galera_new_cluster`
2. On `arm2`, `arm3`: `systemctl start mariadb`
3. Verify cluster: `SHOW STATUS LIKE 'wsrep_cluster_size';` (should be 3)

**Docker Deployment** (alternative to native):

```yaml
services:
  galera:
    image: mariadb:11.4
    container_name: galera
    restart: unless-stopped
    networks:
      - atn_bridge
    ports:
      - "9900:3306"
      - "4567:4567" # Galera sync
      - "4568:4568" # IST
      - "4444:4444" # SST
    environment:
      MYSQL_ROOT_PASSWORD: "${GALERA_ROOT_PW}" # From Bitwarden
      MYSQL_INITDB_SKIP_TZINFO: "yes"
    volumes:
      - /atn/appdata/galera:/var/lib/mysql
      - /atn/config/galera/galera.cnf:/etc/mysql/mariadb.conf.d/galera.cnf:ro
```

---

## Logging: Vector Infrastructure

### Architecture

**Flow**: ARM instances → Vector shipper → AMD sink → disk  
**Purpose**: Prevent ARM idle reclamation, centralize logs on AMD

### Vector on AMD (Sink)

**Role**: Receives logs from all ARM instances, writes to `/atn/logs`

**Configuration** (`/atn/config/vector/vector-amd.yaml`):

```yaml
sources:
  arm_logs:
    type: socket
    address: "0.0.0.0:9091"
    mode: tcp

sinks:
  disk:
    type: file
    inputs:
      - arm_logs
    path: "/atn/logs/%Y-%m-%d-{{ host }}.log"
    encoding:
      codec: json
```

**Systemd Service** (`/etc/systemd/system/vector.service`):

```ini
[Unit]
Description=Vector Log Aggregation
After=network.target

[Service]
Type=simple
User=alex
Group=atn
ExecStart=/usr/local/bin/vector --config /atn/config/vector/vector-amd.yaml
Restart=always

[Install]
WantedBy=multi-user.target
```

### Vector on ARM (Shipper)

**Role**: Ships logs to AMD sink

**Configuration** (`/atn/config/vector/vector-arm.yaml`):

```yaml
sources:
  docker_logs:
    type: docker_logs

transforms:
  parse:
    type: remap
    inputs:
      - docker_logs
    source: |
      .host = "{{ host }}"

sinks:
  amd_sink:
    type: socket
    inputs:
      - parse
    address: "10.10.1.10:9091" # AMD private IP, adjust per account
    mode: tcp
    encoding:
      codec: json
```

**Install Vector** (static binary):

```bash
curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash -s -- -y
mv ~/.vector/bin/vector /usr/local/bin/
```

---

## Service Distribution

### AMD Utility (Always-On, Low Resource)

**System Services** (systemd):

- Tailscale
- Cloudflare Tunnel
- Caddy
- CoreDNS (systemd, not Docker)
- Vector (sink)

**Docker Services** (on `atn_bridge`):

- Vaultwarden (9300)
- SimpleLogin (9400)
- Open WebUI (9100)
- Antigravity Manager Proxy (9200)
- MCP OCI (9050)
- MCP Cloudflare (9051)
- MCP Bitwarden (9052)
- Uptime Kuma (9800)

**Total RAM**: ~950 MB

### ARM Performance (High Resource)

**System Services** (systemd):

- Tailscale
- Cloudflare Tunnel
- Caddy
- CoreDNS (systemd, not Docker)
- Vector (shipper)

**Docker Services** (on `atn_bridge`):

- **MariaDB Galera** (9900) ⭐
- Paperless-NGX (9500)
- Immich (9600)
- Linkwarden (9700)
- Sonarr (9710)
- Radarr (9711)
- Jellyseerr (9712)
- Open WebUI (9100)
- Antigravity Manager Proxy (9200)
- PostgreSQL (9901, localhost only)
- Redis (9902, localhost only)

**Total RAM**: ~8-12 GB

---

## Standardized Port Mappings

**CRITICAL**: Same host port across ALL servers and accounts

| Service             | Container Port | Host Port | Accessible Via        | Location  |
| :------------------ | :------------- | :-------- | :-------------------- | :-------- |
| Open WebUI          | 3000           | 9100      | CF Tunnel / Tailscale | AMD + ARM |
| Antigravity Manager | 8080           | 9200      | CF Tunnel / Tailscale | AMD + ARM |
| Vaultwarden         | 80             | 9300      | CF Tunnel             | AMD only  |
| SimpleLogin         | 7777           | 9400      | CF Tunnel             | AMD only  |
| Paperless-NGX       | 8000           | 9500      | CF Tunnel / Tailscale | ARM only  |
| Immich              | 2283           | 9600      | CF Tunnel / Tailscale | ARM only  |
| Linkwarden          | 3000           | 9700      | Tailscale             | ARM only  |
| Sonarr              | 8989           | 9710      | Tailscale             | ARM only  |
| Radarr              | 7878           | 9711      | Tailscale             | ARM only  |
| Jellyseerr          | 5055           | 9712      | CF Tunnel / Tailscale | ARM only  |
| Uptime Kuma         | 3001           | 9800      | Tailscale             | AMD only  |
| MariaDB Galera      | 3306           | 9900      | VCN + Tailscale       | ARM only  |
| PostgreSQL          | 5432           | 9901      | localhost only        | ARM only  |
| Redis               | 6379           | 9902      | localhost only        | ARM only  |
| MCP OCI             | 8000           | 9050      | Tailscale             | AMD only  |
| MCP Cloudflare      | 8001           | 9051      | Tailscale             | AMD only  |
| MCP Bitwarden       | 8002           | 9052      | Tailscale             | AMD only  |
| Vector (sink)       | -              | 9091      | VCN (ARM→AMD)         | AMD only  |

---

## Bootstrap Framework

### Modular Approach

**Repo**: `atnplex/infrastructure/bootstrap/`

**Structure**:

```
bootstrap/
├── 00-preflight/
│   └── check.sh          # OS, network, time sync validation
├── 10-base-os/
│   └── setup.sh          # Identity, /atn structure, tmpfs
├── 20-security/
│   └── harden.sh         # SSH, firewall, fail2ban
├── 30-mesh/
│   ├── tailscale.sh      # Tailscale setup
│   ├── cloudflare.sh     # CF Tunnel setup
│   └── caddy.sh          # Caddy reverse proxy
├── 40-storage/
│   └── mount.sh          # Unraid NFS, rclone cloud mounts
├── 50-databases/
│   ├── galera.sh         # MariaDB Galera setup (ARM only)
│   └── postgres.sh       # PostgreSQL setup (ARM only)
├── 60-apps/
│   └── deploy.sh         # Docker Compose stacks
├── 70-observability/
│   ├── vector.sh         # Vector logging
│   └── prometheus.sh     # Metrics (optional)
└── config/
    └── global.env        # User-editable values
```

### Global Configuration (`config/global.env`)

```bash
# Identity
ATN_USER="alex"
ATN_GROUP="atn"
ATN_UID=1114
ATN_GID=1114

# Account info
ACCOUNT_NUMBER=1  # Change per account (1, 2, 3)
VCN_CIDR="10.10.0.0/16"  # Adjust per account
DOCKER_BRIDGE_CIDR="172.25.0.0/16"  # Adjust per account

# Secrets (fetched from Bitwarden at runtime)
TAILSCALE_AUTH_KEY=""  # Populated by bootstrap
CF_TUNNEL_TOKEN=""  # Populated by bootstrap
GALERA_ROOT_PW=""  # Populated by bootstrap

# Unraid
UNRAID_IP="<tailscale_ip>"
UNRAID_NFS_PATH="/mnt/user"
```

### Per-Host Manifest (`manifests/arm1.yml`)

```yaml
host: arm1
role: arm-performance
account: 1
modules:
  - 00-preflight
  - 10-base-os
  - 20-security
  - 30-mesh
  - 40-storage
  - 50-databases:
      galera_role: primary # First node bootstraps
  - 60-apps:
      profile: media+openwebui
  - 70-observability:
      vector_role: shipper
```

### Idempotency Contract

Each module MUST:

1. **Check state** before making changes
2. **Write artifacts** to `/atn/.ignore/state/<module>.json`
3. **Support `DRY_RUN=1`** flag (print actions, don't execute)
4. **Exit codes**: 0=success, 1=error, 2=skipped (already done)

---

## MCP Infrastructure

### 10-15 Google Account HA Strategy

**Goal**: Deploy same MCP image across 10-15 Google Cloud accounts

**Budget**: $1/month limit on EVERY Google project + Cloudflare project

### Deploy-Once-Update-All Pattern

**Central Registry**: Google Artifact Registry on "primary" account

**Deployment Flow**:

```bash
#!/bin/bash
# deploy-mcp.sh
ACCOUNTS=("account1" "account2" ... "account15")
IMAGE="us-central1-docker.pkg.dev/primary/mcps/oci-mcp:latest"

# Build once
docker build -t $IMAGE .
docker push $IMAGE

# Deploy to all accounts
for ACCOUNT in "${ACCOUNTS[@]}"; do
  gcloud run deploy oci-mcp \
    --project=$ACCOUNT \
    --image=$IMAGE \
    --region=us-central1 \
    --max-instances=1 \
    --cpu=1 \
    --memory=512Mi \
    --no-allow-unauthenticated
done
```

### Budget Controls

**Per Google Project**:

```bash
gcloud billing budgets create \
  --billing-account=<BILLING_ACCOUNT_ID> \
  --display-name="MCP Budget" \
  --budget-amount=1USD \
  --threshold-rules=percent=50,percent=100 \
  --alert-pubsub-topic=projects/<PROJECT>/topics/budget-alerts
```

**Kill Switch**: Cloud Function scales Cloud Run to 0 when budget hit

**Per Cloudflare Project**: $1/month limit via dashboard settings

---

## Deployment Checklist

### Pre-Deployment

- [ ] Confirm OCI account access (all 3)
- [ ] Generate SSH key pair
- [ ] Obtain Tailscale auth keys from Bitwarden
- [ ] Obtain Cloudflare Tunnel tokens from Bitwarden
- [ ] Review existing OCI security lists (vps1/vps2)

### Per-Account Deployment

#### Phase 1: Network Setup

- [ ] Create VCN: `vcn{N}` with CIDR `10.{10+N}.0.0/16`
- [ ] Create public subnet: `10.{10+N}.1.0/24`
- [ ] Create private subnet: `10.{10+N}.2.0/24`
- [ ] Create Internet Gateway
- [ ] Update route tables
- [ ] Enable IPv6

#### Phase 2: AMD Utility Instance

- [ ] Launch `VM.Standard.E2.1.Micro`, hostname `amd{N}`
- [ ] Boot volume: 50 GB
- [ ] Run bootstrap modules: 00, 10, 20, 30, 60, 70
- [ ] Verify Vector sink running
- [ ] Deploy Docker stacks (Vaultwarden, SimpleLogin, MCP)

#### Phase 3: ARM Performance Instance

- [ ] Launch `VM.Standard.A1.Flex` (4 OCPU, 24 GB), hostname `arm{N}`
- [ ] Boot volume: 150 GB
- [ ] Run bootstrap modules: 00, 10, 20, 30, 40, 50, 60, 70
- [ ] Verify boot volume expanded (`df -h /`)
- [ ] Deploy Docker stacks (Paperless, Immich, media apps)

#### Phase 4: Galera Cluster Setup

- [ ] On `arm1`: Bootstrap Galera (`galera_new_cluster`)
- [ ] On `arm2`, `arm3`: Join cluster (`systemctl start mariadb`)
- [ ] Verify cluster size: `SHOW STATUS LIKE 'wsrep_cluster_size';`
- [ ] Test failover (stop `arm1`, verify `arm2` writable)

#### Phase 5: Post-Deployment

- [ ] Create OCI budget alerts ($1/month)
- [ ] Enable OCI Monitoring
- [ ] Test inter-instance connectivity
- [ ] Test Tailscale mesh
- [ ] Test Cloudflare Tunnel access
- [ ] Document public IPs in Bitwarden

---

## Appendix: Quick Reference

### CIDR Summary

| Account | VCN          | Public Subnet | Private Subnet | Docker        | atn_bridge     |
| :------ | :----------- | :------------ | :------------- | :------------ | :------------- |
| 1       | 10.10.0.0/16 | 10.10.1.0/24  | 10.10.2.0/24   | 172.25.0.0/16 | 172.25.10.0/24 |
| 2       | 10.11.0.0/16 | 10.11.1.0/24  | 10.11.2.0/24   | 172.26.0.0/16 | 172.26.10.0/24 |
| 3       | 10.12.0.0/16 | 10.12.1.0/24  | 10.12.2.0/24   | 172.27.0.0/16 | 172.27.10.0/24 |

### Instance IPs

| Account | ARM Private | AMD Private | ARM Tailscale | AMD Tailscale |
| :------ | :---------- | :---------- | :------------ | :------------ |
| 1       | 10.10.1.20  | 10.10.1.10  | 100.x.x.21    | 100.x.x.11    |
| 2       | 10.11.1.20  | 10.11.1.10  | 100.x.x.22    | 100.x.x.12    |
| 3       | 10.12.1.20  | 10.12.1.10  | 100.x.x.23    | 100.x.x.13    |

### Galera Cluster

| Node | Private IP | Hostname | Role                |
| :--- | :--------- | :------- | :------------------ |
| arm1 | 10.10.1.20 | arm1     | Primary (bootstrap) |
| arm2 | 10.11.1.20 | arm2     | Member              |
| arm3 | 10.12.1.20 | arm3     | Member              |

### Resource Limits (Always Free)

- **Compute**: 4 ARM OCPU + 24 GB RAM per account, 1 AMD instance (1 OCPU + 1 GB)
- **Storage**: 200 GB total per account (50 GB AMD + 150 GB ARM)
- **Network**: 2 VCNs per account, 10 TB egress/month, IPv6 free
- **Monitoring**: OCI Monitoring included
