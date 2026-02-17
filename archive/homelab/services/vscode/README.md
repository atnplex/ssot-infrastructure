# 🖥️ VS Code Editing Standards for Homelab & Services

This document defines **editor configuration standards** across all repos in the `atnplex` organization.  
It ensures **audit clarity, reproducibility, and contributor safety** by embedding VS Code settings, extensions, and workflows directly in each repo.

---

## 🔗 Repo Index (VS Code Setup Status)

Use ✅ to mark repos where `.vscode/settings.json` has been implemented, and ⬜ for pending.

- ✅ [homelab](/.vscode/settings.json)
- ✅ [home-assistant](https://github.com/atnplex/homeassistant/blob/main/.vscode/settings.json)
- ⬜ [radarr](../radarr/.vscode/settings.json)  
- ⬜ [sonarr](../sonarr/.vscode/settings.json)  
- ⬜ [sabnzbd](../sabnzbd/.vscode/settings.json)  
- ⬜ [nextcloud](../nextcloud/.vscode/settings.json)  
- ⬜ [plex](../plex/.vscode/settings.json)  
- ⬜ [jellyfin](../jellyfin/.vscode/settings.json)  
- ⬜ [recyclarr](../recyclarr/.vscode/settings.json)  
- ⬜ [nodered](../nodered/.vscode/settings.json)  
- ⬜ [python-task-runner](../python-task-runner/.vscode/settings.json)  
- ⬜ [immich](../immich/.vscode/settings.json)  
- ⬜ [postgres_immich](../postgres_immich/.vscode/settings.json)  
- ⬜ [tailscale](../tailscale/.vscode/settings.json)  
- ⬜ [cloudflare](../cloudflare/.vscode/settings.json)

Settings.json ready but no personal repo yet.
- ✅ [unraid](/docs/vscode.settings.unraid.json)

*(Add more services here as you migrate. Replace ⬜ with ✅ once settings are in place.)*

---

## 🎯 Purpose

- Provide **predictable editing behavior** for configs, scripts, and documentation.  
- Enforce **safe defaults** (spaces instead of tabs, LF line endings, trailing whitespace trimmed).  
- Reduce onboarding friction by documenting editor workflows directly in config files.  
- Ensure **audit clarity** across homelab and service repos.  

---

## 🛠️ Extensions to Install

- **Red Hat YAML** (`redhat.vscode-yaml`) → YAML formatting & validation.  
- **Home Assistant Config Helper** (`keesschollaart.vscode-home-assistant`) → HA schema validation.  
- **JSON Language Features** (built-in) → JSON formatting.  
- *(Optional)* Docker, Markdown, SQL extensions depending on service.  

---

## ⚖️ Personalized vs Generalized Settings

### 🧩 Personalized Settings (unique per repo)
These repos benefit from **schema validation, language tooling, or service-specific extensions**:

- **Home Assistant** → YAML schema validation, custom tags (`!include`, `!secret`), HA extension integration.  
- **Recyclarr** → YAML schema validation for Radarr/Sonarr sync configs.  
- **Sonarr / Radarr / Lidarr / Bazarr / Prowlarr / Overseerr / Jellyseerr** → JSON/YAML configs, API schema validation.  
- **Nextcloud / Immich / Postgres_immich** → SQL linting, Docker Compose schema validation.  
- **NodeRed / Python-task-runner** → language-specific extensions (JavaScript/TypeScript, Python).  
- **Cloudflare / Tailscale** → JSON/YAML configs for tunnels and networking.  

### 🔄 Generalized Settings (repeated baseline)
These repos mostly rely on **container defaults or simple `.env` files**. They can share the same baseline settings:

- **Plex / Jellyfin / Tautulli / Plextraktsync / Plexytrack / Profilarr / Renamarr / Autoscan / Cleanuparr / Suggestarr / Unpackerr**  
- **Sabnzbd (all versions)**  
- **Binhex-qbittorrentvpn**  
- **Duplicati / Fileflows / Organizr**  
- **Pihole / Pihole-unbound**  
- **Uptimekuma / Speedtest-tracker / Plausible / Librenms**  

---

## 📊 Quick Reference Table — Personalized vs Generalized

| Repo/Service        | Config Type | Settings Needed |
|---------------------|-------------|-----------------|
| Home Assistant      | YAML-heavy  | Personalized (schema + HA extension) |
| Recyclarr           | YAML        | Personalized (schema validation) |
| Sonarr/Radarr/etc.  | JSON/YAML   | Personalized (schema validation) |
| Nextcloud/Immich    | SQL/YAML    | Personalized (SQL + Docker Compose) |
| NodeRed/Python-runner| Code-based | Personalized (language extensions) |
| Plex/Jellyfin/etc.  | Minimal     | Generalized baseline |
| Sabnzbd             | Minimal     | Generalized baseline |
| Pihole/Uptimekuma   | Minimal     | Generalized baseline |

---

## 📂 Collapsible Block — Generalized Settings.json

Use this block for services that don’t need personalized configs.  
Copy/paste into `.vscode/settings.json` in each repo.

<details>
<summary>Click to expand generalized settings.json</summary>

```jsonc
// ============================================================
// File: .vscode/settings.json
// Purpose: Generalized baseline for service repos
// ============================================================

{
  // --- Editor Defaults ---
  "editor.wordWrap": "bounded",
  "editor.wordWrapColumn": 100,
  "editor.insertSpaces": true,
  "editor.tabSize": 2,
  "editor.autoIndent": "full",
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.eol": "\n",

  // --- YAML Formatting ---
  "[yaml]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "redhat.vscode-yaml"
  },

  // --- JSON Formatting ---
  "[json]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "vscode.json-language-features"
  },

  // --- Visual Helpers ---
  "editor.renderWhitespace": "boundary",
  "editor.rulers": [80, 100, 120],

  // --- Terminal Defaults ---
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.profiles": {
    "bash": { "path": "/bin/bash" },
    "zsh": { "path": "/bin/zsh" }
  }
}
```

</details>

---

## ⚠️ Common Pitfalls & Fixes

| Issue                          | Symptom                                    | Fix |
|--------------------------------|--------------------------------------------|-----|
| **CRLF drift**                 | Git shows unexpected line ending changes   | Re‑save file in VS Code (LF enforced) |
| **YAML indentation errors**    | Problems panel shows “bad indentation”     | Use 2 spaces only, never tabs |
| **Missing final newline**      | Git diff shows `\ No newline at end of file` | Save in VS Code → auto adds final newline |
| **Schema validation errors**   | Problems panel highlights invalid keys     | Check against schema, fix typos |
| **Token expired (HA only)**    | HA extension fails to connect              | Generate new long‑lived token in HA profile |

---

## 🛠 Disaster Recovery Checklist

1. Install VS Code → add extensions:  
   - Red Hat YAML (`redhat.vscode-yaml`)  
   - Home Assistant VS Code (`keesschollaart.vscode-home-assistant`) if HA configs present  
2. Copy `.vscode/settings.json` into repo.  
3. Adjust **word wrap column** or **terminal profiles** if needed.  
4. Verify:  
   - Saving YAML auto‑formats.  
   - Whitespace trimmed, final newline added.  
   - Problems panel shows validation errors if schema extensions are active.  

---

## To-Do

This README is now **aaa**:  
- scaffold a **`SETTINGS_INDEX.md`** file that just lists all `.vscode/settings.json` across repos, to track them in one place without cluttering this README.  
- create extensions.json for each repo too

---
