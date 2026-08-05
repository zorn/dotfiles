#!/usr/bin/env bash
#
# Emit one line per new PR review comment, review summary, or issue comment,
# and one per check that fails or is cancelled, so a crashed job does not read
# as silence. Run it after opening a PR to catch the automatic Copilot review
# as it lands.
#
#   ~/.claude/skills/implement/scripts/watch-pr-feedback.sh <pr-number> [repo]
#
# Two streams, deliberately separated:
#
#   stdout  one line per new item. Under an agent's Monitor each of these
#           becomes a notification, so this stream stays selective.
#   stderr  a status line every poll — elapsed time, what has been seen, and
#           the check rollup. On a terminal it rewrites itself in place; piped
#           to a file it appends a line per poll. Monitor routes stderr to the
#           output file without notifying, so this is free to be chatty.
#
# The split is what makes "nothing has happened yet" distinguishable from
# "this has wedged." Never run it as a blocking foreground call: it polls
# until told to stop, so it will only consume the caller's timeout.
#
# Environment:
#
#   WATCH_INTERVAL       steady-state poll interval, seconds (default 30)
#   WATCH_FAST_INTERVAL  poll interval inside the fast window (default 10)
#   WATCH_FAST_WINDOW    seconds to poll fast before settling down (120) — an
#                        automatic review usually lands inside two minutes,
#                        which is exactly when a slow poll is most annoying
#   WATCH_SETTLE         set to 1 to exit once the PR has gone quiet: every
#                        check finished, at least one review in, and no new
#                        item for WATCH_SETTLE_POLLS polls. Off by default,
#                        because there is no signal that says "no more
#                        feedback is coming" and guessing wrong ends the watch
#                        early.
#   WATCH_SETTLE_POLLS   consecutive quiet polls before settling (default 2)
#
# Each item is reported once: ids seen are recorded in a state file, so
# re-running does not replay a review you have already worked. That also means
# a re-run after a finished watch looks silent — delete the state file, whose
# path is printed in the opening status line, to replay.

set -uo pipefail

PR="${1:?usage: watch-pr-feedback.sh <pr-number> [repo]  (env: WATCH_INTERVAL)}"
REPO="${2:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
INTERVAL="${WATCH_INTERVAL:-30}"
FAST_INTERVAL="${WATCH_FAST_INTERVAL:-10}"
FAST_WINDOW="${WATCH_FAST_WINDOW:-120}"
SETTLE="${WATCH_SETTLE:-0}"
SETTLE_POLLS="${WATCH_SETTLE_POLLS:-2}"

STATE="${TMPDIR:-/tmp}/pr-feedback-seen-$(printf '%s' "$REPO" | tr '/' '-')-$PR.txt"
touch "$STATE"

ITEMS="$(mktemp)"
trap 'rm -f "$ITEMS"' EXIT

truncate_line() { cut -c1-400; }

# Whether a rewritable status line is sitting on the terminal right now, so an
# event can push it down instead of printing over the top of it.
status_pending=0

status() {
  if [ -t 2 ]; then
    printf '\r\033[2K%s' "$1" >&2
    status_pending=1
  else
    printf '%s\n' "$1" >&2
  fi
}

end_status_line() {
  if [ "$status_pending" -eq 1 ]; then
    printf '\n' >&2
    status_pending=0
  fi
}

# How many recorded ids carry a given one-character kind prefix. `grep -c`
# exits 1 when it matches nothing, which would otherwise take the script down.
seen_count() { grep -c "^$1" "$STATE" 2>/dev/null || true; }

elapsed_clock() { printf '%02d:%02d' "$(($1 / 60))" "$(($1 % 60))"; }

started=$(date +%s)
polls=0
quiet_polls=0

status "watching $REPO#$PR — state file $STATE"
end_status_line

