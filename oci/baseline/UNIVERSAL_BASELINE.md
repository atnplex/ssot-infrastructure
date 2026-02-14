# Universal OCI Baseline Configuration

**Version**: 2.0.0  
**Date**: 2026-02-14  
**Scope**: Accounts 1, 2, 3 (Always Free Tier)  
**Status**: Ready for Implementation

---

## Architecture Overview

### Per-Account Resources (Always Free Tier)

| Component         | Quantity | Purpose                                               | Specifications                 |
| :---------------- | :------- | :---------------------------------------------------- | :----------------------------- |
| **VCN**           | 1        | Shared network for both instances                     | `10.{10+N}.0.0/16`             |
| **ARM Instance**  | 1        | Performance workloads (Paperless, Immich, Open WebUI) | 4 OCPU, 24 GB RAM, 150 GB boot |
| **AMD Instance**  | 1        | Utility/always-on (MCP, Vaultwarden, Open WebUI)      | 1 OCPU, 1 GB RAM, 50 GB boot   |
| **Total Storage** | 200 GB   | AMD boot (50) + ARM boot (150)                        | No block volumes!              |

### Core Philosophy

1. **Every Instance is Self-Sufficient**: Tailscale + CF Tunnel on ALL instances (system services, not Docker)
2. **Standardized Ports**: Same port mappings everywhere (9xxx-9999 range)
3. **Shared VCN**: Both instances per account on same VCN, can ping each other
4. **No Single Point of Failure**: Direct access to every server via Tailscale
5. **Lightweight Utility**: AMD runs always-on services (MCP, auth, proxies)
6. **Heavy Performance**: ARM runs resource-intensive apps

---

## Naming Conventions

| Account | VCN    | ARM Instance | AMD Instance | ARM VNIC    | AMD VNIC    | ARM Private IP | AMD Private IP |
| :------ | :----- | :----------- | :----------- | :---------- | :---------- | :------------- | :------------- |
| **1**   | `vcn1` | `arm1`       | `amd1`       | `vnic1-arm` | `vnic1-amd` | `10.10.1.20`   | `10.10.1.10`   |
| **2**   | `vcn2` | `arm2`       | `amd2`       | `vnic2-arm` | `vnic2-amd` | `10.11.1.20`   | `10.11.1.10`   |
| **3**   | `vcn3` | `arm3`       | `amd3`       | `vnic3-arm` | `vnic3-amd` | `10.12.1.20`   | `10.12.1.10`   |

---

## Network Architecture

### CIDR Allocation (Non-Overlapping, Future-Proof)

| Account | VCN CIDR       | Public Subnet  | Private Subnet | Docker Bridge   | Tailscale                |
| :------ | :------------- | :------------- | :------------- | :-------------- | :----------------------- |
| **1**   | `10.10.0.0/16` | `10.10.1.0/24` | `10.10.2.0/24` | `172.25.0.0/16` | `100.64.0.0/10` (shared) |
| **2**   | `10.11.0.0/16` | `10.11.1.0/24` | `10.11.2.0/24` | `172.26.0.0/16` | `100.64.0.0/10` (shared) |
| **3**   | `10.12.0.0/16` | `10.12.1.0/24` | `10.12.2.0/24` | `172.27.0.0/16` | `100.64.0.0/10` (shared) |

**Rationale**: Starting at `10.10.x.x` avoids overlap with common home/VPN ranges (`10.0.x.x`, `10.1.x.x`)

### Docker Custom Bridge Network

**Name**: `atn_bridge` (consistent across ALL instances)

**Configuration** (per account):

```yaml
# Account 1
networks:
  atn_bridge:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.10.0/24
          gateway: 172.25.10.1

# Account 2
networks:
  atn_bridge:
    driver: bridge
    ipam:
      config:
        - subnet: 172.26.10.0/24
          gateway: 172.26.10.1

# Account 3
networks:
  atn_bridge:
    driver: bridge
    ipam:
      config:
        - subnet: 172.27.10.0/24
          gateway: 172.27.10.1
```

### IPv6 Configuration

**Enable on ALL VCNs and subnets** (free, improves performance):

```bash
# For each VCN
VCN_OCID="<vcn_ocid>"
oci network ipv6 create --vcn-id $VCN_OCID

# For each subnet (public + private)
SUBNET_OCID="<subnet_ocid>"
oci network ipv6 create --subnet-id $SUBNET_OCID
```

---

## Instance Configurations

