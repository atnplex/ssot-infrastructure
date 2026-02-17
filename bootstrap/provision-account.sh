#!/usr/bin/env bash
# =============================================================================
# ATN Account Provisioner
# Provisions OCI accounts using cached .bootstrap.env credentials.
# Usage: ./provision-account.sh account3 [--skip-tailscale]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_ENV="${SCRIPT_DIR}/.bootstrap.env"
ACCOUNT="${1:-}"
SKIP_TS="${2:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
fail() {
	echo -e "${RED}✗${NC} $1"
	exit 1
}
info() { echo -e "${CYAN}→${NC} $1"; }

# ---------- Validate ----------
if [[ -z "$ACCOUNT" ]]; then
	echo "Usage: $0 <account1|account2|account3> [--skip-tailscale]"
	exit 1
fi

if [[ ! -f "$BOOTSTRAP_ENV" ]]; then
	fail ".bootstrap.env not found. Run .bootstrap.sh first."
fi

source "$BOOTSTRAP_ENV"
echo "=== ATN Account Provisioner: $ACCOUNT ==="
echo ""

# ---------- Account mapping ----------
declare -A ACCOUNT_EMAILS=(
	[account1]="anguy079@gmail.com"
	[account2]="wongkm1alex@gmail.com"
	[account3]="anhnguy079@gmail.com"
)

declare -A INSTANCE_NAMES=(
	[account1]="arm1"
	[account2]="arm2"
	[account3]="arm3"
)

EXPECTED_EMAIL="${ACCOUNT_EMAILS[$ACCOUNT]:-}"
INSTANCE_NAME="${INSTANCE_NAMES[$ACCOUNT]:-}"

if [[ -z "$EXPECTED_EMAIL" ]]; then
	fail "Unknown account: $ACCOUNT"
fi

# ---------- Step 1: Verify OCI Account ----------
info "[1/6] Verifying OCI account..."

ACTUAL_EMAIL=$(docker exec -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True mcp-oci \
	oci iam user list --output json 2>/dev/null |
	python3 -c "import sys,json; print(json.load(sys.stdin)['data'][0]['email'])" 2>/dev/null || echo "unknown")

TENANCY_NAME=$(docker exec -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True mcp-oci \
	oci iam tenancy get --tenancy-id "$OCI_TENANCY_ID" --output json 2>/dev/null |
	python3 -c "import sys,json; print(json.load(sys.stdin)['data']['name'])" 2>/dev/null || echo "unknown")

if [[ "$ACTUAL_EMAIL" != "$EXPECTED_EMAIL" ]]; then
	fail "OCI account mismatch! Expected: $EXPECTED_EMAIL, Got: $ACTUAL_EMAIL"
fi
ok "OCI account verified: $ACTUAL_EMAIL (tenancy: $TENANCY_NAME)"

# ---------- Step 2: Check existing instances ----------
info "[2/6] Checking existing instances..."

