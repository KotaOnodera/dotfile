#!/usr/bin/env bash
# Claude Code statusline: model, directory, git branch with colored context bar

input=$(cat)
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')

# Git branch info
GIT_BRANCH=""
if git rev-parse &>/dev/null; then
  BRANCH=$(git branch --show-current)
  if [ -n "$BRANCH" ]; then
    GIT_BRANCH=" |  $BRANCH"
  else
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$COMMIT_HASH" ]; then
      GIT_BRANCH=" |  HEAD ($COMMIT_HASH)"
    fi
  fi
fi

# Context usage info from JSON
total_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // null')

# Format token counts
if [ "$total_tokens" -ge 1000000 ] 2>/dev/null; then
  token_display=$(awk "BEGIN{printf \"%.1fM\", $total_tokens/1000000}")
elif [ "$total_tokens" -ge 1000 ] 2>/dev/null; then
  token_display=$(awk "BEGIN{printf \"%.1fK\", $total_tokens/1000}")
else
  token_display="$total_tokens"
fi

if [ "$context_window_size" -ge 1000000 ] 2>/dev/null; then
  context_display=$(awk "BEGIN{printf \"%.1fM\", $context_window_size/1000000}")
elif [ "$context_window_size" -ge 1000 ] 2>/dev/null; then
  context_display=$(awk "BEGIN{printf \"%.1fK\", $context_window_size/1000}")
else
  context_display="$context_window_size"
fi

# Color codes
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# Create colored context bar (40 characters wide)
CONTEXT_LINE=""
if [ "$used_percentage" != "null" ] && [ -n "$used_percentage" ]; then
  percentage=$(printf "%.0f" "$used_percentage")
  bar_width=40
  filled=$((percentage * bar_width / 100))
  empty=$((bar_width - filled))

  # Choose color based on usage
  if [ "$percentage" -ge 90 ] 2>/dev/null; then
    COLOR="$RED"
  elif [ "$percentage" -ge 70 ] 2>/dev/null; then
    COLOR="$YELLOW"
  else
    COLOR="$GREEN"
  fi

  # Build bar
  bar_filled=""
  bar_empty=""
  for ((i=0; i<filled; i++)); do bar_filled+="█"; done
  for ((i=0; i<empty; i++)); do bar_empty+="░"; done

  CONTEXT_LINE="\nContext: [${COLOR}${bar_filled}${DIM}${bar_empty}${RESET}] ${COLOR}${token_display}${RESET}/${context_display} (${COLOR}${percentage}%%${RESET})"
fi

# Line 1: model, dir, git branch
# Line 2: context bar with colors
printf '%b' "󰚩 ${MODEL_DISPLAY} |  ${CURRENT_DIR##*/}${GIT_BRANCH}${CONTEXT_LINE}"
