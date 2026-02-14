# Universal OCI Baseline Configuration

**Version**: 1.0.0  
**Date**: 2026-02-14  
**Scope**: Accounts 1, 2, 3 (Always Free Tier)  
**Status**: Ready for Implementation

---

## Architecture Philosophy

### Per-Account Resources

| Component         | Type               | Purpose                                                                                         | Specifications    |
| :---------------- | :----------------- | :---------------------------------------------------------------------------------------------- | :---------------- |
| **ARM Instance**  | Performance Server | High-workload applications, MCP servers (local fallback), containerized services                | 4 OCPU, 24 GB RAM |
| **AMD Instance**  | Utility Server     | Always-on HA services, networking (Tailscale, CF Tunnel, reverse proxy), lightweight monitoring | 1 OCPU, 1 GB RAM  |
| **VCN**           | Network            | Private networking for both instances + future expansion                                        | 10.X.0.0/16       |
| **Block Volumes** | Storage            | Performance storage for ARM instance                                                            | 150 GB @ 20 VPU   |

###Naming

Conventions

**Consistent Pattern**: `{type}{account_number}`

| Account | ARM Hostname | AMD Hostname | VCN Name            | VNIC Names               | Block Volume |
| :------ | :----------- | :----------- | :------------------ | :----------------------- | :----------- |
| **1**   | `arm1`       | `amd1`       | `vps1` (or current) | `vnic1-arm`, `vnic1-amd` | `vol1-perf`  |
| **2**   | `arm2`       | `amd2`       | `vps2` (or current) | `vnic2-arm`, `vnic2-amd` | `vol2-perf`  |
| **3**   | `arm3`       | `amd3`       | `vps3` (confirmed)  | `vnic3-arm`, `vnic3-amd` | `vol3-perf`  |

> [!NOTE]
> **VCN/Tenancy Renaming**
>
> - Ideal: Rename to `vps1`, `vps2`, `vps3` or `atnvps1`, `atnvps2`, `atnvps3`
> - Current: Account 3 VCN is already `vps3` ✅
> - Check via Console → Identity → Tenancy Information → Edit Name
> - If not easily changeable, keep existing names and document mapping

---

## Network Architecture

### CIDR Allocation (Non-Overlapping)

| Account | VCN CIDR      | Public Subnet | Private Subnet | Docker Bridge   | Tailscale Range          |
| :------ | :------------ | :------------ | :------------- | :-------------- | :----------------------- |
| **1**   | `10.1.0.0/16` | `10.1.1.0/24` | `10.1.2.0/24`  | `172.17.0.0/16` | `100.64.0.0/10` (shared) |
| **2**   | `10.2.0.0/16` | `10.2.1.0/24` | `10.2.2.0/24`  | `172.18.0.0/16` | `100.64.0.0/10` (shared) |
| **3**   | `10.3.0.0/16` | `10.3.1.0/24` | `10.3.2.0/24`  | `172.19.0.0/16` | `100.64.0.0/10` (shared) |

**Docker Override** (per account):

```yaml
# /etc/docker/daemon.json
{
  "bip": "172.17.0.1/16"  # Account 1
  "bip": "172.18.0.1/16"  # Account 2
  "bip": "172.19.0.1/16"  # Account 3
}
```

### Networking Services Strategy

**Recommendation**: Run networking services **once on AMD utility instance**

**Rationale** (per research):

- AMD has limited resources (1 GB RAM) but sufficient for lightweight networking stack
- ARM instance freed for performance workloads
- More efficient than duplicating services on each instance
- Private IPs (VCN internal) provide up to 480 Mbps bandwidth (free)

**Services on AMD Instance**:

- ✅ Tailscale (VPN mesh, 50-100 MB RAM)
- ✅ Cloudflare Tunnel (exposes services, ~80 MB RAM)
- ✅ Traefik/Nginx (reverse proxy, 50-200 MB RAM)
- ✅ Unbound/Pi-hole (DNS resolver, ~100 MB RAM, optional)
- ✅ Lightweight monitoring agent (Uptime Kuma, ~100 MB RAM)
- **Total**: ~400-500 MB RAM usage, leaves headroom

**Security List Configuration**:

- Allow ARM → AMD on private IP (all services)
- Allow external → AMD on public IP (Tailscale, HTTPS)
- Block direct external → ARM (access only via Tailscale/CF Tunnel through AMD)

### IPv6 Configuration

**Enable on ALL subnets** (free, improves Tailscale/CF performance):