### AMD Utility Instance (amd1, amd2, amd3)

**Shape**: `VM.Standard.E2.1.Micro` (Always Free)

| Setting                 | Value                    | Notes                            |
| :---------------------- | :----------------------- | :------------------------------- |
| **OCPU**                | 1                        | Always Free limit                |
| **Memory**              | 1 GB                     | Fixed for this shape             |
| **Boot Volume**         | 50 GB @ 10 VPU           | OCI default, part of 200GB limit |
| **Image**               | Ubuntu 24.04 LTS Minimal | Or Oracle Linux 9                |
| **Availability Domain** | Use "assigned"           | Avoid getting charged            |
| **Public IP**           | Ephemeral (or reserved)  | For direct access                |
| **Private IP**          | `10.{10+N}.1.10`         | .10 offset for AMD               |
| **VNIC Name**           | `vnic{N}-amd`            | Clear identification             |
| **Hostname**            | `amd{N}`                 | Matches convention               |

**System Services** (NOT Docker):

- ✅ Tailscale (VPN mesh, direct access)
- ✅ Cloudflare Tunnel (expose services publicly)
- ✅ Caddy (reverse proxy, static binary)
- ✅ CoreDNS (DNS resolver, static binary)

**Docker Services** (on `atn_bridge`):

- Vaultwarden (password manager, ~100 MB RAM)
- SimpleLogin (email alias, ~300 MB RAM)
- Open WebUI (AI frontend, ~200 MB RAM)
- Antigravity Manager Proxy (~150 MB RAM)
- MCP Servers (OCI, Cloudflare, Bitwarden, local fallback)
- Uptime Kuma (monitoring, ~100 MB RAM)
- **Total Docker RAM**: ~850 MB (fits comfortably in 1 GB)

**Cloud-Init Script** (AMD):

```yaml
#cloud-config
hostname: amd1 # Change per account
fqdn: amd1.your-tailnet.ts.net
manage_etc_hosts: true
timezone: America/Los_Angeles

packages:
  - docker.io
  - docker-compose
  - curl
  - wget
  - jq

write_files:
  - path: /etc/docker/daemon.json
    content: |
      {
        "bip": "172.25.0.1/16"
      }
    # Change to 172.26 for Account 2, 172.27 for Account 3

runcmd:
  # Install Tailscale (system service)
  - curl -fsSL https://tailscale.com/install.sh | sh
  - tailscale up --auth-key=<from_bitwarden> --advertise-routes=10.10.0.0/16 # Adjust subnet per account

  # Install Caddy (static binary)
  - curl -o /usr/local/bin/caddy "https://caddyserver.com/api/download?os=linux&arch=amd64"
  - chmod +x /usr/local/bin/caddy

  # Install CoreDNS (static binary)
  - curl -fsSL https://github.com/coredns/coredns/releases/latest/download/coredns_linux_amd64.tgz | tar -xz -C /usr/local/bin

  # Install Cloudflare Tunnel (system service)
  - curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  - dpkg -i cloudflared.deb
  - cloudflared service install <tunnel_token_from_bitwarden>

  # Restart Docker with custom bridge
  - systemctl restart docker

  # OCI firewall (UFW disabled, relying on OCI Security Lists)
  - systemctl disable ufw
  - systemctl stop ufw

  # Set up atn_bridge network
  - docker network create --driver bridge --subnet 172.25.10.0/24 --gateway 172.25.10.1 atn_bridge # Adjust per account
```

### ARM Performance Instance (arm1, arm2, arm3)

**Shape**: `VM.Standard.A1.Flex` (Always Free)

| Setting                 | Value                      | Notes                                              |
| :---------------------- | :------------------------- | :------------------------------------------------- |
| **OCPU**                | 4                          | Maximum Always Free per account                    |
| **Memory**              | 24 GB                      | Maximum (6 GB per OCPU)                            |
| **Boot Volume**         | 150 GB @ 10 VPU            | Maximized boot volume (no separate block volumes!) |
| **Image**               | Ubuntu 24.04 LTS Minimal   | Or Oracle Linux 9                                  |
| **Availability Domain** | Use "assigned" (match AMD) | Avoid charges                                      |
| **Public IP**           | Ephemeral (or reserved)    | Backup access                                      |
| **Private IP**          | `10.{10+N}.1.20`           | .20 offset for ARM                                 |
| **VNIC Name**           | `vnic{N}-arm`              | Clear identification                               |
| **Hostname**            | `arm{N}`                   | Matches convention                                 |

