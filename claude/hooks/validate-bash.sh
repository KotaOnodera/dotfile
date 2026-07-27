#!/bin/bash
# PreToolUse hook: Validate Bash commands before execution

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
command=$(echo "$input" | jq -r '.tool_input.command // ""')

if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

deny() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DENY: $command | Reason: $1" >> ~/.local/state/claude-hooks.log
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

if echo "$command" | grep -qE '\bawk\b'; then
  deny "Use of 'awk' is prohibited. Use 'perl' instead. Example: perl -lane 'print \$F[0]' file.txt"
fi

if echo "$command" | grep -qE '\bsed\b'; then
  deny "Use of 'sed' is prohibited. Use 'perl' instead. Example: perl -pi -e 's/old/new/g' file.txt"
fi

if echo "$command" | grep -qE '\bgit\s+push\b'; then
  # Allow git push inside ~/github/reports
  resolved_cwd=$(cd "$PWD" 2>/dev/null && pwd -P)
  resolved_reports=$(cd "$HOME/github/reports" 2>/dev/null && pwd -P)
  if [[ -z "$resolved_reports" ]] || [[ "$resolved_cwd" != "$resolved_reports" && "$resolved_cwd" != "$resolved_reports"/* ]]; then
    deny "Do not execute 'git push'. Please ask the user to execute it."
  fi
fi

if echo "$command" | grep -qE '\bgit\s+add\s+(-A|--all|\.($|[ ;|&]))'; then
  deny "Do not git-add all files. Specify the file name(s) to add."
fi

exit 0