```bash
# For each VCN
VCN_OCID="<vcn_ocid>"
oci network ipv6 create --vcn-id $VCN_OCID

# For each subnet (public + private)
SUBNET_OCID="<subnet_ocid>"
oci network ipv6 create --subnet-id $SUBNET_OCID
```

---

## Instance Configuration

### AMD Utility Instance (amd1, amd2, amd3)

**Shape**: `VM.Standard.E2.1.Micro`

| Setting                 | Value                                   | Notes                                     |
| :---------------------- | :-------------------------------------- | :---------------------------------------- |
| **OCPU**                | 1                                       | Always Free limit                         |
| **Memory**              | 1 GB                                    | Fixed for this shape                      |
| **Boot Volume**         | 50 GB                                   | Minimum required, included in 200GB limit |
| **VPU (Boot)**          | 10                                      | Balanced performance, free                |
| **Image**               | Ubuntu 24.04 LTS (Minimal)              | Latest LTS, or Oracle Linux 8/9           |
| **Availability Domain** | AD-1 (or lowest latency)                | Check during creation                     |
| **Public IP**           | Reserved (ephemeral acceptable)         | For external access                       |
| **Private IP**          | `10.X.1.10` (Account X)                 | Consistent offset (.10)                   |
| **VNIC Name**           | `vnic1-amd` / `vnic2-amd` / `vnic3-amd` | Clear identification                      |
| **Hostname**            | `amd1` / `amd2` / `amd3`                | Matches naming convention                 |
| **SSH Access**          | ✅ Enabled                              | Key-based only, disable password auth     |
| **Cloud-init**          | See below                               | Auto-configure on first boot              |

**Boot Volume Performance**: 10 VPU (free, sufficient for utility workload)

**VPS Stack (AMD)**:

- **Always-On Services**:
  - Tailscale (VPN)
  - Cloudflare Tunnel (expose services)
  - Traefik (reverse proxy)
  - Uptime Kuma (monitoring)
  - Watchtower (auto-update containers)

- **Optional**:
  - Unbound/Pi-hole (DNS)
  - Netdata (lightweight metrics)

**Cloud-Init Script** (AMD):

```yaml
#cloud-config
hostname: amd1 # Change per account
fqdn: amd1.tailnet-name.ts.net
manage_etc_hosts: true

packages:
  - docker.io
  - docker-compose
  - tailscale
  - ufw

runcmd:
  # Set Docker bridge CIDR
  - echo '{"bip":"172.17.0.1/16"}' > /etc/docker/daemon.json # Account 1, adjust per account
  - systemctl restart docker

  # Enable Tailscale
  - tailscale up --auth-key=<from_bitwarden> --advertise-routes=10.1.0.0/16 # Adjust subnet

  # Firewall rules
  - ufw allow from 10.1.0.0/16 # Private subnet
  - ufw allow 41641/udp # Tailscale
  - ufw allow 443/tcp # HTTPS (CF Tunnel)
  - ufw enable

  # Set timezone
  - timedatectl set-timezone America/Los_Angeles # Or your timezone
```

### ARM Performance Instance (arm1, arm2, arm3)

**Shape**: `VM.Standard.A1.Flex`

| Setting                 | Value                                   | Notes                                        |
| :---------------------- | :-------------------------------------- | :------------------------------------------- |
| **OCPU**                | 4                                       | Maximum Always Free per account              |
| **Memory**              | 24 GB                                   | Maximum Always Free (6GB per OCPU)           |
| **Boot Volume**         | 47-50 GB (default)                      | Minimal boot volume, included in 200GB limit |
| **VPU (Boot)**          | 10                                      | Balanced performance, free                   |
| **Block Volume**        | 150 GB @ 20 VPU                         | Performance storage, attached (maximized)    |
| **Image**               | Ubuntu 24.04 LTS (Minimal)              | Latest LTS, or Oracle Linux 8/9              |
| **Availability Domain** | AD-1 (match AMD if possible)            | Same AD for lower latency                    |
| **Public IP**           | Reserved (ephemeral acceptable)         | Backup access, primarily via AMD             |
| **Private IP**          | `10.X.1.20` (Account X)                 | Consistent offset (.20)                      |
| **VNIC Name**           | `vnic1-arm` / `vnic2-arm` / `vnic3-arm` | Clear identification                         |
| **Hostname**            | `arm1` / `arm2` / `arm3`                | Matches naming convention                    |
| **SSH Access**          | ✅ Enabled                              | Key-based only, disable password auth        |
| **Cloud-init**          | See below                               | Auto-configure + mount block volume          |