**System Services** (NOT Docker):

- ✅ Tailscale (VPN mesh)
- ✅ Cloudflare Tunnel (expose services)
- ✅ Caddy (reverse proxy)
- ✅ CoreDNS (DNS resolver)

**Docker Services** (on `atn_bridge`):

- Paperless-NGX (document management, ~1-2 GB RAM)
- Immich (photo management, ~2-4 GB RAM)
- Open WebUI (AI frontend, ~200 MB RAM)
- Antigravity Manager Proxy (~150 MB RAM)
- PostgreSQL (shared DB for Paperless/Immich, ~1-2 GB RAM)
- Redis (caching, ~200 MB RAM)
- Linkwarden (bookmark manager, ~200 MB RAM)
- **Total Docker RAM**: ~5-10 GB (fits comfortably in 24 GB)

**Cloud-Init Script** (ARM):

```yaml
#cloud-config
hostname: arm1 # Change per account
fqdn: arm1.your-tailnet.ts.net
manage_etc_hosts: true
timezone: America/Los_Angeles

packages:
  - docker.io
  - docker-compose
  - curl
  - wget
  - jq

write_files:
  - path: /etc/docker/daemon.json
    content: |
      {
        "bip": "172.25.0.1/16"
      }
    # Change to 172.26 for Account 2, 172.27 for Account 3

runcmd:
  # Expand boot volume to use full 150GB (OCI auto-expands partition)
  - growpart /dev/sda 3 # Adjust partition number if needed
  - resize2fs /dev/sda3

  # Install Tailscale (system service)
  - curl -fsSL https://tailscale.com/install.sh | sh
  - tailscale up --auth-key=<from_bitwarden>

  # Install Caddy (static binary)
  - curl -o /usr/local/bin/caddy "https://caddyserver.com/api/download?os=linux&arch=arm64"
  - chmod +x /usr/local/bin/caddy

  # Install CoreDNS (static binary)
  - curl -fsSL https://github.com/coredns/coredns/releases/latest/download/coredns_linux_arm64.tgz | tar -xz -C /usr/local/bin

  # Install Cloudflare Tunnel (system service)
  - curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
  - dpkg -i cloudflared.deb
  - cloudflared service install <tunnel_token_from_bitwarden>

  # Restart Docker with custom bridge
  - systemctl restart docker

  # OCI firewall (UFW disabled)
  - systemctl disable ufw
  - systemctl stop ufw

  # Set up atn_bridge network
  - docker network create --driver bridge --subnet 172.25.10.0/24 --gateway 172.25.10.1 atn_bridge # Adjust per account
```

---

## Standardized Port Mappings (9xxx-9999)

**CRITICAL**: All services use the SAME host port across ALL servers and accounts

| Service                 | Container Port | Host Port | Accessible Via                                              |
| :---------------------- | :------------- | :-------- | :---------------------------------------------------------- |
| **Open WebUI**          | 3000           | 9100      | http://localhost:9100 or https://openwebui.your-domain.com  |
| **Antigravity Manager** | 8080           | 9200      | http://localhost:9200 or https://ag-manager.your-domain.com |
| **Vaultwarden**         | 80             | 9300      | https://vault.your-domain.com (AMD only)                    |
| **SimpleLogin**         | 7777           | 9400      | https://mail.your-domain.com (AMD only)                     |
| **Paperless-NGX**       | 8000           | 9500      | https://docs.your-domain.com (ARM only)                     |
| **Immich**              | 2283           | 9600      | https://photos.your-domain.com (ARM only)                   |
| **Linkwarden**          | 3000           | 9700      | https://bookmarks.your-domain.com (ARM only)                |
| **Uptime Kuma**         | 3001           | 9800      | https://status.your-domain.com (AMD only)                   |
| **PostgreSQL**          | 5432           | 9900      | localhost only (ARM only)                                   |
| **Redis**               | 6379           | 9901      | localhost only (ARM only)                                   |
| **MCP OCI**             | 8000           | 9050      | Tailscale only (AMD only)                                   |
| **MCP Cloudflare**      | 8001           | 9051      | Tailscale only (AMD only)                                   |
| **MCP Bitwarden**       | 8002           | 9052      | Tailscale only (AMD only)                                   |

**Example Docker Compose Snippet** (AMD - Vaultwarden):

```yaml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    networks:
      - atn_bridge
    ports:
      - "9300:80" # SAME on ALL servers
    volumes:
      - ./vaultwarden-data:/data
    environment:
      - DOMAIN=https://vault.your-domain.com
```

