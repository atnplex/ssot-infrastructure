# High Availability Patterns & Galera Clustering Explained

**Date**: 2026-02-14  
**For**: OCI Infrastructure Decision Making

---

## HA Pattern 1: Active-Active (True HA)

**Definition**: All nodes actively process requests simultaneously. Load is distributed across all nodes.

### Examples

#### DNS Resolvers (CoreDNS on AMD1, AMD2, AMD3)

- **Pattern**: Active-Active
- **How it works**:
  - Each AMD instance runs CoreDNS independently
  - Clients round-robin between DNS servers (or use one as primary, others as fallback)
  - All servers can answer queries simultaneously
  - No synchronization needed (DNS zones are static or pulled from central config)
- **Failover**: If AMD1 goes down, clients automatically use AMD2 or AMD3
- **No split-brain risk**: Each resolver is independent

#### Load Balancers (Caddy reverse proxy)

- **Pattern**: Active-Active (with Tailscale HA)
- **How it works**:
  - Each AMD runs Caddy independently
  - Tailscale or Cloudflare Tunnel routes requests to any available proxy
  - All proxies route to same backend (ARM instances)
- **Failover**: Automatic (routing layer handles it)

---

## HA Pattern 2: Active-Passive (Failover HA)

**Definition**: One node is PRIMARY (active), others are STANDBY (passive). Standby takes over only when primary fails.

### Examples

#### Traditional PostgreSQL (Leader-Follower Replication)

- **Pattern**: Active-Passive
- **How it works**:
  - **Primary (Leader)**: Accepts all writes, handles reads
  - **Replica (Follower)**: Receives replication stream from primary, handles read-only queries (optional)
  - If primary fails, manual or automatic failover promotes replica to primary
- **Problem**: Downtime during failover (seconds to minutes)
- **No split-brain protection built-in**: Need external orchestrator (Patroni, etc.)

#### Example: Paperless-NGX PostgreSQL

- **Current setup**: PostgreSQL runs on ARM3 only
- **HA upgrade**: Add replicas on ARM1, ARM2
  - ARM3 = Primary (accepts writes)
  - ARM1, ARM2 = Replicas (standby, read-only)
  - If ARM3 fails, promote ARM1 to primary
- **Tool**: Use Patroni or Stolon for automatic failover

---

## HA Pattern 3: Multi-Master (Active-Active with Sync)

**Definition**: All nodes are ACTIVE and WRITABLE. Writes on any node are replicated to all others in near-real-time.

### Examples

#### MariaDB Galera Cluster

- **Pattern**: Active-Active Multi-Master
- **How it works**:
  - All 3 nodes (ARM1, ARM2, ARM3) can accept **reads AND writes** simultaneously
  - Writes are replicated **synchronously** via Galera replication protocol
  - Each node has full copy of database
  - **Quorum**: Need majority of nodes (2 out of 3) to maintain "Primary" state
- **Failover**: Instant (other nodes already have the data)
- **Use case**: High-write workloads where multiple apps need to write to DB

#### How Galera Handles Writes

**Scenario**: App writes to ARM1, another app writes to ARM2 simultaneously

1. **ARM1 receives write** (INSERT INTO users ...)
2. **ARM1 broadcasts to ARM2, ARM3** via Galera replication
3. **ARM2, ARM3 acknowledge** (Yes, I applied the write)
4. **Only then** ARM1 commits the transaction
5. **All nodes now have the same data**

**Key**: Writes are **synchronous** (slower than async, but no data loss)

---

## Your Question: PostgreSQL vs Galera

### PostgreSQL (Traditional Active-Passive)

**Your scenario**:

> "Postgres can't be split between multiple nodes simultaneously"

**Correct!** Traditional PostgreSQL:

- **Primary** handles all writes
- **Replicas** are read-only (or standby)
- Cannot write to multiple PostgreSQL nodes simultaneously (without Citus or similar extension)

**Your described approach**:

> "Frontend on Unraid, backend on multiple instances"

- **This doesn't apply to PostgreSQL.** PostgreSQL is the backend database itself.
- What you might be describing is:
  - **App (frontend)** on Unraid or ARM instances → Reads/writes to PostgreSQL
  - **PostgreSQL (backend)** runs on ARM3 (primary) with replicas on ARM1, ARM2
  - If ARM3 fails, promote ARM1 to primary

**Better approach for PostgreSQL HA**:

- Use **Patroni** or **Stolon** (automatic failover)
- Or use **Galera-compatible database** instead (like MariaDB)

### MariaDB Galera (Multi-Master)

**Your Galera setup**:

- **All 3 ARM nodes** (ARM1, ARM2, ARM3) run MariaDB Galera
- **All nodes** can accept writes simultaneously
- Apps can connect to ANY node (load balancing)
- If one node fails, the other 2 continue (quorum maintained)

**Use cases**:

- Vaultwarden database (read/write from any node)
- Paperless-NGX database (if migrated from PostgreSQL to MariaDB)
- Any app that needs HA database without complex failover

---

## Galera Split-Brain Prevention

### The Problem

**Split-Brain**: Network partition divides cluster into 2+ groups that can't communicate.

**Example**: ARM1 isolated from ARM2+ARM3

- **Without protection**: Both sides think they're primary → data divergence
- **With protection**: Only one side stays primary, other goes read-only

### Solution 1: Weighted Nodes (Simple, Single Point of Failure)

**Configuration**:

