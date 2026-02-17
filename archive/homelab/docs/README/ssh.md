# 🧩 SSH Vault Structure & Onboarding Guide

This guide scaffolds a modular, audit-friendly SSH workflow for accessing Unraid, HAOS, OCI VPS, and Docker hosts. It includes key management, host chaining logic, fallback strategies, and naming conventions.

---

## 🔐 SSH Key Management

### Key Principles
- Private keys (`id_ed25519_*`) are stored securely on your device and optionally in Bitwarden.
- Public keys (`id_ed25519_*.pub`) are copied to the remote host’s `~/.ssh/authorized_keys`.
- Each service gets its own keypair for audit clarity and blast radius containment.

### Setup Steps
```bash
# Generate keypair per host/service
ssh-keygen -t ed25519 -C "unraid access" -f ~/.ssh/id_ed25519_unraid

# Copy public key to remote host
ssh-copy-id -i ~/.ssh/id_ed25519_unraid.pub root@unraid.lan
```

---

## 🧭 SSH Config Template (`~/.ssh/config`)

Supports:
- Hostname fallback (LAN + Tailscale)
- Key aliasing
- Agent forwarding
- Port forwarding
- Jump hosts (host chaining)

```ssh
Host *
  ForwardAgent yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
  Compression yes
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes

Host unraid
  HostName unraid.lan
  User root
  IdentityFile ~/.ssh/id_ed25519_unraid
  Port 22

Host unraid-tailscale
  HostName 100.x.x.x
  User root
  IdentityFile ~/.ssh/id_ed25519_unraid
  Port 22

Host haos
  HostName haos.lan
  User root
  IdentityFile ~/.ssh/id_ed25519_haos
  Port 22
  LocalForward 8123 localhost:8123

Host oci
  HostName oci.example.com
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519_oci
  Port 22
  ProxyJump bastion

Host bastion
  HostName bastion.example.com
  User alex
  IdentityFile ~/.ssh/id_ed25519_bastion
  Port 22
```

---

## 🗂️ Vault Structure

### Keychain
| Key Name               | Purpose                        |
|------------------------|--------------------------------|
| `id_ed25519_unraid`    | Unraid root access             |
| `id_ed25519_haos`      | HAOS root access               |
| `id_ed25519_oci`       | OCI VPS (Ubuntu)               |
| `id_ed25519_bastion`   | Bastion jump host              |

### Hosts
| Group     | Hostname        | Address         | Key              | Notes                          |
|-----------|------------------|------------------|------------------|--------------------------------|
| Unraid    | `unraid`         | `unraid.lan`     | `id_ed25519_unraid` | LAN access                    |
| Unraid    | `unraid-tailscale` | `100.x.x.x`     | `id_ed25519_unraid` | Tailscale fallback            |
| HAOS      | `haos`           | `haos.lan`       | `id_ed25519_haos`   | Port forward 8123             |
| OCI       | `oci`            | `oci.example.com`| `id_ed25519_oci`   | ProxyJump via bastion         |
| OCI       | `bastion`        | `bastion.example.com` | `id_ed25519_bastion` | Jump host                    |

### Tags
- `docker`, `unraid`, `tailscale`, `haos`, `oci`, `prod`, `dev`, `jump-host`, `port-forwarded`

---

## 🧪 Naming Conventions

| Element      | Convention                     | Example                      |
|--------------|--------------------------------|------------------------------|
| Host Alias   | `env-role-location`            | `oci-prod-sfo`               |
| Key Name     | `id_ed25519_<role>`            | `id_ed25519_unraid`          |
| Group Name   | `env` or `platform`            | `Unraid`, `OCI`, `HAOS`      |
| Tags         | `function`, `access`, `region` | `docker`, `tailscale`, `prod`|

Use descriptive, audit-safe names that reflect purpose and fallback logic.

---
