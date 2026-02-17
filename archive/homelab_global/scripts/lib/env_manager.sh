#!/usr/bin/env bash
# file: scripts/lib/env_manager.sh
# purpose: Secrets loading and GitHub CLI helper functions (no side effects on source).

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

# SSOT File Path
SECRETS_FILE="${SECRETS_FILE:-$HOME/.homelab_secrets}"

ensure_gh_cli() {
	if command -v gh >/dev/null 2>&1; then
		return 0
	fi

	echo -e "${YELLOW}[Auto-Heal] Installing GitHub CLI...${NC}"
	curl -fsSL "https://cli.github.com/packages/githubcli-archive-keyring.gpg" |
		sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
	sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
		sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

	sudo apt-get update -qq
	sudo apt-get install -y -qq gh
}

load_secrets() {
	# 1) Try Local File (VPS Priority)
	if [[ -f "$SECRETS_FILE" ]]; then
		# shellcheck disable=SC1090
		source "$SECRETS_FILE"
	fi

	# 2) Validation
	if [[ -z "${GEMINI_KEY_1:-}" ]]; then
		echo -e "${RED}[Error] GEMINI_KEY_1 is missing.${NC}"
		echo "Edit $SECRETS_FILE to fix."
		return 1
	fi

	return 0
}

sync_to_github() {
	ensure_gh_cli

	if ! gh auth status >/dev/null 2>&1; then
		echo -e "${YELLOW}[Sync] Skipped - gh not authenticated.${NC}"
		return 0
	fi

	echo -e "${YELLOW}[Sync] Pushing secrets to GitHub...${NC}"
	local keys=("GEMINI_KEY_1" "GEMINI_KEY_2" "GEMINI_KEY_3" "GEMINI_KEY_4" "GEMINI_KEY_5" "GH_PAT")

	for key in "${keys[@]}"; do
		local val="${!key:-}"
		if [[ -n "$val" ]]; then
			gh secret set "$key" --body "$val" >/dev/null 2>&1 || true
		fi
	done

	echo -e "${GREEN}[Sync] Done.${NC}"
}
