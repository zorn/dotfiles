# Dispatch Cleans Up via Prune

The `dispatch` skill finds finished worktrees with a dry run of `wt step prune`, not by asking GitHub whether each pull request merged, and then removes each one with `wt remove`. worktrunk already detects squash-merged work from git alone and runs our teardown hooks on removal, so the skill reuses that rather than rebuilding it from `gh` calls. Settled in [issue #95](https://github.com/zorn/dotfiles/issues/95).

## Consequences & Tradeoffs

Two alternatives were rejected. The first was checking `gh pr view --json state` for each worktree. That check trusts GitHub's word over the code. A merged pull request can leave commits behind on its branch, and a removal would then discard them. The check also costs a network call per worktree. The second was running prune live, without `--dry-run`. A live run cannot leave out an individual candidate, so it would remove the two kinds of candidate that must stay.

Those two kinds are the sharp edge. `--min-age 0s` lets a worktree merged the same day qualify, but it also makes a freshly launched worktree look integrated, under the reason `same commit as`, because its branch still matches `main`. Removing it would kill the agent just starting there. A worktree whose agent is still working would be killed the same way, because removal closes its Herdr workspace. So the skill keeps only the reason `all changes in`, and it skips any candidate whose agent is working. A reason it has not seen gets reported, not removed.

Prune measures integration against the local `main`, so cleanup pulls `main` first. A pull request closed without merging never qualifies, and its worktree stays until a person decides.
