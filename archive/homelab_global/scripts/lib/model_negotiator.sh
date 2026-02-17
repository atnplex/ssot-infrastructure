#!/usr/bin/env bash
source scripts/lib/env_manager.sh

# USAGE: source scripts/lib/model_negotiator.sh [fast|smart]
MODE="${1:-fast}"

# Safe Exit/Return helper
# shellcheck disable=SC2317
safe_exit() {
	return "$1" 2>/dev/null || exit "$1"
}

# Load keys
load_secrets || safe_exit 1

echo "🔍 Negotiating Model (Mode: $MODE)..."
if [[ -n "${BLACKLIST_MODELS:-}" ]]; then
	echo "🚫 Blacklisted: $BLACKLIST_MODELS"
fi

# 1. Fetch Available Models
MODELS_JSON=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_KEY_1")

if echo "$MODELS_JSON" | grep -q "error"; then
	echo "❌ API Error during negotiation."
	echo "$MODELS_JSON" | jq .error.message 2>/dev/null
	safe_exit 1
fi

# 2. Define Preference Filters based on Mode
if [[ "$MODE" == "smart" ]]; then
	# Smart: Prioritize Pro/Ultra -> Fallback to Flash
	# Lower number = Higher priority
	FILTER='
      if test("gemini-1.5-pro") then 1
      elif test("gemini-1.0-pro") then 2
      elif test("gemini-1.5-flash") then 3
      else 99 end
    '
else
	# Fast: Prioritize Flash -> Fallback to Pro
	FILTER='
      if test("gemini-1.5-flash") then 1
      elif test("gemini-1.0-pro") then 2
      elif test("gemini-1.5-pro") then 3
      else 99 end
    '
fi

# 3. Select Best Non-Blacklisted Model
# FIX: Wrapped in [ ... ] to create an array for sort_by
SELECTED_MODEL=$(echo "$MODELS_JSON" | jq -r --arg blacklist "${BLACKLIST_MODELS:-}" '
  [
    .models[] 
    | select(.supportedGenerationMethods[]? | contains("generateContent"))
    | .name |= sub("^models/"; "")
    | select(.name as $n | $blacklist | split(",") | index($n) | not)
    | {name: .name, priority: (.name | '"$FILTER"')}
  ] 
  | sort_by(.priority)
  | .[0].name
')

if [[ -z "$SELECTED_MODEL" || "$SELECTED_MODEL" == "null" ]]; then
	echo "❌ No suitable models left (all exhausted or blacklisted)."
	safe_exit 1
fi

echo "✅ Auto-selected: $SELECTED_MODEL"
export GEMINI_MODEL="$SELECTED_MODEL"

# Persist to secrets file for future runs
if grep -q "export GEMINI_MODEL=" "$SECRETS_FILE"; then
	sed -i "s|export GEMINI_MODEL=.*|export GEMINI_MODEL=\"$SELECTED_MODEL\"|" "$SECRETS_FILE"
else
	echo "export GEMINI_MODEL=\"$SELECTED_MODEL\"" >>"$SECRETS_FILE"
fi
