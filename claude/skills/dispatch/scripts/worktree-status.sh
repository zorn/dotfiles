#!/usr/bin/env bash
#
# Print one JSON object per linked worktree of the repo in the current
# directory, as a JSON array: the six columns of the dispatch Status table,
# plus the facts Release checks.
#
#   worktree-status.sh            # every linked worktree
#   worktree-status.sh <branch>   # only that branch's worktree
#
# Run it from the primary checkout. It fetches a PR's head commit when that
# commit is missing here. It changes nothing else. Each row:
#
#   label       the Herdr workspace label, or null
#   branch      the worktree's branch
#   path        the worktree's path
#   head        the worktree's HEAD commit
#   agents      [{name, status}] for every Herdr agent whose cwd is inside it
#   pr          {number, state, holds_head} or null. The open PR, else one
#               that holds HEAD: its head is HEAD or a descendant of it. A
#               merged PR that does not hold HEAD belongs to an earlier branch
#               with the same name, so it is not shown.
#   checks      {pass, fail, pending, skipping, cancel} counts, "unavailable"
#               when the lookup failed, or null with no PR
#   dirty       the number of `git status --porcelain` lines
#   releasable  "yes", or the first reason Release would refuse it

set -euo pipefail

only="${1:-}"

agents_json="$(herdr agent list)"
workspaces_json="$(herdr workspace list)"

# `git worktree list --porcelain` prints the primary checkout first; skip its
# record by position, because a detached primary prints no branch line. A
# detached linked worktree has no branch line either, and dispatch never makes
# one. macOS ships bash 3.2, which has no mapfile, so read the rows from a
# variable.
rows="$(
  git worktree list --porcelain |
    awk '/^worktree /{n++; p=substr($0,10)} /^branch /{if (n > 1) {b=substr($0,8); sub("^refs/heads/","",b); print p "\t" b}}'
)"

out="[]"
while IFS=$'\t' read -r path branch; do
  [ -n "$path" ] || continue
  [ -z "$only" ] || [ "$branch" = "$only" ] || continue

  head="$(git -C "$path" rev-parse HEAD)"
  dirty="$(git -C "$path" status --porcelain | wc -l | tr -d ' ')"

  label="$(jq --arg p "$path" '[.result.workspaces[] | select(.worktree.checkout_path == $p) | .label][0]' <<<"$workspaces_json")"

  # Match on a path boundary, so /repo.feature-a does not claim /repo.feature-ab's agent.
  agents="$(jq --arg p "$path" '[.result.agents[]
      | select((.cwd // "") as $c | $c == $p or ($c | startswith($p + "/")))
      | {name, status: .agent_status}]' <<<"$agents_json")"

  # Ancestry, not equality: a teammate can push to a PR under review and leave
  # the worktree behind. Fetch a missing head from refs/pull/<n>/head, because
  # a squash merge can delete the branch. A head that is still missing fails
  # merge-base, so the worktree stays.
  prs="$(gh pr list --head "$branch" --state all --json number,state,headRefOid)"
  held="[]"
  while read -r n oid; do
    [ -n "$oid" ] || continue
    git cat-file -e "$oid^{commit}" 2>/dev/null ||
      git fetch -q origin "refs/pull/$n/head" 2>/dev/null || true
    if git merge-base --is-ancestor "$head" "$oid" 2>/dev/null; then
      held="$(jq --arg o "$oid" '. + [$o]' <<<"$held")"
    fi
  done <<<"$(jq -r '.[] | "\(.number) \(.headRefOid)"' <<<"$prs")"
  pr="$(jq --argjson held "$held" '
      map(. + {holds_head: (.headRefOid as $o | $held | index($o) != null)})
      | ((map(select(.state == "OPEN")) + map(select(.holds_head)))[0])
      | if . == null then null else {number, state, holds_head} end' <<<"$prs")"

  checks=null
  number="$(jq -r '.number // empty' <<<"$pr")"
  if [ -n "$number" ]; then
    # gh exits non-zero when a check failed or is pending, and its JSON is still
    # complete. A failed lookup prints no JSON, so it reads "unavailable" rather
    # than as a PR with nothing failing.
    checks_err="$(mktemp)"
    checks_raw="$(gh pr checks "$number" --json bucket 2>"$checks_err" || true)"
    if grep -q 'no checks reported' "$checks_err"; then checks_raw='[]'; fi
    rm -f "$checks_err"
    if jq -e 'type == "array"' <<<"$checks_raw" >/dev/null 2>&1; then
      checks="$(jq 'reduce .[] as $c ({pass: 0, fail: 0, pending: 0, skipping: 0, cancel: 0}; .[$c.bucket] += 1)' <<<"$checks_raw")"
    else
      checks='"unavailable"'
    fi
  fi

  # Release's three checks, in the order the skill lists them.
  # Any PR that holds HEAD counts, not only the one shown in the pr column.
  releasable="$(jq -n --argjson held "$held" --argjson agents "$agents" --arg dirty "$dirty" '
      if ($held | length) == 0 then "no pull request holds HEAD"
      elif $dirty != "0" then "uncommitted changes"
      elif any($agents[]; .status == "working" or .status == "blocked") then "agent is working or blocked"
      else "yes" end')"

  out="$(jq \
    --argjson label "$label" --arg branch "$branch" --arg path "$path" --arg head "$head" \
    --argjson agents "$agents" --argjson pr "$pr" --argjson checks "$checks" \
    --argjson dirty "$dirty" --argjson releasable "$releasable" \
    '. + [{label: $label, branch: $branch, path: $path, head: $head, agents: $agents,
           pr: $pr, checks: $checks, dirty: $dirty, releasable: $releasable}]' <<<"$out")"
done <<<"$rows"

jq . <<<"$out"