**Block Volume Configuration**:

- **Size**: 100 GB (remaining from 200GB quota)
- **VPU**: 20 (maximum free tier performance, ✅ confirmed no charges)
- **Attachment**: Paravirtualized (better performance than iSCSI)
- **Mount Point**: `/mnt/data` (containers, databases, app data)
- **File System**: ext4 or XFS

**VPS Stack (ARM)**:

- **Performance Applications**:
  - Paperless-NGX (document management, ~1-2 GB RAM)
  - Vaultwarden (password manager, ~100 MB RAM)
  - Linkwarden (bookmark manager, ~200 MB RAM)
  - SimpleLogin (email alias, ~300 MB RAM)
  - Immich (photo management, optional, ~2-4 GB RAM)
- **MCP Servers** (local fallback):
  - OCI MCP (local instance)
  - Cloudflare MCP (local instance)
  - Filesystem MCP

- **Databases**:
  - PostgreSQL (shared for Paperless, Linkwarden, etc., ~1-2 GB RAM)
  - Redis (caching, ~200 MB RAM)

**Cloud-Init Script** (ARM):

```yaml
#cloud-config
hostname: arm1 # Change per account
fqdn: arm1.tailnet-name.ts.net
manage_etc_hosts: true

packages:
  - docker.io
  - docker-compose
  - tailscale

runcmd:
  # Set Docker bridge CIDR
  - echo '{"bip":"172.17.0.1/16"}' > /etc/docker/daemon.json # Account 1, adjust per account
  - systemctl restart docker

  # Mount block volume (assumes already attached as /dev/sdb)
  - mkfs.ext4 /dev/sdb
  - mkdir -p /mnt/data
  - echo '/dev/sdb /mnt/data ext4 defaults,nofail 0 2' >> /etc/fstab
  - mount /mnt/data
  - chown -R 1000:1000 /mnt/data # Adjust UID/GID as needed

  # Enable Tailscale
  - tailscale up --auth-key=<from_bitwarden>

  # Set timezone
  - timedatectl set-timezone America/Los_Angeles # Or your timezone
```

---

## Storage Breakdown

### Per-Account Allocation (200 GB Total)

| Volume        | Size                | VPU   | Purpose                                               | Mount Point |
| :------------ | :------------------ | :---- | :---------------------------------------------------- | :---------- |
| **AMD Boot**  | 50 GB               | 10    | OS, system packages, networking stack                 | `/`         |
| **ARM Boot**  | ~47-50 GB (default) | 10    | OS, system packages, Docker engine (minimal)          | `/`         |
| **ARM Block** | 150 GB              | 20 ✅ | Performance storage (containers, databases, app data) | `/mnt/data` |
| **Total**     | ~197-200 GB         | -     | Maximum Always Free per account                       | -           |

**20 VPU Confirmation**: ✅ **FREE** (community-confirmed, no official VPU limit in free tier, only 200GB capacity limit applies)

### Block Volume Performance (20 VPU)

**Specifications**:

- ✅ IOPS: ~15,000 (balanced workload)
- ✅ Throughput: ~240 MB/s
- ✅ Sufficient for PostgreSQL, document processing, photo uploads

**Create & Attach**:

```bash
# Create block volume
oci bv volume create \
  --availability-domain <AD> \
  --compartment-id <COMPARTMENT_OCID> \
  --display-name vol1-perf \
  --size-in-gbs 150 \
  --vpus-per-gb 20

# Attach to ARM instance
oci compute volume-attachment attach \
  --instance-id <ARM_INSTANCE_OCID> \
  --type paravirtualized \
  --volume-id <VOLUME_OCID> \
  --device /dev/oracleoci/oraclevdb
```

---

## Security & Access

### SSH Configuration

**AMD Instance**:

- Primary access: via Tailscale SSH (`ssh amd1`)
- Backup access: Public IP (restricted to your IPs in security list)
- No password auth, key-based only

**ARM Instance**:

- Primary access: via AMD instance (jump host) or Tailscale
- Backup access: Public IP (restricted, emergency only)
- No password auth, key-based only

### Security Lists

**default-security-list** (VCN-wide):

