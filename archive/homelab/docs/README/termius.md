# 🖥️ Termius Configuration & Contributor-Safe Defaults

This guide outlines recommended Termius settings for SSH workflows across Unraid, HAOS, OCI VPS, and Docker environments. It includes terminal preferences, security options, and rationale for each setting.

---

## 🎨 Terminal Appearance

| Setting                     | Value                | Rationale                                         |
|-----------------------------|----------------------|--------------------------------------------------|
| Terminal Emulation          | `xterm-256color`     | Enables full color support for modern shells     |
| Font                        | `Cascadia Code`      | Monospaced, ligature-friendly for CLI readability|
| Text Size                   | `14`                 | Balanced for visibility and screen real estate   |
| Bright Colors               | Enabled              | Improves syntax highlighting and command clarity |
| Shell History Import        | Enabled              | Preserves command history across sessions        |
| Select to Copy              | Enabled              | Speeds up CLI workflows                          |
| Right Click to Paste        | Enabled              | Reduces friction in command reuse                |
| Autoreconnect               | Enabled              | Keeps sessions alive during network hiccups      |
| Autocomplete                | Disabled             | Avoids noisy suggestions in CLI workflows        |
| Bell Sound                  | Disabled             | Prevents distractions during coding sessions     |
| Theme                       | `Termius Dark`       | Reduces eye strain, matches dark-mode workflows  |

---

## ⚙️ Terminal Behavior

| Setting                     | Value                | Rationale                                         |
|-----------------------------|----------------------|--------------------------------------------------|
| Detect OS                  | Enabled              | Allows OS-specific snippets and commands         |
| Detect OS Script           | `uname -a && cat /etc/os-release` | Cross-platform detection             |
| Local Terminal Path        | `pwsh.exe`           | Use PowerShell 7 for modern CLI and SSH support  |
| Keep Alive Interval        | `60` or `120` sec    | Prevents idle disconnects                        |
| Scrollback Lines           | `40000`              | Enables deep log inspection                      |
| Post-Quantum Key Exchange  | Enabled              | Future-proofing against quantum attacks          |
| Shortcuts                  | Disabled             | Avoid accidental triggers                        |
| Theme                      | Dark                 | Consistent with coding environments              |

---

## 🧪 Optimization Tips

- Use **Tags** to group hosts by function (`docker`, `prod`, `tailscale`)
- Use **Snippets** for reusable commands (see SSH README)
- Use **Host Chaining** for OCI → Bastion → Private VM flows
- Use **Agent Forwarding** to avoid copying keys to intermediate hosts
- Use **Port Forwarding** to tunnel services (e.g., HAOS UI, Docker API)

---

## 🧰 Recommended Extensions

- Enable **SFTP GUI** for drag-and-drop file transfers
- Use **Vault Sync** to keep keys and hosts consistent across devices
- Store keys in **Bitwarden** for backup and recovery

---

## 🧰 Snippet Ideas

```bash
# Docker cleanup
docker system prune -af --volumes

# HAOS backup
ha backup create --name "pre-upgrade"

# Unraid disk check
smartctl -a /dev/sdX

# OCI system update
sudo apt update && sudo apt upgrade -y
```
