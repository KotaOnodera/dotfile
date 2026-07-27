#!/usr/bin/env bash
# Notification hook: Send Claude Code events to Google Chat

input=$(cat)
MESSAGE=$(echo "$input" | jq -r '.message')

case "$MESSAGE" in
  'Claude is waiting for your input')
    NOTIFY_MSG="Claudeはあなたの入力を待っています"
    ;;
  'Claude Code login successful')
    exit 0
    ;;
  'Claude needs your permission to use '*)
    NOTIFY_MSG="${MESSAGE#Claude needs your permission to use }の許可が必要です"
    ;;
  *)
    NOTIFY_MSG="${MESSAGE}"
    ;;
esac

if [ -z "$GOOGLE_CHAT_WEBHOOK_URL" ]; then
  exit 0
fi

curl -s -X POST \
  "${GOOGLE_CHAT_WEBHOOK_URL}" \
  -H "Content-Type: application/json; charset=UTF-8" \
  -d "{\"text\": \"Claude Code: ${NOTIFY_MSG}\"}" >/dev/null 2>&1
