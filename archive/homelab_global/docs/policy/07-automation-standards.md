# Automation Standards & AI Checklist

## 1. Environment & Workspace
* **Dynamic Paths:** NEVER hardcode paths like `/tmp` or `/home/alex`.
    * *Requirement:* Use variables sourced from `scripts/lib/init_workspace.sh`.
    * *Standard:* Use `$ATN_WORK_DIR` for all temporary operations.
* **RAM Disk:** High-IO operations (git worktrees, logs) must occur in `$ATN_WORK_DIR` (tmpfs) to reduce disk wear and latency.
* **Idempotency:** Scripts must check state before acting.
    * *Example:* If a directory exists, clear it or skip creation. If a mount exists, do not remount.

## 2. Secrets & SSOT
* **Source of Truth (SSOT):** * Primary: `~/.homelab_secrets` (Local Cache).
    * Fallback: Scripts must fail gracefully with a clear message if keys are missing.
* **Auto-Heal:** If a key fails (401/403), the script should mark it bad and attempt the next available key/model before exiting.

## 3. User Feedback & Observability
* **Visual Logs:** Status updates (e.g., "Mounting...", "Negotiating...") must be printed to STDOUT.
* **Heartbeat:** Long-running processes (>10s) must spawn a background heartbeat function to output `⏳ Working...` every 30s.
* **Auditability:** Final results must explicitly state:
    * Which Model was used.
    * Where logs are located.
    * Exit Code / Success Status.

## 4. Error Handling
* **Fail Fast, Fail Loud:** Do not fail silently. If a critical dependency (API Key, Workspace) is missing, print a user-friendly error block and exit.
* **Self-Correction:** Where possible, scripts should attempt to fix the environment (e.g., `init_workspace.sh` creating directories) before failing.

## 5. Async & Background Processing
* **Non-Blocking Summaries:** Tasks like changelog generation or metric summarization must run in the background (`nohup` or `&`) to avoid blocking the interactive terminal.
* **Cost Efficiency:** Use the "Fast" model tier (e.g., Flash) for background summarization tasks.

## 6. Script Architecture (Mandatory)
* **Init Header:** All scripts must source `scripts/lib/env_manager.sh` and `scripts/lib/init_workspace.sh` at the top.
* **Dynamic Variables:** NEVER use hardcoded paths. Use `$ATN_WORK_DIR` for temp files.
* **Heartbeat:** Any script expected to run >10s must use the standard `heartbeat` function from the library.

## 7. File Structure & Metadata (Strict)
- Shebang must be the first line: `#!/usr/bin/env bash`
- Immediately after shebang, include a commented metadata block:
  - `# file: path/to/script.sh`
  - `# purpose: one-line description`
- Strict mode must come next (entrypoints):
  - Prefer: `set -euo pipefail` (or `set -u -o pipefail` if you intentionally avoid `-e`)
- Imports must come after strict mode:
  - `source scripts/lib/env_manager.sh` etc.
- Never include markdown links inside shell scripts (no `[text](url)` formatting).

## 8. Library Side-Effects
- Files under `scripts/lib/` must NOT execute actions on source (no automatic mounts, no automatic installs).
- Entrypoint scripts (under `scripts/automation/` and invoked by users/CI) should call any needed init functions explicitly (e.g., `init_ram_disk`).