---

## Security & Firewall

### OCI Security Lists

**User Preference**: UFW disabled, relying on OCI Security Lists (more robust)

**Check Existing Rules** (vps1 and vps2 have more configured):

```bash
# Get security list OCID for vcn1
VCN_OCID=$(oci network vcn list --compartment-id <COMPARTMENT_OCID> --display-name vcn1 --query 'data[0].id' --raw-output)
oci network security-list list --vcn-id $VCN_OCID --all

# Get existing ingress rules
oci network security-list get --security-list-id <SECURITY_LIST_OCID> --query 'data."ingress-security-rules"'
```

**Recommended Security List Rules**:

| Type    | Source/Dest    | Protocol | Port  | Purpose                          |
| :------ | :------------- | :------- | :---- | :------------------------------- |
| Ingress | `0.0.0.0/0`    | UDP      | 41641 | Tailscale                        |
| Ingress | `0.0.0.0/0`    | TCP      | 443   | HTTPS (Cloudflare Tunnel)        |
| Ingress | `<your_ip>/32` | TCP      | 22    | SSH (will be added dynamically)  |
| Ingress | `10.10.0.0/16` | ALL      | ALL   | Internal VCN traffic (Account 1) |
| Ingress | `10.11.0.0/16` | ALL      | ALL   | Internal VCN traffic (Account 2) |
| Ingress | `10.12.0.0/16` | ALL      | ALL   | Internal VCN traffic (Account 3) |
| Egress  | `0.0.0.0/0`    | ALL      | ALL   | Outbound (unrestricted)          |

**Dynamic IP Updates** (CLI):

```bash
# Add your current public IP to SSH allowlist
MY_IP=$(curl -s ifconfig.me)
oci network security-list update \
  --security-list-id <SECURITY_LIST_OCID> \
  --ingress-security-rules "[{\"source\": \"$MY_IP/32\", \"protocol\": \"6\", \"tcp-options\": {\"destination-port-range\": {\"min\": 22, \"max\": 22}}, \"description\": \"SSH from home\"}]" \
  --force
```

---

## MCP Infrastructure (10-15 Google Accounts)

### Architecture

**Goal**: Deploy same MCP image across 10-15 Google Cloud accounts for HA and cost distribution

**Strategy**: Deploy once, update everywhere

**Budget**: $1/month limit on EVERY Google project (and Cloudflare project)

### Deployment Architecture

```
Google Account 1-15
├── Cloud Run (MCP Server) [us-central1]
├── Artifact Registry (Docker image)
├── Budget Alert ($0.50 forecasted, $1.00 actual)
└── Kill Switch (Scale to 0 if budget exceeded)
```

### MCP Servers to Deploy

1. **OCI MCP** (manage all 3 OCI accounts)
   - `list_instances`, `get_instance_config`, `update_security_list`, etc.
2. **Cloudflare MCP** (manage DNS, R2, Tunnels)
   - `list_zones`, `update_dns_record`, `list_tunnels`, etc.
3. **Bitwarden MCP** (manage secrets programmatically)
   - `get_secret`, `create_or_update_secret`, `list_secrets`

### Deploy-Once-Update-All Mechanism

**Central Image Registry**: Google Artifact Registry (pick one account as "primary")

**Deployment Flow**:

1. Build MCP Docker image locally or in Cloud Build
2. Push to primary Artifact Registry
3. Run deployment script that:
   - Pulls image from primary registry
   - Deploys to Cloud Run in all 10-15 accounts
   - Verifies health endpoints
   - Updates MCP registry with new endpoints

**Example Deployment Script** (pseudo-code):

```bash
#!/bin/bash
ACCOUNTS=("account1" "account2" ... "account15")
IMAGE="us-central1-docker.pkg.dev/primary-project/mcps/oci-mcp:latest"

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
# Create budget with $1 limit
gcloud billing budgets create \
  --billing-account=<BILLING_ACCOUNT_ID> \
  --display-name="MCP Server Budget" \
  --budget-amount=1USD \
  --threshold-rules=percent=50,percent=100 \
  --alert-pubsub-topic=projects/<PROJECT_ID>/topics/budget-alerts

# Set up kill switch (Cloud Function triggered by Pub/Sub)
# Function scales Cloud Run to 0 when budget exceeded
```

---

## Monitoring & Alerts

### OCI Monitoring (Always Free)

