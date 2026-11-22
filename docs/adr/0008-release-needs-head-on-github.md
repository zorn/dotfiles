# Release Needs HEAD on GitHub

`/dispatch release` removes a worktree whose work is not merged, so a worktree waiting on review, or abandoned, does not sit on the machine. It removes one only when a pull request for its branch, in any state, has a head commit that equals the worktree's `HEAD` or descends from it, the worktree has no uncommitted changes, and every agent in it is idle or done. Either way GitHub holds every commit in the worktree, so deleting the local branch with `-D` loses nothing.

## Consequences & Tradeoffs

This extends [ADR 0006](0006-dispatch-cleans-up-via-prune.md), where a pull request closed without merging never qualifies. Release allows it because the user names the worktree, or says `release all`, and confirms the list before anything is removed. Clean removes without asking, so it keeps its stricter rule: a merged pull request at the worktree's exact `HEAD`.

Ancestry rather than equality lets Release remove a worktree that a later push left behind, such as a review worktree on a pull request someone else keeps pushing to. The comparison needs the pull request's head commit locally. `worktree-status.sh` fetches a missing one from `refs/pull/<n>/head`, not from the branch, because a squash merge can delete the branch while GitHub keeps the pull request ref. When the commit is still missing, the pull request does not count, so the worktree stays.

Release checks again just before each removal, because an idle agent can wake during the wait for "go" and commit without pushing. A clean tree does not stop `wt remove`, so `-D` would delete that commit.

Resuming uses `wt herdr-resume`, because `wt herdr` passes `--create`, which ignores the remote branch and starts a new one from `main`. A repo that opts in to databases gets new ones in the resumed worktree. Refreshing a stale worktree in place was rejected: a release followed by `/dispatch <PR>` gives the same result without a third Launch path.

This follows [zorn-rxv/dotfiles ADR 0004](https://github.com/zorn-rxv/dotfiles/blob/main/docs/adr/0004-release-needs-a-pushed-head.md) and its amendment, [ADR 0005](https://github.com/zorn-rxv/dotfiles/blob/main/docs/adr/0005-release-allows-a-stale-head.md), which settled the same rule in two steps.
