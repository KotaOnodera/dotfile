#!/bin/bash
# Open nvim in a new Ghostty window

files=()
for f in "$@"; do
  abs="$(cd "$(dirname "$f")" 2>/dev/null && pwd)/$(basename "$f")"
  files+=("$abs")
done

open -na Ghostty.app --args --command="nvim ${files[*]}"
