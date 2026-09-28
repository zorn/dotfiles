#!/usr/bin/env bash
# Claude Code status line script
# Receives JSON on stdin and outputs a single status line.

input=$(cat)

# 1. Current working directory (use the pre-formatted workspace.current_dir which uses ~)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# 2. Git branch — only show if inside a git repo (skip optional locks)
branch=$(GIT_OPTIONAL_LOCKS=0 git -C "${cwd/#\~/$HOME}" rev-parse --abbrev-ref HEAD 2>/dev/null)

# 3. Model display name
model=$(echo "$input" | jq -r '.model.display_name // empty')

# 4. Context window usage percentage
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build the output
parts=()

# Directory + optional branch
if [ -n "$branch" ]; then
    parts+=("$cwd ($branch)")
else
    parts+=("$cwd")
fi

# Model
[ -n "$model" ] && parts+=("$model")

# Context usage
if [ -n "$used_pct" ]; then
    parts+=("$(printf '%.0f' "$used_pct")%")
fi

# Join with " | "
output=""
for part in "${parts[@]}"; do
    if [ -z "$output" ]; then
        output="$part"
    else
        output="$output | $part"
    fi
done

echo "$output"