| Type    | Source/Dest   | Protocol | Port  | Purpose                          |
| :------ | :------------ | :------- | :---- | :------------------------------- |
| Ingress | `0.0.0.0/0`   | TCP      | 22    | SSH (restrict to your IPs later) |
| Ingress | `0.0.0.0/0`   | UDP      | 41641 | Tailscale                        |
| Ingress | `0.0.0.0/0`   | TCP      | 443   | HTTPS (Cloudflare Tunnel)        |
| Ingress | `10.X.0.0/16` | ALL      | ALL   | Internal VCN traffic             |
| Egress  | `0.0.0.0/0`   | ALL      | ALL   | Outbound (unrestricted)          |

**Dynamic IP Updates** (CLI):

```bash
# Add your current public IP to SSH allowlist
oci network security-list update \
  --security-list-id <SECURITY_LIST_OCID> \
  --ingress-security-rules '[{
    "source": "YOUR.PUBLIC.IP.HERE/32",
    "protocol": "6",
    "tcp-options": {"destination-port-range": {"min": 22, "max": 22}},
    "description": "SSH from home"
  }]' \
  --force
```

**Required IAM Policy**:

```
Allow group AdminGroup to manage virtual-network-family in compartment root
```

---

## Monitoring & Alerts

### OCI Monitoring (Always Free)

**Enable by default**:

- CPU utilization
- Memory utilization (requires custom metric agent on instance)
- Disk I/O
- Network bandwidth

**Setup**:

1. Console → Compute → Instance → Metrics
2. Enable "Monitoring" plugin on instance
3. Create alarms:
   - CPU > 80% for 5 min → email
   - Memory > 90% for 5 min → email

### Budget Alerts

**Configuration**:
| Setting | Value |
|:---|:---|
| **Monthly Budget** | $1.00 USD |
| **Alert Threshold 1** | 50% forecasted ($0.50) |
| **Alert Threshold 2** | 100% actual ($1.00) |
| **Action** | Email to your address |
| **Scope** | Per compartment (root) |

**Create via CLI**:

```bash
oci budgets budget create \
  --compartment-id <ROOT_COMPARTMENT_OCID> \
  --amount 1.00 \
  --reset-period MONTHLY \
  --target-type COMPARTMENT \
  --targets '["<ROOT_COMPARTMENT_OCID>"]' \
  --display-name "Account-1-Budget"  # Adjust per account

# Create alert rules
oci budgets alert-rule create \
  --budget-id <BUDGET_OCID> \
  --type FORECAST \
  --threshold-metric PERCENTAGE \
  --threshold 50 \
  --recipients <YOUR_EMAIL>

oci budgets alert-rule create \
  --budget-id <BUDGET_OCID> \
  --type ACTUAL \
  --threshold-metric PERCENTAGE \
  --threshold 100 \
  --recipients <YOUR_EMAIL>
```

---

## Deployment Checklist

### Pre-Deployment

- [ ] Confirm OCI account access (all 3 accounts)
- [ ] Generate SSH key pair (or use existing)
- [ ] Obtain Tailscale auth keys from Bitwarden
- [ ] Obtain Cloudflare Tunnel tokens from Bitwarden
- [ ] Decide on tenancy renaming (vps1-3 or keep current)

### Per-Account Deployment (repeat for accounts 1, 2, 3)

#### Network Setup

- [ ] Create/verify VCN: `vps{N}` with CIDR `10.{N}.0.0/16`
- [ ] Create public subnet: `10.{N}.1.0/24`
- [ ] Create private subnet: `10.{N}.2.0/24`
- [ ] Create Internet Gateway
- [ ] Update route tables (public subnet → IGW)
- [ ] Enable IPv6 on VCN
- [ ] Enable IPv6 on both subnets
- [ ] Configure security lists (see above)

#### AMD Utility Instance

- [ ] Launch instance: `VM.Standard.E2.1.Micro`
- [ ] Hostname: `amd{N}`
- [ ] VNIC: `vnic{N}-amd`, private IP `10.{N}.1.10`
- [ ] Boot volume: 50 GB, 10 VPU
- [ ] Add cloud-init script (adjust CIDR for account)
- [ ] Reserve or accept ephemeral public IP
- [ ] Wait for instance to start
- [ ] Test SSH access
- [ ] Verify Tailscale connection
- [ ] Deploy Docker Compose stack (Traefik, CF Tunnel, Uptime Kuma)

#### ARM Performance Instance

