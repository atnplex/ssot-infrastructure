#!/usr/bin/env bash
source scripts/lib/env_manager.sh

# ARGS: $1 = Log Directory, $2 = Branch Name
LOG_DIR="$1"
BRANCH_NAME="$2"

# 1. Load Secrets (Silent Mode)
load_secrets || exit 0

# 2. Negotiate "Fast" Model (Force Flash for cost/speed)
source scripts/lib/model_negotiator.sh fast >/dev/null 2>&1

# 3. Gather Data
DIFF_STAT=$(git diff --stat HEAD~1 2>/dev/null)
LOG_TAIL=$(tail -n 50 "$LOG_DIR/ai_loop.log" 2>/dev/null)

# 4. Construct Prompt
PROMPT="Analyze this automated refactor run.
BRANCH: $BRANCH_NAME
CHANGES:
$DIFF_STAT
LOGS:
$LOG_TAIL

TASK: Write a concise 1-line summary bullet point for a Changelog.
FORMAT: '- [Auto-Refactor] <Summary> (<Files Changed> files)'"

# 5. Call AI (Manual curl to avoid dependency loops)
PAYLOAD=$(jq -n --arg txt "$PROMPT" '{contents:[{parts:[{text:$txt}]}]}')
SUMMARY=$(curl -s -X POST -H 'Content-Type: application/json' \
    -d "$PAYLOAD" \
    "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=$GEMINI_KEY_1" \
    | jq -r '.candidates[0].content.parts[0].text // empty')

# 6. Update Changelog (Atomic Append)
if [[ -n "$SUMMARY" ]]; then
    echo "$SUMMARY" >> docs/automation/CHANGELOG_AI.md
fi
