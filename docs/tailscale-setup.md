# Tailscale Mesh Configuration

## Node Table

| Node             | Tailscale IP   | Role          | Docker CIDR   | LAN CIDR       |
| :--------------- | :------------- | :------------ | :------------ | :------------- |
| VPS1 (Account 1) | 100.67.88.109  | Primary brain | 172.19.0.0/16 | —              |
| VPS2 (Account 2) | 100.102.55.88  | Secrets + HA  | 172.20.0.0/16 | —              |
| VPS3 (Account 3) | TBD            | Failover      | 172.21.0.0/16 | —              |
| Unraid           | 100.76.168.116 | Media + DB    | 172.18.0.0/16 | 192.168.1.0/24 |
| Windows Desktop  | —              | Dev + GPU     | —             | 192.168.1.0/24 |
| Windows Laptop   | —              | Mobile dev    | —             | varies         |

## Subnet Routing

Each instance advertises its Docker network so inter-node container communication
can work over Tailscale without exposing ports publicly.

```bash
# Account 1:
sudo tailscale up --advertise-routes=172.19.0.0/16 --accept-routes

# Account 2:
sudo tailscale up --advertise-routes=172.20.0.0/16 --accept-routes

# Account 3:
sudo tailscale up --advertise-routes=172.21.0.0/16 --accept-routes

# Unraid:
sudo tailscale up --advertise-routes=172.18.0.0/16,192.168.1.0/24 --accept-routes
```

## Split DNS

| Hostname  | Resolves To    | Used By                |
| :-------- | :------------- | :--------------------- |
| vps1.ts   | 100.67.88.109  | Ansible, health checks |
| vps2.ts   | 100.102.55.88  | Ansible, health checks |
| vps3.ts   | TBD            | Ansible, health checks |
| unraid.ts | 100.76.168.116 | Arr stack, PostgreSQL  |

Configure in Tailscale admin console → DNS → Add nameserver → Restrict to domain `ts`.

## Access Patterns

```
External user → Cloudflare → CF Tunnel → Caddy → Container (via atn-net)
Internal agent → Tailscale IP:port → Container (direct, bypasses CF)
Cross-node     → Tailscale IP + Docker subnet route → Container
```

## Ansible Access

All Ansible SSH goes over Tailscale IPs. No public IP exposure needed.

```bash
ansible-playbook -i inventory.yml deploy.yml
# Uses: ssh ubuntu@100.67.88.109, ssh ubuntu@100.102.55.88, ssh root@100.76.168.116
```
