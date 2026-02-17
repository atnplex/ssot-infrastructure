# Remote Integration Guide (SSOT)

This document defines the standard for connecting devices within the homelab ecosystem using the "Charge and Forget" architecture.

## Overview

The goal is to enable robust, zero-touch remote access (RDP + SSH) to secondary nodes (laptops, headless servers) while optimizing for power efficiency and AI autonomy.

## Setup Requirements

### 1. Tailscale Mesh

All devices must be logged into **Tailscale**. This provides a persistent "Anchor IP" that never changes, regardless of the physical network.

### 2. Deployment Script

Use the universal deployment script located at `scripts/automation/Deploy-RemoteIntegration.ps1`.

**What it does:**

- Enables Remote Desktop (RDP).
- Disables UAC Secure Desktop (prevents blank screens during RDP sessions).
- Installs OpenSSH Server (via direct binary bypass for unreliable Windows Update systems).
- Configures "Always-On" Power settings (Stay awake if lid is closed, Network-Wake-Up enabled).
- Sets a 25% battery critical threshold to protect hardware.

## Reproduction Steps

1.  **Clone the SSOT**:
    ```powershell
    git clone https://github.com/atnplex/homelab_global.git
    cd homelab_global
    ```
2.  **Run the Setup**:
    ```powershell
    pwsh -ExecutionPolicy Bypass -File .\scripts\automation\Deploy-RemoteIntegration.ps1
    ```
3.  **Deploy the Connection Manager (ACM)**:
    On your primary desktop, run:
    ```powershell
    pwsh -ExecutionPolicy Bypass -File .\scripts\automation\register_ACM.ps1
    ```

## Maintenance

AG Agents must follow **Rule R29** (Git Workflow) and run `git pull --rebase` before modifying any automation logic to ensure they are using the latest proven patterns.
