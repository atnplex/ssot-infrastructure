#!/usr/bin/env bash
# file: scripts/automation/ai_refactor_loop.sh
# purpose: Loop calling Gemini for unified diffs until a goal command passes.

set -u -o pipefail
# shellcheck disable=SC1091
source scripts/lib/env_manager.sh

# 1. Setup
load_secrets || exit 1
export BLACKLIST_MODELS=""

# Initial Negotiation
source scripts/lib/model_negotiator.sh fast || exit 1

# Config
MAX_LOOPS=5
GOAL_CMD="${GOAL_CMD:-make qa}"
LOG_FILE="qa_errors.log"
CURRENT_LOOP=1
GEMINI_KEYS=("${GEMINI_KEY_1:-}" "${GEMINI_KEY_2:-}" "${GEMINI_KEY_3:-}" "${GEMINI_KEY_4:-}" "${GEMINI_KEY_5:-}")
KEY_COUNT=${#GEMINI_KEYS[@]}

ask_gemini() {
	local prompt_text="$1"
	local idx=$(((CURRENT_LOOP - 1) % KEY_COUNT))
	local key="${GEMINI_KEYS[$idx]}"

	if [[ -z "$key" ]]; then
		echo "null"
		return
	fi

	local payload
	payload=$(jq -n --arg txt "$prompt_text" '{contents:[{parts:[{text:$txt}]}]}')

	local http_code
	local response_file
	response_file=$(mktemp)
	http_code=$(curl -s -w "%{http_code}" -o "$response_file" -X POST \
		-H 'Content-Type: application/json' \
		-d "$payload" \
		"https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=$key")

	if [[ "$http_code" != "200" ]]; then
		echo >&2 "⚠️  API Error ($http_code)"
		rm "$response_file"
		echo "ERROR"
		return
	fi

	jq -r '.candidates[0].content.parts[0].text // "null"' <"$response_file"
	rm "$response_file"
}

echo "Starting Loop (Model: $GEMINI_MODEL)..."

while [[ "$CURRENT_LOOP" -le "$MAX_LOOPS" ]]; do
	echo "--- Loop $CURRENT_LOOP ---"

	# Check if we are passing specific instructions or just the goal
	if $GOAL_CMD >/dev/null 2>&1; then
		echo "✅ Goal Reached!"
		exit 0
	fi

	$GOAL_CMD >"$LOG_FILE" 2>&1 || true
	ERRORS=$(tail -n 20 "$LOG_FILE")

	# Use custom instruction if set (e.g. from your manual run)
	PROMPT="${CUSTOM_INSTRUCTION:-Fix this code. Errors: $ERRORS}. Return ONLY a unified diff."

	RESPONSE=$(ask_gemini "$PROMPT")

	if [[ "$RESPONSE" == "ERROR" || "$RESPONSE" == "null" ]]; then
		echo "⚠️  Model failed. Retrying..."
		source scripts/lib/model_negotiator.sh fast
		continue
	fi

	# Save and Apply Patch
	PATCH_FILE="ai_fix_$CURRENT_LOOP.patch"
	echo "$RESPONSE" >"$PATCH_FILE"

	if grep -q "^diff" "$PATCH_FILE"; then
		echo "📝 Applying Patch..."
		# Try to apply. If it fails, ignore and loop again (AI might correct itself)
		git apply --whitespace=fix "$PATCH_FILE" || echo "⚠️ Patch failed to apply cleanly."
	else
		echo "⚠️ Response was not a diff. Skipping."
	fi

	((CURRENT_LOOP++))
done
