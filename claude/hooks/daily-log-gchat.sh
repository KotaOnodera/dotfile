#!/bin/bash
# Daily log notification to Google Chat (multi-section card)
# Usage: echo "log content" | daily-log-gchat.sh "ProjectName - Task Title"
#
# Sections are separated by "---" lines.
# Each section becomes a separate card section in Google Chat.
#
# Env: GOOGLE_CHAT_DAILY_LOG_WEBHOOK_URL (required)

set -euo pipefail

TITLE="${1:-Daily Log}"
BODY=$(cat)

if [ -z "${GOOGLE_CHAT_DAILY_LOG_WEBHOOK_URL:-}" ]; then
  echo "ERROR: GOOGLE_CHAT_DAILY_LOG_WEBHOOK_URL is not set" >&2
  exit 1
fi

if [ -z "$BODY" ]; then
  echo "ERROR: No log content provided via stdin" >&2
  exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Section icons for visual distinction
SECTION_ICONS=(
  "📋"  # 概要
  "📁"  # 変更ファイル
  "🔍"  # 技術的判断
  "💡"  # 問題と学び
  "📌"  # TODO・リスク
)

# Split body into sections by "---" separator and build JSON array
SECTIONS_JSON=$(printf '%s\n' "$BODY" | perl -0777 -pe 's/\n---\n/\x{00}/g' | {
  idx=0
  first=true
  echo "["
  while IFS= read -r -d '' section || [ -n "$section" ]; do
    # Trim leading/trailing whitespace (whole section, not per-line)
    section=$(printf '%s' "$section" | perl -0777 -pe 's/\A\s+//; s/\s+\z//')
    [ -z "$section" ] && continue
    icon="${SECTION_ICONS[$idx]:-📎}"
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    jq -n --arg text "${icon} ${section}" \
      '{"widgets": [{"textParagraph": {"text": $text}}]}'
    idx=$((idx + 1))
  done
  echo "]"
})

# Fallback: if section parsing produced empty array, use full body as single section
if [ "$SECTIONS_JSON" = "[]" ] || [ -z "$SECTIONS_JSON" ]; then
  SECTIONS_JSON=$(jq -n --arg text "$BODY" \
    '[{"widgets": [{"textParagraph": {"text": $text}}]}]')
fi

# Build Google Chat card message
PAYLOAD=$(jq -n \
  --arg title "$TITLE" \
  --arg subtitle "$TIMESTAMP" \
  --argjson sections "$SECTIONS_JSON" \
  '{
    "cardsV2": [{
      "cardId": "dailyLog",
      "card": {
        "header": {
          "title": $title,
          "subtitle": $subtitle,
          "imageUrl": "https://fonts.gstatic.com/s/i/short-term/release/googlesymbols/task_alt/default/48px.svg",
          "imageType": "CIRCLE"
        },
        "sections": $sections
      }
    }]
  }')

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  "${GOOGLE_CHAT_DAILY_LOG_WEBHOOK_URL}" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -d "$PAYLOAD")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "OK: Daily log sent to Google Chat (HTTP ${HTTP_CODE})"
else
  echo "ERROR: Google Chat webhook returned HTTP ${HTTP_CODE}" >&2
  exit 1
fi
