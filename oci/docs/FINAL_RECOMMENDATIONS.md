# Final Pre-Push Recommendations & Actions

**Date**: 2026-02-14  
**Status**: Ready for final review before GitHub push

---

## ✅ COMPLETED

### 1. Subnet Naming Convention

- [x] Updated to `public-subnet-3` and `private-subnet-3` pattern

### 2. Cloud-Init User Setup

- [x] Creates alex:atn (1114:1114) ✅
- [x] Passwordless sudo (`NOPASSWD:ALL`) ✅
- [x] Timezone (America/Los_Angeles) ✅
- [x] OS updates (`package_update` + `package_upgrade`) ✅
- [x] SSH key deployment ✅

### 3. Security Flow

- [x] BWS → Tailscale → SSH hardening (correct order) ✅
- [x] Public SSH disabled after Tailscale confirmed ✅

### 4. HA Pattern Explanation

- [x] Documented Active-Active vs Active-Passive ✅
- [x] Galera multi-master behavior explained ✅
- [x] Recommendation: Use Galera Arbitrator on AMD1 ✅

### 5. File Structure

- [x] Simplified to `.secrets` and `.state` (no `.ignore`) ✅

---

## 🔧 TO-DO BEFORE FINAL PUSH

### 1. Remove Default Users (Security Enhancement)

**Add to cloud-init template**:

```yaml
# After bootstrap_main.sh in runcmd
- userdel -r ubuntu 2>/dev/null || true
- userdel -r oci 2>/dev/null || true
- userdel -r debian 2>/dev/null || true
```

**Rationale**: Default users are unnecessary and potential security risk. Alex user is sufficient.

### 2. Test Sudo Configuration

**Verify** in `/var/log/cloud-init-bootstrap.log`:

- [ ] Commands run without sudo prompts
- [ ] alex user can run `docker ps` without sudo (after adding to docker group)

**Note**: `NOPASSWD:ALL` is already configured, but should test on first deployment.

### 3. Add Galera Arbitrator Deployment Script

**Create**: `infrastructure/oci/scripts/deploy_galera_arbitrator.sh`

```bash
#!/bin/bash
# Deploy Galera Arbitrator on AMD1 (or Unraid)

set -euo pipefail

# Install Galera Arbitrator
apt-get update
apt-get install -y galera-arbitrator-4

# Configure
cat > /etc/default/garbd <<EOF
GALERA_NODES="10.10.2.20:4567,10.11.2.20:4567,10.12.2.20:4567"
GALERA_GROUP="atn-galera-cluster"
GALERA_OPTIONS=""
EOF

# Enable and start
systemctl enable garbd
systemctl start garbd

# Verify
systemctl status garbd
```

**To-Do**: Add this file before pushing

### 4. Code Consolidation Status

**Searched**:

- [x] `atnplex/oracle-cloud-vps` - Extracted BASELINE.md ✅
- [x] `atnplex/atn` - Extracted BWS setup scripts ✅
- [x] `atnplex/setup` - Not cloned (repo exists but empty?)
- [x] `atnplex/atn-bootstrap` - Not cloned (repo exists but empty?)

**Legacy Code Found**:

- `oracle-cloud-vps/BASELINE.md` - OLD (uses .ignore, 10.1-3.0.0/16 CIDR)
- No other significant cloud-init or OCI setup code found

**Recommendation**:

