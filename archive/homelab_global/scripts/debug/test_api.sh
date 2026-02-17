#!/usr/bin/env bash
source scripts/lib/env_manager.sh
load_secrets

echo "🔍 Testing GEMINI_KEY_1..."
echo "Key Length: ${#GEMINI_KEY_1}"

# Construct a simple JSON
JSON='{"contents":[{"parts":[{"text":"Say Hello"}]}]}'

# Call API and show Headers + Body
curl -v -X POST \
  -H 'Content-Type: application/json' \
  -d "$JSON" \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_KEY_1"