```ini
# ARM1 (Account 1)
wsrep_provider_options="pc.weight=3"

# ARM2 (Account 2)
wsrep_provider_options="pc.weight=1"

# ARM3 (Account 3)
wsrep_provider_options="pc.weight=1"
```

**How it works**:

- Total weight: 3 + 1 + 1 = 5
- Quorum: Need >50% = 2.6
- **ARM1 alone**: weight 3 > 2.6 → Stays primary ✅
- **ARM2+ARM3**: weight 2 < 2.6 → Goes non-primary ❌

**Problem**: If ARM1 is isolated, ARM2+ARM3 cannot operate (even though they're together)

**Pros**:

- Simple configuration
- ARM1 can survive alone

**Cons**:

- ARM1 is single point of failure (if isolated, cluster stops)

### Solution 2: Equal Weights + Galera Arbitrator (Best for Multi-Account)

**Configuration**:

```ini
# All ARM nodes
wsrep_provider_options="pc.weight=1"

# Arbitrator (garbd) on AMD1 (or Unraid)
# Weight: 0 (participates in quorum but doesn't store data)
```

**How it works**:

- **3 ARM nodes** (weight=1 each) + **1 arbitrator** (weight=0)
- Arbitrator votes in quorum but doesn't store data
- Need 2 out of 3 ARM nodes + arbitrator to maintain primary

**Scenarios**:

- **ARM1 fails**: ARM2+ARM3+arbitrator = quorum ✅
- **ARM2 fails**: ARM1+ARM3+arbitrator = quorum ✅
- **ARM3 fails**: ARM1+ARM2+arbitrator = quorum ✅
- **network partition ARM1 vs ARM2+ARM3**: Side with arbitrator wins

**Where to run arbitrator**:

- **Option A**: AMD1 (lightweight, always-on)
- **Option B**: Unraid (if always-on)
- **Option C**: Separate VPS outside OCI (external tie-breaker)

**Pros**:

- No single point of failure
- Symmetric (all ARM nodes equal)
- Lightweight (arbitrator uses ~10 MB RAM)

**Cons**:

- Requires one more component

---

## Recommendations for Your Setup

### For Galera Cluster (ARM1, ARM2, ARM3)

**Use**: **Equal weights + Arbitrator on AMD1**

**Why**:

- Multi-account setup (each ARM in different OCI account)
- No single point of failure
- If entire account goes down (billing issue, outage), others continue

**Configuration**:

```yaml
# ARM nodes
wsrep_cluster_address: "gcomm://10.10.2.20,10.11.2.20,10.12.2.20"
wsrep_provider_options: "pc.weight=1"

# AMD1 arbitrator
garbd -a gcomm://10.10.2.20,10.11.2.20,10.12.2.20 -g atn-galera-cluster
```

### For PostgreSQL (If Using)

**Option A**: Migrate to MariaDB Galera

- Paperless-NGX supports both PostgreSQL and MariaDB
- Vaultwarden works with MariaDB
- **Benefit**: Get multi-master HA automatically

**Option B**: Use PostgreSQL with Patroni

- Keep PostgreSQL for apps that require it
- Deploy Patroni on ARM1, ARM2, ARM3
- Automatic failover (active-passive)
- **Complexity**: Higher than Galera

**Recommendation**: **Use MariaDB Galera for everything** unless app specifically requires PostgreSQL

### For DNS (CoreDNS on AMD1, AMD2, AMD3)

**Pattern**: Active-Active (no clustering needed)

- Each AMD runs CoreDNS independently
- Clients configured with multiple DNS servers: `10.10.1.10, 10.11.1.10, 10.12.1.10`
- If one fails, others handle requests
- **No arbitrator needed** (independent resolvers)

---

## Summary Table

| Service                 | HA Pattern               | Cluster Type                      | Split-Brain Solution           |
| ----------------------- | ------------------------ | --------------------------------- | ------------------------------ |
| **MariaDB Galera**      | Active-Active            | Multi-Master                      | **Arbitrator on AMD1**         |
| **PostgreSQL**          | Active-Passive           | Leader-Follower                   | Patroni (automatic failover)   |
| **CoreDNS**             | Active-Active            | Independent                       | N/A (no clustering)            |
| **Caddy/Reverse Proxy** | Active-Active            | Independent                       | N/A (routing handles failover) |
| **Vaultwarden**         | Active (single instance) | N/A (stateless app, DB on Galera) | Via Galera                     |

---

## Final Recommendation

**For your 3-account OCI setup**:

1. **MariaDB Galera** (ARM1, ARM2, ARM3):
   - Equal weights (pc.weight=1 on all)
   - **Galera Arbitrator** on AMD1 (or Unraid)
   - All nodes writable, multi-master
   - Use for: Vaultwarden, Paperless-NGX, SimpleLogin

2. **CoreDNS** (AMD1, AMD2, AMD3):
   - Independent instances (active-active)
   - No clustering, clients use all 3 as resolvers

3. **PostgreSQL** (if needed):
   - **Option A**: Don't use it, migrate to MariaDB Galera
   - **Option B**: Use Patroni for automatic failover

**Deployment order**:

1. Deploy ARM1, ARM2, ARM3 (no Galera yet)
2. Deploy AMD1 with Galera Arbitrator
3. Bootstrap Galera cluster (ARM1 first, then ARM2, ARM3)
4. Verify cluster: `SHOW STATUS LIKE 'wsrep_cluster_size';` (should show 3)
5. Deploy apps pointing to Galera cluster

---

**Question for you**: Do you want to use **MariaDB Galera for everything** (recommended), or do you have apps that specifically need PostgreSQL?
