# Dispatch Cleans Up via Prune

The `dispatch` skill removes a worktree only when two checks agree: a dry run of `wt step prune` lists it, so its work is in `main`, and its pull request is merged on GitHub. Prune alone cannot tell a finished worktree from a freshly launched one, and GitHub alone cannot tell whether removing the branch loses work. Settled in [issue #95](https://github.com/zorn/dotfiles/issues/95) and its pull request, #102.

## Consequences & Tradeoffs

Prune detects squash-merged work from git, and `wt remove` runs our teardown hooks, so the skill reuses both rather than rebuilding them. But `--min-age 0s`, which lets a worktree merged the same day qualify, also lists a worktree with no commits. Prune reports that worktree as `same commit as`, or as `ancestor of` once `main` moves on, which happens as soon as another agent's pull request merges. Removing it would kill the agent just starting there. A merged pull request is what tells the two apart.

GitHub alone was rejected because it trusts a label over the code: a merged pull request can leave commits behind on its branch, and a removal would discard them. The prune check guards against that. Running prune live, without `--dry-run`, was rejected because it cannot leave out an individual candidate.

A pull request closed without merging never qualifies, even when its changes reached `main` another way, so its worktree stays until a person decides. A failed lookup also leaves the worktree in place. Prune measures integration against the local `main`, so cleanup pulls `main` first, and a worktree whose agent is still working is skipped, because removal closes its Herdr workspace.