EXISTING=$(docker exec -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True mcp-oci \
	python3 -c "
import subprocess, json, os
os.environ['OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING'] = 'True'
r = subprocess.run(['oci','compute','instance','list','--compartment-id','$OCI_TENANCY_ID','--all','--output','json'], capture_output=True, text=True)
for i in json.loads(r.stdout)['data']:
    if i['lifecycle-state'] not in ('TERMINATED','TERMINATING'):
        sc = i.get('shape-config',{}) or {}
        print(f\"{i['display-name']}|{i['lifecycle-state']}|{i['shape']}|{sc.get('ocpus','?')}|{sc.get('memory-in-gbs','?')}\")
" 2>/dev/null || echo "")

if [[ -n "$EXISTING" ]]; then
	echo "  Existing instances:"
	echo "$EXISTING" | while IFS='|' read -r name state shape cpu mem; do
		echo "    $name ($shape, ${cpu} OCPU, ${mem}GB) — $state"
	done
fi

# Check if target instance already exists
if echo "$EXISTING" | grep -q "^${INSTANCE_NAME}|"; then
	ok "Instance $INSTANCE_NAME already exists"
	INSTANCE_IP=$(docker exec -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True mcp-oci \
		python3 -c "
import subprocess, json, os
os.environ['OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING'] = 'True'
r = subprocess.run(['oci','compute','instance','list','--compartment-id','$OCI_TENANCY_ID','--all','--output','json'], capture_output=True, text=True)
for i in json.loads(r.stdout)['data']:
    if i['display-name'] == '$INSTANCE_NAME' and i['lifecycle-state'] == 'RUNNING':
        r2 = subprocess.run(['oci','compute','vnic-attachment','list','--compartment-id','$OCI_TENANCY_ID','--instance-id',i['id'],'--output','json'], capture_output=True, text=True)
        vnics = json.loads(r2.stdout)['data']
        if vnics:
            r3 = subprocess.run(['oci','network','vnic','get','--vnic-id',vnics[0]['vnic-id'],'--output','json'], capture_output=True, text=True)
            print(json.loads(r3.stdout)['data'].get('public-ip',''))
" 2>/dev/null || echo "")
	ok "Public IP: $INSTANCE_IP"
else
	info "Instance $INSTANCE_NAME not found — would need to provision"
	warn "Provisioning not implemented in this script yet (use OCI console or mcp-oci)"
	exit 1
fi

# ---------- Step 3: Verify SSH ----------
info "[3/6] Verifying SSH access..."

if ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
	"ubuntu@${INSTANCE_IP}" "hostname" &>/dev/null; then
	HOSTNAME=$(ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=10 "ubuntu@${INSTANCE_IP}" "hostname" 2>/dev/null)
	ok "SSH verified: ubuntu@${INSTANCE_IP} (hostname: $HOSTNAME)"
else
	fail "SSH failed to ubuntu@${INSTANCE_IP}"
fi

# ---------- Step 4: Install Docker ----------
info "[4/6] Checking Docker..."

DOCKER_VER=$(ssh -i ~/.ssh/id_ed25519 "ubuntu@${INSTANCE_IP}" "docker --version 2>/dev/null" || echo "")
if [[ -n "$DOCKER_VER" ]]; then
	ok "Docker: $DOCKER_VER"
else
	info "Installing Docker..."
	ssh -i ~/.ssh/id_ed25519 "ubuntu@${INSTANCE_IP}" "curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker ubuntu"
	ok "Docker installed"
fi

# ---------- Step 5: Tailscale ----------
info "[5/6] Configuring Tailscale..."

if [[ "$SKIP_TS" == "--skip-tailscale" ]]; then
	warn "Skipping Tailscale (--skip-tailscale flag)"
else
	TS_STATUS=$(ssh -i ~/.ssh/id_ed25519 "ubuntu@${INSTANCE_IP}" "sudo tailscale status 2>&1" || echo "not installed")

	if echo "$TS_STATUS" | grep -q "Logged out\|not installed\|stopped"; then
		if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
			info "Authenticating Tailscale with cached auth key..."
			ssh -i ~/.ssh/id_ed25519 "ubuntu@${INSTANCE_IP}" \
				"sudo tailscale up --authkey '${TAILSCALE_AUTHKEY}' --ssh --accept-routes"
			ok "Tailscale authenticated"
		else
			warn "No Tailscale auth key cached. Run .bootstrap.sh to set one."
		fi
	else
		ok "Tailscale already connected"
	fi

	TS_IP=$(ssh -i ~/.ssh/id_ed25519 "ubuntu@${INSTANCE_IP}" "tailscale ip -4 2>/dev/null" || echo "N/A")
	ok "Tailscale IP: $TS_IP"
fi

# ---------- Step 6: Update hostname ----------
info "[6/6] Setting hostname..."

CURRENT_HOSTNAME=$(ssh -i ~/.ssh/id_ed25519 "ubuntu@${INSTANCE_IP}" "hostname" 2>/dev/null)
if [[ "$CURRENT_HOSTNAME" != "$INSTANCE_NAME" ]]; then
	ssh -i ~/.ssh/id_ed25519 "ubuntu@${INSTANCE_IP}" "sudo hostnamectl set-hostname $INSTANCE_NAME"
	ok "Hostname set: $INSTANCE_NAME (was: $CURRENT_HOSTNAME)"
else
	ok "Hostname: $INSTANCE_NAME"
fi

# ---------- Summary ----------
echo ""
echo "=== PROVISIONING COMPLETE ==="
echo "  Account:      $ACCOUNT ($EXPECTED_EMAIL)"
echo "  Instance:     $INSTANCE_NAME"
echo "  Public IP:    ${INSTANCE_IP:-N/A}"
echo "  Tailscale IP: ${TS_IP:-N/A}"
echo "  Docker:       ${DOCKER_VER:-installed}"
echo "  SSH:          ✓ verified"
echo ""
echo "Next: ansible-playbook ansible/deploy.yml -l $ACCOUNT"
