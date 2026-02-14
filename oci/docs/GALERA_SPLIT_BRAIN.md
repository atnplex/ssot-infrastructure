# Galera Split-Brain Prevention: Node Weights Explained

## What is Split-Brain?

**Split-brain** occurs when a Galera cluster is divided by network partition into two or more groups that cannot communicate with each other. Without prevention, each group might elect itself as "Primary" and start accepting writes independently, causing data divergence.

## How Node Weights Prevent Split-Brain

**Node Weight** (`pc.weight`) is a Galera parameter that determines voting power during quorum calculations.

### Configuration Example

```ini
# arm1 (Account 1) - Primary bootstrap node
wsrep_provider_options="pc.weight=3;pc.ignore_sb=false"

# arm2 (Account 2) - Member node
wsrep_provider_options="pc.weight=1;pc.ignore_sb=false"

# arm3 (Account 3) - Member node
wsrep_provider_options="pc.weight=1;pc.ignore_sb=false"
```

### How It Works

**Total Cluster Weight**: 3 + 1 + 1 = 5  
**Quorum Threshold**: > 50% of total weight = 2.6 (need at least 3)

#### Scenario 1: arm1 Fails (Network Partition)

**Partition A**: arm1 (weight=3) - ALONE  
**Partition B**: arm2 + arm3 (weight=1+1=2) - TOGETHER

- **Partition A**: 3 weight < quorum (need 2.6, have 3, **just barely makes quorum**)
- **Partition B**: 2 weight < quorum (need 2.6)

**Result**: arm1 stays Primary (it has 3, meets threshold), arm2+arm3 go Non-Primary.

#### Scenario 2: arm2 Fails

**Partition A**: arm1 + arm3 (weight=3+1=4) - TOGETHER  
**Partition B**: arm2 (weight=1) - ALONE

- **Partition A**: 4 weight > quorum ✅
- **Partition B**: 1 weight < quorum ❌

**Result**: arm1+arm3 maintain Primary state, arm2 goes Non-Primary.

#### Scenario 3: arm3 Fails

Same as Scenario 2, arm1+arm2 maintain Primary.

### Why This Matters for Multi-Account Setup

**Problem**: Your ARM nodes are in **different OCI accounts**. If an entire account goes down (e.g., billing issue, regional outage), we need to ensure the remaining nodes can continue operating.

**Solution**: By giving arm1 higher weight (3), we ensure:

1. **arm1 alone** can maintain quorum (3 > 2.6 threshold)
2. **arm2 + arm3 together** cannot form quorum without arm1 (1+1=2 < 2.6)
3. **Any two nodes including arm1** maintain quorum

### Potential Issue with This Approach

**Problem**: If arm1 is isolated and arm2+arm3 are together, you'll have:

- arm1 thinks it's Primary (weight=3)
- arm2+arm3 think they're Non-Primary (weight=2)

**Better Alternative for Multi-Account HA**: Use **pc.bootstrap=yes** flag strategically

## Recommended Approach for Your Setup

### Option A: Equal Weights + Manual Intervention (Safer)

```ini
# All nodes: equal weight
wsrep_provider_options="pc.weight=1;pc.ignore_sb=false"
```

**Quorum**: Need 2 out of 3 nodes  
**Pro**: Symmetric, no single point of failure  
**Con**: If network partitions into 1+1+1, cluster stops (no quorum)

**Manual Recovery**: If split-brain suspected, SSH to nodes, check cluster status, manually bootstrap primary with: `SET GLOBAL wsrep_provider_options='pc.bootstrap=yes';`

### Option B: Weighted with Arbitrator (Best)

```ini
# All ARM nodes: weight=1
# Add lightweight arbitrator on AMD or Unraid: weight=0 (just for quorum)
```

**Arbitrator** (garbd) is a lightweight daemon that participates in quorum but doesn't store data.

**Pro**: Breaks ties, prevents split-brain automatically  
**Con**: Requires another component

### Option C: Weighted Primary (What I Recommended)

```ini
# arm1: weight=3
# arm2, arm3: weight=1
```

**Pro**: arm1 can survive alone, useful if arm1 is your "most reliable" account  
**Con**: If arm1 isolated, arm2+arm3 cannot operate (might be acceptable if rare)

## My Revised Recommendation

For your **multi-account OCI setup**, I recommend **Option B (Arbitrator)**:

1. Deploy lightweight `garbd` (Galera Arbitrator) on one AMD instance (e.g., amd1)
2. All ARM nodes have equal weight=1
3. Arbitrator has weight=0 but participates in quorum voting

**Why**:

- If Account 1 goes down → arm2+arm3+garbd maintain quorum ✅
- If Account 2 goes down → arm1+arm3+garbd maintain quorum ✅
- If arm1+arm2 isolated from arm3 → arm1+arm2+garbd maintain quorum ✅

**Setup**:

```bash
# On amd1 (or Unraid)
apt-get install galera-arbitrator-4

# /etc/default/garbd
GALERA_NODES="10.10.1.20:4567 10.11.1.20:4567 10.12.1.20:4567"
GALERA_GROUP="atn-galera-cluster"

systemctl enable garbd
systemctl start garbd
```

## Decision: What Should We Use?

**For Account 3 Initial Deployment**: Start with **Option A (Equal Weights)** for simplicity. We can add arbitrator later once all 3 accounts are deployed.

**After All 3 Accounts Deployed**: Migrate to **Option B (Arbitrator)** for true multi-account HA.

---

**Summary**:

- Node weights (3, 1, 1) were meant to make arm1 "win" during partitions
- Better approach: Use equal weights + Galera Arbitrator on AMD/Unraid
- For now: Start simple with equal weights, add arbitrator in Phase 2
