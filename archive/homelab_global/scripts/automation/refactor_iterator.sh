#!/usr/bin/env bash
# file: scripts/automation/refactor_iterator.sh
# purpose: Iterate over target scripts and ask Gemini to rewrite files to satisfy ShellCheck/qa.

set -euo pipefail

# shellcheck disable=SC1091
source scripts/lib/env_manager.sh

# Ensure LOG_DIR is set (run_once.sh exports it)
if [[ -z "${LOG_DIR:-}" ]]; then
	echo "❌ LOG_DIR not set. Run via scripts/automation/run_once.sh"
	exit 1
fi

TARGET_PATTERN="${1:-scripts/qa/*.sh}"
STATUS_FILE="status.txt"
BACKOFF_DELAY=5

log() {
	echo "[$(date +%T)] $1" | tee -a "$LOG_DIR/iterator.log"
}

update_status() {
	echo "$1" >"$STATUS_FILE"
	log "$1"
}

read_policy() {
	if [[ -f docs/policy/07-automation-standards.md ]]; then
		# Keep it bounded to avoid huge prompts; expand later if needed.
		sed -n "1,220p" docs/policy/07-automation-standards.md
	fi
}

# Load secrets and pick a model (quiet; dashboard handles output)
load_secrets >/dev/null 2>&1 || exit 1
# shellcheck disable=SC1091
source scripts/lib/model_negotiator.sh fast >/dev/null 2>&1 || exit 1

log "🔍 Starting Iterator on: $TARGET_PATTERN"

SEARCH_DIR="$(dirname -- "$TARGET_PATTERN")"
NAME_GLOB="$(basename -- "$TARGET_PATTERN")"

find "$SEARCH_DIR" -type f -name "$NAME_GLOB" 2>/dev/null | sort | while IFS= read -r FILE; do
	# --- IDEMPOTENCY CHECK ---
	if command -v shellcheck >/dev/null 2>&1; then
		if shellcheck "$FILE" >/dev/null 2>&1; then
			update_status "✅ Skipped (Clean): $(basename "$FILE")"
			continue
		fi
		ERR_CODES="$(shellcheck -f gcc "$FILE" 2>&1 | grep -o "SC[0-9]*" | head -n 3 | tr "\n" " ")"
		ERRORS="$(shellcheck -f gcc "$FILE" 2>&1 | head -n 40)"
	else
		ERR_CODES="General"
		ERRORS="General refactoring needed."
	fi

	update_status "🤖 Fixing $(basename "$FILE") [$ERR_CODES]..."

	POLICY_TEXT="$(read_policy || true)"

	PROMPT="$(
		cat <<PROMPT_EOF
You are a Code Fixer for a Bash repository.

PROJECT POLICY (follow strictly):
$POLICY_TEXT

TASK:
Fix the errors in this file so ShellCheck/qa will pass.

FILE PATH:
$FILE

FILE CONTENT:
$(cat "$FILE")

ERRORS:
$ERRORS

STRICT OUTPUT RULES:
1) Output ONLY the raw, full content of the fixed file (no unified diff).
2) Do NOT use markdown code fences.
3) Preserve intent; make minimal necessary changes.
PROMPT_EOF
	)"

	RETRIES=0
	while [[ $RETRIES -lt 3 ]]; do
		if [[ $RETRIES -gt 0 ]]; then
			SLEEP_TIME=$((BACKOFF_DELAY * RETRIES * RETRIES))
			update_status "⏳ API Limit. Sleeping ${SLEEP_TIME}s..."
			sleep "$SLEEP_TIME"
		fi

		response_file="$(mktemp)"
		tmp_file="$(mktemp)"
		rm_guard() { rm -f "$response_file" "$tmp_file"; }
		trap rm_guard RETURN

		PAYLOAD="$(jq -n --arg txt "$PROMPT" "{contents:[{parts:[{text:\$txt}]}]}")"
		HTTP_STATUS="$(curl -s -o "$response_file" -w "%{http_code}" -X POST \
			-H "Content-Type: application/json" \
			-d "$PAYLOAD" \
			"https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=$GEMINI_KEY_1")"

		if [[ "$HTTP_STATUS" != "200" ]]; then
			log "⚠️ API Error $HTTP_STATUS"
			((RETRIES++))
			continue
		fi

		NEW_CONTENT="$(jq -r ".candidates[0].content.parts[0].text // empty" <"$response_file")"

		if [[ -n "$NEW_CONTENT" && ${#NEW_CONTENT} -gt 10 ]]; then
			# Strip any accidental markdown fences
			CLEAN_CONTENT="$(printf "%s" "$NEW_CONTENT" | sed '/^```/d')"
			printf "%s" "$CLEAN_CONTENT" >"$tmp_file"

			if bash -n "$tmp_file" 2>/dev/null; then
				cp -a "$FILE" "$FILE.bak.$(date +%s)" 2>/dev/null || true
				cat "$tmp_file" >"$FILE"
				update_status "💾 Saved: $(basename "$FILE")"
				break
			fi

			log "⚠️ AI Syntax Error. Retrying..."
		fi

		((RETRIES++))
	done

	sleep 1
done

update_status "Done"
