#!/usr/bin/env bash
#
# Check one Launch row and print a JSON verdict for it.
#
#   preflight.sh <branch> <issue-number>
#   preflight.sh --pr <PR number or URL>
#
# The branch is the planned zorn/issue-<NNN>-<slug> branch. Run it from the
# primary checkout. It runs `git fetch --prune`, so the remote checks see
# GitHub as it is now, and changes nothing else. It prints:
#
#   checkout   {branch, clean} of the primary checkout
#   verdict    "clear", "skip", "resume", or "rename"
#   reason     why, for every verdict but "clear"
#   branch     the branch to launch: the planned one, or the PR's on "resume"
#   agent      the agent name, issue-<NNN>
#   fast_forward  true when a leftover local branch must be fast-forwarded to
#              origin before the launch
#
# The branch prefix zorn/issue-<NNN>- ties every branch to its issue, so an
# earlier run is found by the prefix, whatever its slug. The verdicts follow
# Launch step 3 of the dispatch skill:
#   skip    an agent already has the name; an open PR of mine for the issue
#           has a worktree or a local branch with commits origin lacks; more
#           than one open PR of mine for the issue is resumable; or, with no
#           such PR, the planned branch or another branch for the issue exists
#   resume  exactly one open PR of mine for the issue has no worktree and no
#           live agent, so it was released
#   rename  the planned branch name is taken on GitHub by an earlier branch or PR
#   clear   none of the above
#
# With --pr, the row is a PR row: a pull request, not an issue. Its verdict
# is "pr", "skip", or "refuse". The output adds number, agent (pr-<number>),
# title, author, and mine, which is true when the gh user is the author:
#   refuse  the PR belongs to another repo, is not open, or comes from a fork
#   skip    its worktree exists here, its local branch has commits origin
#           lacks, or its agent is already live
#   pr      none of the above; launch it on the PR's branch

set -euo pipefail

usage() { sed -n '3,7p' "$0" >&2; exit 2; }

if [ "${1:-}" = --pr ]; then
  [ $# -eq 2 ] || usage
  pr_ref="$2"
else
  [ $# -eq 2 ] || usage
  pr_ref="" branch="$1" issue="$2"
  case "$issue" in '' | *[!0-9]*) usage ;; esac
  prefix="zorn/issue-$issue-"
  agent="issue-$issue"
  case "$branch" in
    "$prefix"?*) ;;
    *) printf 'preflight.sh: %s must start with %s\n' "$branch" "$prefix" >&2; exit 2 ;;
  esac
fi

git fetch --prune -q

checkout_branch="$(git branch --show-current)"
[ -z "$(git status --porcelain)" ] && clean=true || clean=false

worktree_branches="$(git worktree list --porcelain | awk '/^branch /{b=substr($0,8); sub("^refs/heads/","",b); print b}')"
has_worktree() { grep -qxF "$1" <<<"$worktree_branches"; }
branch_taken() { [ -n "$(git branch --list "$1")" ] || has_worktree "$1"; }
# A plain wt remove keeps an unmerged local branch, and wt herdr-resume reuses
# it instead of origin/<branch>. Prints "none", "behind" when origin holds all
# of it so a fast-forward is safe, or "ahead" when it has commits origin lacks.
leftover() {
  if [ -z "$(git branch --list "$1")" ]; then echo none
  elif git merge-base --is-ancestor "refs/heads/$1" "refs/remotes/origin/$1" 2>/dev/null; then echo behind
  else echo ahead; fi
}
# Read Herdr once, outside any condition, so a failed lookup aborts the run
# rather than reading as "no such agent".
agents_json="$(herdr agent list)"
jq -e '.result.agents | type == "array"' <<<"$agents_json" >/dev/null
agent_live() { jq -e --arg a "$1" 'any(.result.agents[]; .name == $a)' <<<"$agents_json" >/dev/null; }