- [ ] Create block volume: 150 GB, 20 VPU, name `vol{N}-perf`
- [ ] Launch instance: `VM.Standard.A1.Flex`, 4 OCPU, 24 GB RAM
- [ ] Hostname: `arm{N}`
- [ ] VNIC: `vnic{N}-arm`, private IP `10.{N}.1.20`
- [ ] Boot volume: 50 GB, 10 VPU
- [ ] Add cloud-init script (adjust CIDR, mount block volume)
- [ ] Attach block volume (paravirtualized)
- [ ] Reserve or accept ephemeral public IP
- [ ] Wait for instance to start
- [ ] Test SSH access (via AMD or Tailscale)
- [ ] Verify block volume mounted at `/mnt/data`
- [ ] Deploy Docker Compose stack (Paperless, Vaultwarden, etc.)

#### Post-Deployment

- [ ] Create budget: $1.00/month
- [ ] Create budget alert rules (50% forecast, 100% actual)
- [ ] Enable OCI Monitoring
- [ ] Create monitoring alarms (CPU, memory)
- [ ] Test inter-instance connectivity (private IPs)
- [ ] Test Tailscale mesh across all accounts
- [ ] Test Cloudflare Tunnel access
- [ ] Document public IPs in Bitwarden
- [ ] Update DNS records (if using custom domains)

---

## MCP Server Integration

### Remote External MCPs (Priority 1)

Deploy via MCP registry (no hosting required):

- Google BigQuery, GKE, Cloud Run, Workspace, Cloud Storage
- Third-party: Scout, TeamCity, CODING DevOps, etc.

### Remote MCPs on Google Cloud (Priority 2)

**HA Strategy**: Deploy same MCP image across 3-5 Google accounts

**Core MCPs to Deploy**:

1. **OCI MCP** (this baseline automation tool)
   - `list_instances`
   - `get_instance_config`
   - `list_security_lists`
   - `update_security_list_add_ip`
2. **Cloudflare MCP**
   - `list_zones`, `list_dns_records`, `update_dns_record`
   - `list_tunnels`, `list_r2_buckets`

3. **Bitwarden MCP**
   - `get_secret`, `list_secrets`, `create_or_update_secret`

**Budget Controls**:

- Per Google project: $5/month limit
- Kill switch: Scale Cloud Run to 0 if threshold hit
- Automatic failover to other account endpoints

### Local MCPs (Priority 3 - Fallback)

Run on ARM instances, accessible via:

- Localhost (on same instance)
- Tailscale (from any device in mesh)
- Cloudflare Tunnel (via AMD reverse proxy)

**Deployment**:

```yaml
# docker-compose.yml on ARM instance
services:
  oci-mcp:
    image: your-registry/oci-mcp:latest
    restart: unless-stopped
    environment:
      - OCI_CONFIG=/config/oci_config
    volumes:
      - /mnt/data/mcp/oci:/config
    ports:
      - "127.0.0.1:8001:8000"
```

---

## Next Steps

1. **Confirm Account 2 Audit**: Wait for 2nd auditor to complete Account 2 review
2. **Verify Account 3**: Check if both ARM + AMD instances exist (audit only found 1)
3. **Deploy Baseline**: Use this document to configure all 3 accounts
4. **Document in GitHub**: Create `atnplex/infrastructure` repo with this baseline
5. **Set Up MCP Servers**: Follow MCP integration strategy above

---

## Appendix: Quick Reference

### CIDR Summary

| Account | VCN         | Public Subnet | Private Subnet | Docker        |
| :------ | :---------- | :------------ | :------------- | :------------ |
| 1       | 10.1.0.0/16 | 10.1.1.0/24   | 10.1.2.0/24    | 172.17.0.0/16 |
| 2       | 10.2.0.0/16 | 10.2.1.0/24   | 10.2.2.0/24    | 172.18.0.0/16 |
| 3       | 10.3.0.0/16 | 10.3.1.0/24   | 10.3.2.0/24    | 172.19.0.0/16 |

### Instance IPs

| Account | ARM Private | AMD Private |
| :------ | :---------- | :---------- |
| 1       | 10.1.1.20   | 10.1.1.10   |
| 2       | 10.2.1.20   | 10.2.1.10   |
| 3       | 10.3.1.20   | 10.3.1.10   |

### Resource Limits (Always Free)

- **Compute**: 4 ARM OCPU + 24 GB RAM, 2 AMD instances (1 OCPU + 1 GB each)
- **Storage**: 200 GB total (boot + block volumes)
- **VPN**: 20 VPU confirmed FREE 24/7
- **Network**: 2 VCNs, 10 TB egress/month, IPv6 free
- **Monitoring**: OCI Monitoring included, 100 metric namespaces
