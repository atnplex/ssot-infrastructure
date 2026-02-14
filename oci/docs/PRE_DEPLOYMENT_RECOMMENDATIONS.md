# Pre-Deployment Recommendations for OCI Baseline v3.0

**Date**: 2026-02-14  
**For Review By**: Multiple agents + user  
**GitHub Repo**: [atnplex/infrastructure](https://github.com/atnplex/infrastructure)

---

## ✅ What's Ready

The baseline v3.0 is comprehensive and production-ready for:

- Identity & file system structure
- Network architecture & CIDR allocation
- Service distribution (AMD utility + ARM performance)
- MariaDB Galera 3-node HA cluster
- Vector logging infrastructure
- Standardized port mappings (9xxx-9999)
- MCP HA strategy (10-15 Google accounts)

---

## 🔍 Recommended Improvements Before Deployment

### 1. **Security Hardening** (HIGH PRIORITY)

#### SSH Configuration

**Current**: Cloud-init enables SSH on port 22  
**Recommend**:

```bash
# /etc/ssh/sshd_config additions
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers alex
# Only allow SSH via Tailscale interface
ListenAddress 100.x.x.x  # Tailscale IP only
```

#### Fail2Ban

**Missing**: No intrusion prevention  
**Recommend**: Add to bootstrap `20-security` module

#### Secrets Management

**Current**: References Bitwarden but no fetch automation  
**Recommend**: Add `fetch-secrets.sh` script using BWS CLI:

```bash
#!/bin/bash
# Fetch secrets from Bitwarden and populate /atn/.ignore/secrets/
source /atn/.ignore/secrets/bws_token  # Stored manually once
bws secret get TAILSCALE_AUTH_KEY > /atn/.ignore/secrets/tailscale_key
bws secret get CF_TUNNEL_TOKEN_AMD1 > /atn/.ignore/secrets/cf_tunnel_token
# etc.
```

---

### 2. **Automation & Idempotency** (MEDIUM PRIORITY)

#### Bootstrap Scripts

**Current**: Framework defined, scripts not written  
**Recommend**: Create scripts BEFORE first deployment

**Priority Order**:

1. `00-preflight/check.sh` (critical - catches issues early)
2. `10-base-os/setup.sh` (foundation)
3. `30-mesh/tailscale.sh` (connectivity)
4. `50-databases/galera.sh` (complex, test thoroughly)

#### State Tracking

**Missing**: Module execution state artifacts  
**Recommend**: Each module writes JSON to `/atn/.ignore/state/`:

```json
{
  "module": "10-base-os",
  "version": "1.0.0",
  "executed_at": "2026-02-14T13:00:00Z",
  "status": "success",
  "changes": ["created /atn", "created alex:atn", "mounted tmpfs"]
}
```

---

### 3. **Disaster Recovery** (MEDIUM PRIORITY)

#### Backup Strategy

**Current**: Mentioned Unraid backups, not detailed  
**Recommend**:

**Daily**:

- Galera dumps: `mysqldump --all-databases --single-transaction > /mnt/unraid/backups/db/$(date +%Y%m%d).sql`
- Config backup: `rsync -av /atn/config/ /mnt/unraid/backups/config-$(hostname)/`

**Weekly**:

- Full `/atn` snapshot (excluding tmp, appdata): `tar -czf /mnt/unraid/backups/atn-$(hostname)-$(date +%Y%m%d).tar.gz /atn --exclude=/atn/tmp --exclude=/atn/appdata`

**Automated**: Cron jobs in `70-observability` module

#### Disaster Recovery Plan

**Missing**: Documented restore procedure  
**Recommend**: Add `docs/DISASTER_RECOVERY.md`:

- How to restore Galera from backup
- How to rebuild instance from scratch
- How to restore from Account 1 failure (use Accounts 2+3)

---

### 4. **Galera Cluster Bootstrap** (HIGH PRIORITY)

#### Split-Brain Prevention

**Current**: Basic Galera config  
**Recommend**: Add to config:

```ini
wsrep_provider_options="pc.weight=3;pc.ignore_sb=false"
# On arm1 (primary): pc.weight=3
# On arm2, arm3: pc.weight=1
# This ensures arm1 wins in split-brain scenarios
```

#### Monitoring & Auto-Recovery

**Missing**: Galera health checks  
**Recommend**: Add systemd watchdog:

```ini
# /etc/systemd/system/galera-watchdog.service
[Unit]
Description=Galera Cluster Health Monitor

[Service]
Type=simple
ExecStart=/atn/scripts/galera-watchdog.sh
Restart=always

[Install]
WantedBy=multi-user.target
```

Script checks `wsrep_cluster_status` and alerts if `Non-Primary`.

---

### 5. **Cost Optimization & Monitoring** (LOW PRIORITY)

#### OCI Cost Alerts

**Current**: $1/month budget, good  
**Recommend**: Add weekly cost reports:

```bash
# Check actual spend via OCI CLI
oci usage cost list --time-usage-started <start> --time-usage-ended <end>
```

#### Resource Right-Sizing

**Question**: After 1 month, review actual usage:

- Is AMD 1GB RAM enough for lightweight services + Vector sink?
- Can we move any services from ARM to AMD to balance load?

#### Idle Resource Detection

**Recommend**: Add to `70-observability`:

- Alert if Docker container CPU < 1% for 7 days
- Alert if disk usage not growing (might indicate app failure)

---

### 6. **Testing Strategy** (HIGH PRIORITY)

#### Pre-Production Testing

**Critical**: Test on disposable VMs FIRST  
**Recommend**:

**Phase 1: Local VirtualBox Test**

1. Create 3 VMs (1 AMD spec, 2 ARM spec)
2. Run bootstrap scripts
3. Test Galera cluster formation
4. Test failover (stop arm1, verify arm2 writable)
5. Document time to complete (should be < 30 min per node)

**Phase 2: Single OCI Account Test**

1. Deploy to Account 1 only
2. Run for 48 hours
3. Monitor costs, logs, resource usage
4. Verify all services accessible via Tailscale + CF Tunnel

**Phase 3: Multi-Account Deployment**

1. Deploy to Accounts 2 & 3
2. Form Galera cluster
3. Test cross-account failover

---

### 7. **Documentation Gaps** (MEDIUM PRIORITY)

#### Missing Docs

**Recommend creating**:

- `docs/BOOTSTRAP_GUIDE.md` - Step-by-step manual bootstrap
- `docs/TROUBLESHOOTING.md` - Common issues & solutions
- `docs/NETWORKING.md` - Detailed Tailscale + CF Tunnel setup
- `docs/GALERA_OPERATIONS.md` - Cluster management, failover, recovery

#### Runbooks

**Recommend**: One-pagers for common tasks:

- "How to add a new service to AMD/ARM"
- "How to rotate Tailscale keys"
- "How to restore Galera from backup"

---

### 8. **MCP Infrastructure** (LOW PRIORITY)

#### Google Cloud Deployment

**Current**: Conceptual, not implemented  
**Recommend**: Defer to Phase 2 AFTER OCI baseline stable

**Reasoning**:

- Focus on getting 3 OCI accounts working first
- MCP can run locally on AMD instances initially
- Google Cloud HA adds complexity, validate need first

---

### 9. **Vector Logging** (MEDIUM PRIORITY)

#### Log Retention

**Current**: `/atn/logs` tmpfs (wiped on reboot)  
**Question**: Is this intentional?  
**Recommend**: If logs needed long-term:

- Ship to Unraid: `vector sink -> file on /mnt/unraid/logs/`
- Or use separate persistent volume: `/var/log/vector/`

#### Log Aggregation

**Recommend**: Add lightweight Grafana Loki (optional):

- Runs on AMD (or Unraid)
- Vector ships logs to Loki
- Query logs across all 6 nodes from one UI

---

### 10. **Unraid Integration** (LOW PRIORITY)

#### NFS Mounts

**Current**: Mentioned, not configured  
**Recommend**: Add to `40-storage` module:

```bash
# /etc/fstab
<unraid_tailscale_ip>:/mnt/user/media /mnt/unraid/media nfs defaults,_netdev,x-systemd.automount 0 0
<unraid_tailscale_ip>:/mnt/user/backups /mnt/unraid/backups nfs defaults,_netdev,x-systemd.automount 0 0
```

#### Shared AppData

**Question**: Should some `/atn/appdata` sync to Unraid for persistence?  
**Example**: Vaultwarden database -> Unraid backup every 6 hours

---

## 📋 Pre-Deployment Checklist

Before deploying to Account 1:

**Bootstrap Scripts** (Priority 1):

- [ ] Write `00-preflight/check.sh`
- [ ] Write `10-base-os/setup.sh`
- [ ] Write `30-mesh/tailscale.sh`
- [ ] Write `30-mesh/cloudflare.sh`
- [ ] Write `50-databases/galera.sh`
- [ ] Test all scripts on VirtualBox VM

**Security** (Priority 1):

- [ ] Harden SSH config (Tailscale-only, disable password auth)
- [ ] Add Fail2Ban to `20-security`
- [ ] Create `fetch-secrets.sh` for Bitwarden integration

**Documentation** (Priority 2):

- [ ] Write `BOOTSTRAP_GUIDE.md`
- [ ] Write `DISASTER_RECOVERY.md`
- [ ] Create Galera runbooks

**Validation** (Priority 1):

- [ ] Test bootstrap on VirtualBox (3 VMs)
- [ ] Verify Galera cluster forms
- [ ] Test split-brain recovery
- [ ] Deploy to Account 1, run 48 hours
- [ ] Check costs ($0.00 expected)

**Monitoring** (Priority 2):

- [ ] Set up OCI budget alerts
- [ ] Configure Galera watchdog
- [ ] Test Vector logging (ARM → AMD)

---

## 🎯 My Specific Recommendations

### Recommendation 1: Start with Account 1 Only

**Why**: Validate architecture end-to-end before replication  
**Timeline**: 1 week Account 1, then Accounts 2+3

### Recommendation 2: Write Bootstrap Scripts First

**Why**: Manual deployment error-prone, hard to replicate  
**Effort**: ~4-6 hours to write + test all modules

### Recommendation 3: Test Galera Locally First

**Why**: Cluster formation can be tricky, debug on VMs  
**Effort**: ~2 hours VirtualBox setup

### Recommendation 4: Defer MCP Google Cloud HA

**Why**: Local MCP on AMD works for now, Google Cloud adds cost/complexity  
**Timeline**: Revisit in 1 month after OCI baseline stable

### Recommendation 5: Add Observability Early

**Why**: Need visibility into what's working/failing  
**Components**: Vector logs, simple Grafana dashboard, OCI Monitoring

---

## ❓ Questions for Other Agents

When you cross-check with other agents, ask them:

1. **Security**: Any glaring security holes in the design?
2. **Galera**: Best practices for 3-node Galera cluster across different cloud accounts?
3. **Vector**: Better way to prevent OCI idle reclamation than log shipping?
4. **Networking**: Any issues with the CIDR allocation or Tailscale mesh?
5. **Cost**: Will we ACTUALLY stay at $0/month with this setup?
6. **Scaling**: If we need to add Account 4 later, how painful?

---

## 🚀 Deployment Timeline (Proposed)

**Week 1: Preparation**

- Write bootstrap scripts
- Test on VirtualBox
- Harden security configs

**Week 2: Account 1 Deployment**

- Deploy AMD + ARM instances
- Run bootstrap
- Deploy Docker stacks
- Monitor for 7 days

**Week 3: Multi-Account Expansion**

- Deploy Accounts 2 & 3
- Form Galera cluster
- Test cross-account failover

**Week 4: Production Hardening**

- Add monitoring/alerting
- Document runbooks
- Load production data

---

## 📎 Useful Links

- **GitHub Repo**: [atnplex/infrastructure](https://github.com/atnplex/infrastructure)
- **Baseline v3.0**: `oci/baseline/UNIVERSAL_BASELINE.md`
- **OCI Console**: [cloud.oracle.com](https://cloud.oracle.com/)
- **Galera Docs**: [galeracluster.com/library/documentation](https://galeracluster.com/library/documentation/)
- **Vector Docs**: [vector.dev/docs](https://vector.dev/docs/)