if [ -n "$pr_ref" ]; then
  pr="$(gh pr view "$pr_ref" --json number,url,state,headRefName,isCrossRepository,title,author)"
  me="$(gh api user | jq -r .login)"
  repo="$(gh repo view --json nameWithOwner | jq -r .nameWithOwner)"
  number="$(jq -r .number <<<"$pr")"
  head_ref="$(jq -r .headRefName <<<"$pr")"
  agent="pr-$number"
  verdict=pr reason="" fast_forward=false

  # gh pr view opens a URL from any repo, so the PR must be this repo's.
  # GitHub names are case-insensitive.
  if ! jq -e --arg r "$repo" '(.url | ascii_downcase) | startswith("https://github.com/" + ($r | ascii_downcase) + "/pull/")' <<<"$pr" >/dev/null; then
    verdict=refuse reason="PR #$number belongs to another repo, not $repo"
  # A closed or merged PR has no review or second round left to work on.
  elif [ "$(jq -r .state <<<"$pr")" != OPEN ]; then
    verdict=refuse reason="PR #$number is $(jq -r '.state | ascii_downcase' <<<"$pr"), not open"
  # wt herdr-resume builds from origin/<branch>, and origin has no fork branch.
  elif [ "$(jq -r .isCrossRepository <<<"$pr")" = true ]; then
    verdict=refuse reason="PR #$number comes from a fork, so origin has no $head_ref"
  elif has_worktree "$head_ref"; then
    verdict=skip reason="a worktree for $head_ref already exists"
  elif [ "$(leftover "$head_ref")" = ahead ]; then
    verdict=skip reason="local branch $head_ref has commits origin lacks"
  elif agent_live "$agent"; then
    verdict=skip reason="an agent named $agent is already live"
  elif [ "$(leftover "$head_ref")" = behind ]; then
    fast_forward=true
  fi

  jq -n \
    --arg cb "$checkout_branch" --argjson clean "$clean" \
    --arg verdict "$verdict" --arg reason "$reason" --argjson pr "$pr" --arg me "$me" \
    --arg agent "$agent" --argjson ff "$fast_forward" \
    '{checkout: {branch: $cb, clean: $clean}, verdict: $verdict,
      reason: (if $reason == "" then null else $reason end),
      branch: $pr.headRefName, number: $pr.number, agent: $agent,
      mine: ($pr.author.login == $me), title: $pr.title, author: $pr.author.login,
      fast_forward: $ff}'
  exit 0
fi

# --author @me keeps a teammate's PR on a same-named branch from being resumed.
my_prs="$(gh pr list --state open --author @me --limit 200 --json number,headRefName,isCrossRepository |
  jq --arg p "$prefix" 'map(select(.headRefName | startswith($p)))')"
# Any other local branch or worktree for the issue, such as one with an older
# slug. The arguments are branches that do not count.
other_local() {
  { git branch --list "$prefix*" --format='%(refname:short)'; grep -F "$prefix" <<<"$worktree_branches" || true; } |
    grep -vxF -e "$1" -e "${2:-$1}" | head -n 1 || true
}
# Checked assignments, so a failed lookup aborts instead of reading as "unused".
remote_head="$(git ls-remote --heads origin "$branch")"
old_prs="$(gh pr list --head "$branch" --state all --json number | jq length)"

verdict=clear reason="" launch="$branch" fast_forward=false

# Open PRs come before the planned branch: a plain wt remove keeps the local
# branch, and a re-dispatch can derive the same slug, so a branch that exists
# here may belong to a released PR that should resume.
dispatched="" resumable=()
while read -r number head_ref cross; do
  [ -n "$head_ref" ] || continue
  # wt herdr-resume builds from origin/<branch>, and origin has no fork branch.
  if [ "$cross" = true ]; then
    dispatched="open PR #$number for issue #$issue comes from a fork, so origin has no $head_ref"
  elif has_worktree "$head_ref"; then
    dispatched="open PR #$number is on $head_ref, and its worktree exists"
  elif [ "$(leftover "$head_ref")" = ahead ]; then
    dispatched="open PR #$number is on $head_ref, and that local branch has commits origin lacks"
  else
    resumable+=("$number $head_ref")
  fi
done <<<"$(jq -r '.[] | "\(.number) \(.headRefName) \(.isCrossRepository)"' <<<"$my_prs")"

if agent_live "$agent"; then
  verdict=skip reason="an agent named $agent is already live"
elif [ -n "$dispatched" ]; then
  verdict=skip reason="$dispatched"
elif [ "${#resumable[@]}" -gt 1 ]; then
  verdict=skip reason="several open PRs of mine are for issue #$issue; release or close all but one"
elif [ "${#resumable[@]}" -eq 1 ] && read -r number head_ref <<<"${resumable[0]}" &&
  [ -n "$(other_local "$head_ref" "$branch")" ]; then
  verdict=skip reason="branch $(other_local "$head_ref" "$branch") for issue #$issue exists here beside released PR #$number"
elif [ "${#resumable[@]}" -eq 1 ]; then
  [ "$(leftover "$head_ref")" = behind ] && fast_forward=true
  verdict=resume reason="open PR #$number is on $head_ref and was released; the resumed worktree gets new databases" launch="$head_ref"
elif branch_taken "$branch"; then
  verdict=skip reason="branch $branch already exists here"
elif [ -n "$(other_local "$branch")" ]; then
  verdict=skip reason="branch $(other_local "$branch") for issue #$issue already exists here"
elif [ -n "$remote_head" ] || [ "$old_prs" -gt 0 ]; then
  verdict=rename reason="$branch is taken on GitHub by an earlier branch or PR; pick another slug"
fi

jq -n \
  --arg cb "$checkout_branch" --argjson clean "$clean" \
  --arg verdict "$verdict" --arg reason "$reason" --arg branch "$launch" \
  --arg agent "$agent" --argjson ff "$fast_forward" \
  '{checkout: {branch: $cb, clean: $clean}, verdict: $verdict,
    reason: (if $reason == "" then null else $reason end), branch: $branch,
    agent: $agent, fast_forward: $ff}'
