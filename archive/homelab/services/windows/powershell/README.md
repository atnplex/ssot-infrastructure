# Windows Terminal + PowerShell Core Setup

This repo contains a clean, contributor-safe configuration for Windows Terminal and PowerShell Core (`pwsh`). It includes:

- A minimal `settings.json` for Windows Terminal
- Guidance on switching from Windows PowerShell to PowerShell Core
- A PowerShell snippet to clean up your profile for silent startup

---

## 🧠 Terminal vs PowerShell

| Concept | Terminal | PowerShell |
|--------|----------|------------|
| Role | Interface to run shells | Shell and scripting language |
| Examples | Windows Terminal, VS Code Terminal | `powershell.exe`, `pwsh.exe` |
| Function | Hosts shells | Executes commands and scripts |
| Analogy | Dashboard | Engine |

---

## 🚀 Why Switch to PowerShell Core?

- No startup banners or update nags
- Faster and cross-platform
- Object-based scripting with modern features
- Side-by-side install — no need to uninstall Windows PowerShell

---

## 🛠 How to Install PowerShell Core

1. Go to [https://aka.ms/powershell](https://aka.ms/powershell)
2. Download the **Windows x64 `.msi` installer**
3. Run the installer and accept defaults
4. Optionally enable:
   - Add to PATH
   - Event Logging
5. Launch `pwsh.exe` or set it as default in Windows Terminal

---

## 🧼 Clean Up Profile for Silent Startup

Run this in PowerShell Core (`pwsh`):

```powershell
New-Item -ItemType File -Path $PROFILE -Force
notepad $PROFILE
```

Paste this into the file:

```powershell
# Minimal pwsh profile — silent startup
# Load helpers only if needed
```

---

## 📂 Included Files

- [`settings.json`](./settings.json) — Windows Terminal configuration

You can copy this into your Windows Terminal settings folder or use it directly in your repo for onboarding contributors.

---