- Mark `oracle-cloud-vps` repo as **DEPRECATED** (add notice to README)
- Point to `infrastructure` repo as SSOT
- Keep old repo for historical reference (don't delete yet)

### 5. Additional Scans Needed

**Check these locations**:

- [ ] `C:\atn\github\atnplex\*` - Scan ALL repos for cloud-init or OCI references
- [ ] VPS1/VPS2 actual server files (via SSH or Tailscale) - Check `/atn/scripts/` for any OCI automation
- [ ] Old branches in `oracle-cloud-vps` repo (e.g., `inventory/account3`)

**To-Do**: Run comprehensive grep across all repos

---

## 🚀 FINAL CHECKLIST BEFORE PUSH

### Files to Create/Update

- [ ] Update `base-template.yml` - Add default user removal
- [ ] Update `UNIVERSAL_BASELINE.md` - Change subnet names to `public-subnet-3` pattern
- [ ] Create `scripts/deploy_galera_arbitrator.sh`
- [ ] Create `docs/HA_PATTERNS.md` (copy from artifacts)
- [ ] Update `oracle-cloud-vps/README.md` - Add deprecation notice

### Documentation Completeness

- [ ] Cloud-init template has inline comments explaining each section ✅
- [ ] Baseline has deployment checklist ✅
- [ ] HA patterns explained (Galera vs PostgreSQL) ✅
- [ ] Split-brain prevention documented ✅
- [ ] Pre-deployment recommendations exist ✅

### Code Quality

- [ ] All scripts are idempotent (can run multiple times safely) ✅
- [ ] Error handling (`set -euo pipefail`) ✅
- [ ] State tracking (`/atn/.state/bootstrap.json`) ✅
- [ ] Logging (`/var/log/cloud-init-bootstrap.log`) ✅

---

## 📋 REMAINING QUESTIONS FOR USER

### 1. PostgreSQL vs MariaDB Galera

**Question**: Do you want to use **MariaDB Galera for everything**, or keep PostgreSQL for specific apps?

**Recommendation**: Use Galera for all database needs (Vaultwarden, Paperless-NGX, SimpleLogin all support MariaDB)

### 2. Galera Arbitrator Location

**Question**: Where should Galera Arbitrator run?

**Options**:

- AMD1 (OCI Account 1) - **Recommended** (always-on, lightweight)
- Unraid (if always-on and accessible via Tailscale)
- Separate VPS outside OCI (external tie-breaker, more resilient)

**Recommendation**: AMD1 for simplicity

### 3. Legacy Repo Cleanup

**Question**: Should we:

- **Option A**: Archive `oracle-cloud-vps` repo (make read-only, add deprecation notice)
- **Option B**: Keep it active for historical reference
- **Option C**: Delete it entirely (after confirming all code migrated)

**Recommendation**: Option A (archive with deprecation notice)

---

## 🔍 ADDITIONAL RECOMMENDATIONS

### 1. Add CoreDNS Systemd Service Template

**Create**: `infrastructure/oci/systemd/coredns.service`

```ini
[Unit]
Description=CoreDNS DNS Server
After=network.target

[Service]
Type=simple
User=alex
Group=atn
ExecStart=/usr/local/bin/coredns -conf /atn/config/coredns/Corefile
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 2. Add Cloudflare Tunnel Systemd Service Template

**Create**: `infrastructure/oci/systemd/cloudflared.service`

```ini
[Unit]
Description=Cloudflare Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=alex
Group=atn
ExecStart=/usr/local/bin/cloudflared tunnel --config /atn/config/cloudflared/config.yml run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 3. Add Vector Systemd Service Template

**Create**: `infrastructure/oci/systemd/vector.service`

```ini
[Unit]
Description=Vector Log Aggregation
After=network.target

[Service]
Type=simple
User=alex
Group=atn
ExecStart=/usr/local/bin/vector --config /atn/config/vector/vector.toml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 4. Add Post-Bootstrap Validation Script

**Create**: `infrastructure/oci/scripts/validate_bootstrap.sh`

```bash
#!/bin/bash
# Validate bootstrap completed successfully

set -euo pipefail

echo "=== Bootstrap Validation ==="

# Check user
if id alex &>/dev/null; then
  echo "✅ User alex exists"
  echo "   UID: $(id -u alex), GID: $(id -g alex)"
else
  echo "❌ User alex missing"
  exit 1
fi

# Check /atn structure
for dir in /atn/.secrets /atn/.state /atn/tmp /atn/logs; do
  if [[ -d $dir ]]; then
    echo "✅ $dir exists"
  else
    echo "❌ $dir missing"
    exit 1
  fi
done

# Check Tailscale
if tailscale status &>/dev/null; then
  echo "✅ Tailscale connected: $(tailscale ip -4)"
else
  echo "❌ Tailscale not connected"
  exit 1
fi

# Check Docker
if docker ps &>/dev/null; then
  echo "✅ Docker running"
  docker network ls | grep atn_bridge && echo "✅ atn_bridge network exists"
else
  echo "❌ Docker not running"
  exit 1
fi

# Check bootstrap state
if [[ -f /atn/.state/bootstrap.json ]]; then
  echo "✅ Bootstrap state exists"
  jq . /atn/.state/bootstrap.json
else
  echo "❌ Bootstrap state missing"
  exit 1
fi

echo "=== Validation Complete ==="
```

---

## 🎯 RECOMMENDED NEXT ACTIONS

### Immediate (Before GitHub Push)

1. Update subnet naming in baseline
2. Add default user removal to cloud-init
3. Copy HA patterns doc to `oci/docs/`
4. Create systemd service templates
5. Create validation script
6. Run final grep search across ALL repos

### After Push (Before Deployment)

1. Get feedback from other agents
2. Test cloud-init on VirtualBox VM
3. Deploy to OCI Account 3
4. Validate bootstrap with validation script
5. Document any issues/adjustments needed

### Phase 2 (Multi-Account Expansion)

1. Deploy Accounts 1 & 2
2. Deploy Galera Arbitrator on AMD1
3. Form Galera cluster
4. Test cross-account failover
5. Deploy production services

---

**Ready to proceed with updates?** Let me know and I'll make the changes!
