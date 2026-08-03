#!/usr/bin/env bash
#
# Emit one line per new PR review comment, review summary, issue comment, or
# failed check. Run it after opening a PR to catch the automatic Copilot
# review as it lands.
#
#   scripts/watch-pr-feedback.sh <pr-number> [repo]
#
# Each item is reported once: ids seen are recorded in a state file, so
# re-running does not replay a review you have already worked. Delete the
# state file to replay.
#
# Poll it from an agent as a Monitor command, or run it in a terminal. It
# does not exit on its own — a review can arrive minutes after the PR opens,
# and there is no signal that says "no more feedback is coming."

set -uo pipefail

PR="${1:?usage: watch-pr-feedback.sh <pr-number> [repo]}"
REPO="${2:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
INTERVAL="${WATCH_INTERVAL:-30}"

STATE="${TMPDIR:-/tmp}/pr-feedback-seen-$(printf '%s' "$REPO" | tr '/' '-')-$PR.txt"
touch "$STATE"

trim() { cut -c1-400; }

while true; do
  {
    # Inline review comments — the ones that need a threaded reply.
    gh api "repos/$REPO/pulls/$PR/comments?per_page=100" \
      --jq '.[] | "c\(.id)|\(.user.login) — \(.path):\(.line // .original_line // 0) — id=\(.id) — \(.body | gsub("\r?\n"; " "))"' 2>/dev/null

    # Review summaries (Copilot posts its overview as one of these).
    gh api "repos/$REPO/pulls/$PR/reviews?per_page=100" \
      --jq '.[] | select((.body // "") != "") | "r\(.id)|\(.user.login) — REVIEW \(.state) — \(.body | gsub("\r?\n"; " "))"' 2>/dev/null

    # Top-level PR conversation.
    gh api "repos/$REPO/issues/$PR/comments?per_page=100" \
      --jq '.[] | "i\(.id)|\(.user.login) — COMMENT — \(.body | gsub("\r?\n"; " "))"' 2>/dev/null

    # Every terminal check state that is not a pass, so a crashed job is not
    # silence. A filter that only matched successes would look identical to
    # "still running."
    gh pr checks "$PR" --repo "$REPO" --json name,bucket,link \
      --jq '.[] | select(.bucket == "fail" or .bucket == "cancel" or .bucket == "skipping")
            | "k\(.name)-\(.bucket)|CHECK \(.bucket | ascii_upcase) — \(.name) — \(.link)"' 2>/dev/null
  } | while IFS='|' read -r id rest; do
    [ -z "${id:-}" ] && continue
    if ! grep -qxF "$id" "$STATE"; then
      printf '%s\n' "$id" >> "$STATE"
      printf '%s\n' "$rest" | trim
    fi
  done

  sleep "$INTERVAL"
done