**Enable by default** on all instances:

- CPU utilization
- Memory utilization (requires metric agent)
- Disk I/O
- Network bandwidth

**Setup**:

```bash
# Enable monitoring plugin (cloud-init or manual)
oci compute instance update \
  --instance-id <INSTANCE_OCID> \
  --agent-config '{"plugins":[{"name":"Compute Instance Monitoring","desiredState":"ENABLED"}]}'

# Create alarm for high CPU
oci monitoring alarm create \
  --compartment-id <COMPARTMENT_OCID> \
  --destinations '["<EMAIL_TOPIC_OCID>"]' \
  --display-name "High CPU - arm1" \
  --metric-name CpuUtilization \
  --namespace oci_computeagent \
  --query-text 'CpuUtilization[1m].mean() > 80' \
  --severity ERROR
```

### Budget Alerts (OCI)

| Setting            | Value                  |
| :----------------- | :--------------------- |
| **Monthly Budget** | $1.00 USD              |
| **Alert 1**        | 50% forecasted ($0.50) |
| **Alert 2**        | 100% actual ($1.00)    |
| **Scope**          | Per compartment (root) |

**Create via CLI**:

```bash
oci budgets budget create \
  --compartment-id <ROOT_COMPARTMENT_OCID> \
  --amount 1.00 \
  --reset-period MONTHLY \
  --target-type COMPARTMENT \
  --targets "[\"<ROOT_COMPARTMENT_OCID>\"]" \
  --display-name "Account 1 Budget"

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
- [ ] Obtain Tailscale auth keys from Bitwarden (one per instance or reusable)
- [ ] Obtain Cloudflare Tunnel tokens from Bitwarden (one per instance)
- [ ] Review existing OCI security list rules (esp. vps1 and vps2)

### Per-Account Deployment (repeat for accounts 1, 2, 3)

#### Network Setup

- [ ] Create/verify VCN: `vcn{N}` with CIDR `10.{10+N}.0.0/16`
- [ ] Create public subnet: `10.{10+N}.1.0/24`
- [ ] Create private subnet: `10.{10+N}.2.0/24`
- [ ] Create Internet Gateway
- [ ] Update route tables (public subnet → IGW)
- [ ] Enable IPv6 on VCN
- [ ] Enable IPv6 on both subnets
- [ ] Configure security lists (see above, check existing vps1/vps2 rules)

#### AMD Utility Instance

- [ ] Launch instance: `VM.Standard.E2.1.Micro`
- [ ] Hostname: `amd{N}`
- [ ] VNIC: `vnic{N}-amd`, private IP `10.{10+N}.1.10`
- [ ] Boot volume: 50 GB @ 10 VPU (default)
- [ ] Availability Domain: "assigned" (avoid charges)
- [ ] Add cloud-init script (adjust CIDR, Tailscale key, CF token)
- [ ] Ephemeral or reserved public IP
- [ ] Wait for instance to start
- [ ] Test SSH access
- [ ] Verify Tailscale connection (`tailscale status`)
- [ ] Verify CF Tunnel running (`systemctl status cloudflared`)
- [ ] Deploy Docker Compose stack (Vaultwarden, SimpleLogin, Open WebUI, MCP servers)
- [ ] Verify `atn_bridge` network created (`docker network ls`)

#### ARM Performance Instance

- [ ] Launch instance: `VM.Standard.A1.Flex`, 4 OCPU, 24 GB RAM
- [ ] Hostname: `arm{N}`
- [ ] VNIC: `vnic{N}-arm`, private IP `10.{10+N}.1.20`
- [ ] Boot volume: **150 GB** @ 10 VPU (maximized!)
- [ ] Availability Domain: "assigned" (match AMD if possible)
- [ ] Add cloud-init script (adjust CIDR, verify partition expansion)
- [ ] Ephemeral or reserved public IP
- [ ] Wait for instance to start
- [ ] Test SSH access (via AMD or Tailscale)
- [ ] Verify boot volume expanded (`df -h /` should show ~140-145 GB)
- [ ] Verify Tailscale connection
- [ ] Verify CF Tunnel running
- [ ] Deploy Docker Compose stack (Paperless-NGX, Immich, PostgreSQL, Redis, Open WebUI)
- [ ] Verify `atn_bridge` network created

#### Post-Deployment

- [ ] Create budget: $1.00/month
- [ ] Create budget alert rules (50% forecast, 100% actual)
- [ ] Enable OCI Monitoring on both instances
- [ ] Create monitoring alarms (CPU, memory)
- [ ] Test inter-instance connectivity (`ping 10.{10+N}.1.10` from ARM)
- [ ] Test Tailscale mesh across all accounts
- [ ] Test Cloudflare Tunnel access to services
- [ ] Document public IPs in Bitwarden
- [ ] Update DNS records (if using custom domains)
- [ ] Test all services via standardized ports (9xxx-9999)

---

## Service Distribution Summary

### AMD Utility (Always-On, Low Resource)

**System Services**:

- Tailscale, Cloudflare Tunnel, Caddy, CoreDNS

**Docker Services** (on `atn_bridge`):

- Vaultwarden (9300)
- SimpleLogin (9400)
- Open WebUI (9100)
- Antigravity Manager Proxy (9200)
- MCP OCI (9050)
- MCP Cloudflare (9051)
- MCP Bitwarden (9052)
- Uptime Kuma (9800)

**Total RAM**: ~850 MB Docker + ~100 MB system services = **~950 MB** (fits in 1 GB)

### ARM Performance (High Resource)

**System Services**:

- Tailscale, Cloudflare Tunnel, Caddy, CoreDNS

**Docker Services** (on `atn_bridge`):

- Paperless-NGX (9500)
- Immich (9600)
- Linkwarden (9700)
- Open WebUI (9100)
- Antigravity Manager Proxy (9200)
- PostgreSQL (9900, localhost only)
- Redis (9901, localhost only)

**Total RAM**: ~5-10 GB Docker + ~100 MB system services = **~5-10 GB** (fits in 24 GB)

---

## Next Steps

1. **Check Existing OCI Security Lists**: Review vps1 and vps2 for reference
2. **Deploy to Account 1**: Test full deployment on one account first
3. **Validate Services**: Ensure all services accessible via Tailscale and CF Tunnel
4. **Replicate to Accounts 2 & 3**: Use Account 1 as template
5. **Set Up MCP HA**: Deploy across 10-15 Google accounts
6. **Document in GitHub**: Push to `atnplex/infrastructure`

---

## Appendix: Quick Reference

### CIDR Summary

| Account | VCN          | Public Subnet | Private Subnet | Docker Bridge | atn_bridge     |
| :------ | :----------- | :------------ | :------------- | :------------ | :------------- |
| 1       | 10.10.0.0/16 | 10.10.1.0/24  | 10.10.2.0/24   | 172.25.0.0/16 | 172.25.10.0/24 |
| 2       | 10.11.0.0/16 | 10.11.1.0/24  | 10.11.2.0/24   | 172.26.0.0/16 | 172.26.10.0/24 |
| 3       | 10.12.0.0/16 | 10.12.1.0/24  | 10.12.2.0/24   | 172.27.0.0/16 | 172.27.10.0/24 |

### Instance IPs

| Account | ARM Private | AMD Private |
| :------ | :---------- | :---------- |
| 1       | 10.10.1.20  | 10.10.1.10  |
| 2       | 10.11.1.20  | 10.11.1.10  |
| 3       | 10.12.1.20  | 10.12.1.10  |

### Port Mappings (Standardized)

| Service        | Host Port | Location             |
| :------------- | :-------- | :------------------- |
| Open WebUI     | 9100      | Both (AMD + ARM)     |
| AG Manager     | 9200      | Both (AMD + ARM)     |
| Vaultwarden    | 9300      | AMD only             |
| SimpleLogin    | 9400      | AMD only             |
| Paperless-NGX  | 9500      | ARM only             |
| Immich         | 9600      | ARM only             |
| Linkwarden     | 9700      | ARM only             |
| Uptime Kuma    | 9800      | AMD only             |
| PostgreSQL     | 9900      | ARM only (localhost) |
| Redis          | 9901      | ARM only (localhost) |
| MCP OCI        | 9050      | AMD only (Tailscale) |
| MCP Cloudflare | 9051      | AMD only (Tailscale) |
| MCP Bitwarden  | 9052      | AMD only (Tailscale) |

### Resource Limits (Always Free)

- **Compute**: 4 ARM OCPU + 24 GB RAM, 1 AMD instance (1 OCPU + 1 GB)
- **Storage**: 200 GB total (50 GB AMD boot + 150 GB ARM boot)
- **Network**: 2 VCNs per account, 10 TB egress/month, IPv6 free
- **Monitoring**: OCI Monitoring included, 100 metric namespaces
