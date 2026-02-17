# Tailscale Device Approval Workflow

## Overview

We use Tailscale OAuth Client Credentials (`tag:server`) to authenticate servers. In some cases, devices still require admin approval even with valid keys (depending on Tailnet ACLs).

## Automated Approval

Usage:

```bash
# Using the approve_tailscale.sh script (requires BWS secrets)
./approve_tailscale.sh
```

## Manual API Approval

If the script is unavailable, you can approve a device using the Tailscale API manually:

1. **Get Access Token**:

   ```bash
   curl -d "client_id=$CLIENT_ID" -d "client_secret=$CLIENT_SECRET" "https://api.tailscale.com/api/v2/oauth/token"
   ```

2. **Find Device ID**:

   ```bash
   curl -H "Authorization: Bearer $TOKEN" "https://api.tailscale.com/api/v2/tailnet/-/devices"
   ```

3. **Approve**:
   ```bash
   curl -X POST -H "Authorization: Bearer $TOKEN" -d '{"authorized": true}' "https://api.tailscale.com/api/v2/device/$DEVICE_ID/authorized"
   ```

## BWS Secrets

The following secrets are stored in BWS (`bootstrap` and `config` projects) to enable this:

- `TAILSCALE_OAUTH_CLIENT_ID`
- `PROVISIONER_API_TOKEN_TAILSCALE` (Client Secret)
