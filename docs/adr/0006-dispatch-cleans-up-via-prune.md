# Dispatch Cleans Up via Prune

The `dispatch` skill finds finished worktrees with `wt step prune --dry-run --min-age 0s --format=json`, not by asking GitHub whether each pull request merged. It then removes each one with `wt remove`, skipping any candidate whose reason is `same commit as` or whose agent is still `working`. worktrunk already detects squash-merged work from git alone and runs our teardown hooks on removal, so the skill reuses that rather than rebuilding it from `gh` calls. Settled in [issue #95](https://github.com/zorn/dotfiles/issues/95).

## Consequences & Tradeoffs

Two alternatives were rejected. Checking `gh pr view --json state` per worktree trusts GitHub's word over the code: a merged pull request can leave commits behind on the branch, which a removal would then discard, and it costs a network call per worktree. Running prune live, without `--dry-run`, cannot leave out an individual candidate, so it would remove the two that must stay.

Those two exclusions are the sharp edge. `--min-age 0s` lets a worktree merged the same day qualify, but it also makes a freshly launched worktree, whose branch still matches `main`, look integrated under the `same commit as` reason. Removing it would kill the agent just starting there. A worktree whose agent is still working would be killed the same way, because removal closes its Herdr workspace.

Prune measures integration against the local `main`, so cleanup pulls `main` first. A pull request closed without merging never qualifies, and its worktree stays until a person decides.