while true; do
  polls=$((polls + 1))
  elapsed=$(($(date +%s) - started))

  # Fetched once and used for both the failure events and the status rollup,
  # so a poll costs one call here rather than two.
  checks_json=$(gh pr checks "$PR" --repo "$REPO" --json name,bucket,link 2>/dev/null || printf '[]')

  {
    # Inline review comments — the ones that need a threaded reply.
    gh api --paginate "repos/$REPO/pulls/$PR/comments?per_page=100" \
      --jq '.[] | "c\(.id)|\(.user.login) — \(.path):\(.line // .original_line // 0) — id=\(.id) — \(.body | gsub("\r?\n"; " "))"' 2>/dev/null

    # Review summaries (Copilot posts its overview as one of these).
    gh api --paginate "repos/$REPO/pulls/$PR/reviews?per_page=100" \
      --jq '.[] | select((.body // "") != "") | "r\(.id)|\(.user.login) — REVIEW \(.state) — \(.body | gsub("\r?\n"; " "))"' 2>/dev/null

    # Top-level PR conversation.
    gh api --paginate "repos/$REPO/issues/$PR/comments?per_page=100" \
      --jq '.[] | "i\(.id)|\(.user.login) — COMMENT — \(.body | gsub("\r?\n"; " "))"' 2>/dev/null

    # A crashed or cancelled job must not read as silence, so both are
    # reported. "skipping" is not: a skipped check is almost always a
    # deliberately path-filtered or conditional job, and on a repo with any
    # `if:`-gated workflow it would bury the real feedback every poll.
    printf '%s' "$checks_json" |
      jq -r '.[] | select(.bucket == "fail" or .bucket == "cancel")
             | "k\(.name)-\(.bucket)|CHECK \(.bucket | ascii_upcase) — \(.name) — \(.link)"' 2>/dev/null
  } >"$ITEMS"

  # Redirected rather than piped, so the counter survives the loop instead of
  # dying with the subshell a pipeline would put it in.
  new_count=0
  while IFS='|' read -r id rest; do
    [ -z "${id:-}" ] && continue
    if ! grep -qxF "$id" "$STATE"; then
      printf '%s\n' "$id" >>"$STATE"
      end_status_line
      printf '%s\n' "$rest" | truncate_line
      new_count=$((new_count + 1))
    fi
  done <"$ITEMS"

  if [ "$new_count" -eq 0 ]; then
    quiet_polls=$((quiet_polls + 1))
  else
    quiet_polls=0
  fi

  pending=$(printf '%s' "$checks_json" | jq -r '[.[] | select(.bucket == "pending")] | length' 2>/dev/null || printf '0')
  rollup=$(printf '%s' "$checks_json" | jq -r '[group_by(.bucket)[] | "\(length) \(.[0].bucket)"] | join(", ")' 2>/dev/null)
  [ -z "$rollup" ] && rollup='no checks yet'

  reviews_seen=$(seen_count r)

  if [ "$elapsed" -lt "$FAST_WINDOW" ]; then
    sleep_for="$FAST_INTERVAL"
  else
    sleep_for="$INTERVAL"
  fi

  # A settled watch ends on stdout, not in silence: under Monitor that final
  # line is the notification saying the watch is over rather than stalled.
  if [ "$SETTLE" != '0' ] &&
    [ "${pending:-1}" -eq 0 ] &&
    [ "${reviews_seen:-0}" -gt 0 ] &&
    [ "$quiet_polls" -ge "$SETTLE_POLLS" ]; then
    end_status_line
    printf 'WATCH SETTLED — checks: %s; %s inline, %s review(s), %s comment(s); quiet for %d polls\n' \
      "$rollup" "$(seen_count c)" "$reviews_seen" "$(seen_count i)" "$quiet_polls"
    exit 0
  fi

  status "[$(elapsed_clock "$elapsed")] poll $polls · $(seen_count c) inline, $reviews_seen review(s), $(seen_count i) comment(s) · checks: $rollup · next in ${sleep_for}s"

  sleep "$sleep_for"
done
