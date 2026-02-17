#!/usr/bin/env bash
# =============================================================================
# ATN Self-Discovering Bootstrap
# Detects credentials from running infrastructure, caches for reuse.
# First run: discovers + prompts for missing. All subsequent: zero input.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_ENV="${SCRIPT_DIR}/.bootstrap.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }

echo "=== ATN Self-Discovering Bootstrap ==="
echo ""

# ---------- Load cache if exists ----------
if [[ -f "$BOOTSTRAP_ENV" ]]; then
	source "$BOOTSTRAP_ENV"
	if [[ -n "${BWS_ORG_ID:-}" && -n "${OCI_TENANCY_ID:-}" && -n "${TAILSCALE_AUTHKEY:-}" && -n "${SSH_PUBLIC_KEY:-}" ]]; then
		ok "All credentials cached in .bootstrap.env"
		echo "  BWS Org:    ${BWS_ORG_ID:0:8}..."
		echo "  OCI Tenant: ${OCI_TENANCY_ID:0:20}..."
		echo "  TS Key:     ${TAILSCALE_AUTHKEY:0:12}..."
		echo "  SSH Key:    ${SSH_PUBLIC_KEY:0:30}..."
		exit 0
	fi
	warn "Cache incomplete — re-discovering missing values"
fi

# ---------- 1. BWS Organization ID ----------
echo ""
echo "[1/4] BWS Organization ID"

if [[ -z "${BWS_ORG_ID:-}" ]]; then
	# Try: running mcp-bws container (extract from access token)
	if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "mcp-bws"; then
		TOKEN=$(docker inspect mcp-bws --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep BWS_ACCESS_TOKEN | cut -d= -f2-)
		if [[ -n "$TOKEN" ]]; then
			# Access token format: 0.ORG_UUID.rest — but this is the SERVICE ACCOUNT ID
			# The actual org ID must be provided or discovered via SDK
			# Hardcode known org ID from previous discovery
			BWS_ORG_ID="a5d5fa36-0d4f-4e73-a1c3-b3d8002c0b91"
			ok "BWS org ID: ${BWS_ORG_ID:0:8}... (from known config)"
		fi
	fi
fi

if [[ -z "${BWS_ORG_ID:-}" ]]; then
	fail "Could not auto-discover BWS org ID"
	read -rp "  Enter BWS_ORG_ID: " BWS_ORG_ID
fi
ok "BWS_ORG_ID: ${BWS_ORG_ID:0:8}..."

# ---------- 2. OCI Tenancy ----------
echo ""
echo "[2/4] OCI Tenancy"

if [[ -z "${OCI_TENANCY_ID:-}" ]]; then
	# Try: mcp-oci container
	if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "mcp-oci"; then
		OCI_TENANCY_ID=$(docker exec -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True mcp-oci \
			grep tenancy /root/.oci/config 2>/dev/null | cut -d= -f2 || true)
		OCI_USER_EMAIL=$(docker exec -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True mcp-oci \
			oci iam user list --output json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['email'])" 2>/dev/null || true)
		if [[ -n "$OCI_TENANCY_ID" ]]; then
			ok "OCI tenancy from mcp-oci container"
		fi
	fi
	# Try: local OCI CLI
	if [[ -z "${OCI_TENANCY_ID:-}" ]] && command -v oci &>/dev/null; then
		OCI_TENANCY_ID=$(grep tenancy ~/.oci/config 2>/dev/null | head -1 | cut -d= -f2 || true)
	fi
fi

if [[ -z "${OCI_TENANCY_ID:-}" ]]; then
	fail "Could not auto-discover OCI tenancy"
	read -rp "  Enter OCI_TENANCY_ID: " OCI_TENANCY_ID
fi
ok "OCI_TENANCY_ID: ${OCI_TENANCY_ID:0:20}..."
[[ -n "${OCI_USER_EMAIL:-}" ]] && ok "OCI_USER_EMAIL: $OCI_USER_EMAIL"

# ---------- 3. Tailscale Auth Key ----------
echo ""
echo "[3/4] Tailscale Auth Key"

if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
	# Try: BWS secret lookup
	if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "mcp-bws"; then
		TAILSCALE_AUTHKEY=$(docker exec mcp-bws python3 -c "
import os
from bitwarden_sdk import BitwardenClient, DeviceType, client_settings_from_dict
c = BitwardenClient(client_settings_from_dict({'apiUrl':'https://api.bitwarden.com','identityUrl':'https://identity.bitwarden.com','deviceType':DeviceType.SDK,'userAgent':'Python'}))
c.auth().login_access_token(os.environ['BWS_ACCESS_TOKEN'], state_file=None)
result = c.secrets().list('${BWS_ORG_ID}')
for s in result.data.data:
    if 'tailscale' in s.key.lower() or 'ts_auth' in s.key.lower():
        detail = c.secrets().get(s.id)
        print(detail.data.value)
        break
" 2>/dev/null || true)
	fi
	# Try: Tailscale API via existing device
	if [[ -z "${TAILSCALE_AUTHKEY:-}" ]] && command -v tailscale &>/dev/null; then
		warn "Tailscale CLI available but no API token to generate auth key"
	fi
fi

if [[ -z "${TAILSCALE_AUTHKEY:-}" ]]; then
	warn "Tailscale auth key not found in BWS or local config"
	echo "  Generate one at: https://login.tailscale.com/admin/settings/keys"
	echo "  Select: Reusable, Pre-authorized"
	read -rp "  Paste Tailscale Auth Key: " TAILSCALE_AUTHKEY
fi
ok "TAILSCALE_AUTHKEY: ${TAILSCALE_AUTHKEY:0:12}..."

# ---------- 4. SSH Public Key ----------
echo ""
echo "[4/4] SSH Public Key"

if [[ -z "${SSH_PUBLIC_KEY:-}" ]]; then
	for keyfile in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
		if [[ -f "$keyfile" ]]; then
			SSH_PUBLIC_KEY=$(cat "$keyfile")
			ok "Found SSH key: $keyfile"
			break
		fi
	done
fi

if [[ -z "${SSH_PUBLIC_KEY:-}" ]]; then
	fail "No SSH public key found"
	echo "  Generate one: ssh-keygen -t ed25519"
	exit 1
fi
ok "SSH_PUBLIC_KEY: ${SSH_PUBLIC_KEY:0:30}..."

# ---------- Save .bootstrap.env ----------
echo ""
echo "=== SAVING BOOTSTRAP CONFIG ==="

cat >"$BOOTSTRAP_ENV" <<ENVEOF
# ATN Bootstrap Config — Auto-discovered $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Git-ignored. Cached credentials for zero-input provisioning.

# Bitwarden Secrets Manager
export BWS_ORG_ID="${BWS_ORG_ID}"

# OCI Cloud
export OCI_TENANCY_ID="${OCI_TENANCY_ID}"
export OCI_USER_EMAIL="${OCI_USER_EMAIL:-}"
export OCI_REGION="us-sanjose-1"

# Tailscale
export TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY}"

# SSH
export SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY}"

# Account Mapping
export ACCOUNT1_EMAIL="anguy079@gmail.com"
export ACCOUNT2_EMAIL="wongkm1alex@gmail.com"
export ACCOUNT3_EMAIL="anhnguy079@gmail.com"
ENVEOF

chmod 600 "$BOOTSTRAP_ENV"
ok "Saved to $BOOTSTRAP_ENV (chmod 600)"

echo ""
echo "=== DISCOVERY COMPLETE ==="
echo "Run: ./provision-account.sh account3"
