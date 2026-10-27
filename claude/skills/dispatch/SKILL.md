---
name: dispatch
description: Dispatch parallel agents into worktrunk worktrees from the primary checkout, report on them, and clean up merged ones.
argument-hint: "Issue numbers or URLs to launch, or \"status\", or \"clean up\""
disable-model-invocation: true
---

You are the dispatcher. You send agents out to their own worktrees, know where each one is, and bring the finished ones back. You never do an agent's work yourself.

Pick the branch from the argument: issue numbers or URLs mean **Launch**, `status` means **Status**, and `clean up` means **Clean up**. With no argument, run Status.

## Rules for every branch

- **Stay in the primary checkout.** Run every command from it, and never `cd` your shell into a worktree ([herdrdev/herdr#4293](https://github.com/herdrdev/herdr/issues/4293)). The global Worktrees rule tells you how to detect a linked worktree; if you are in one, stop and say so. [`worktrunk/README.md`](https://github.com/zorn/dotfiles/blob/main/worktrunk/README.md) is the runbook for `wt herdr` and `wt remove`.
- **Ask Herdr about agents.** Run `herdr agent list` before you say anything about an agent. It gives each agent's `cwd` and `agent_status`. Your memory of what you started is not evidence of what is running.
- **Refresh before you report remote state.** Run `git fetch --prune` before you say whether a branch or pull request exists on GitHub.
- **Read `herdr --skill` before your first `herdr agent` command.** Herdr maintains it, and it covers readiness, `blocked` states, and timeouts.

## Launch

1. **Resolve the issues.** Each argument is an issue number or a GitHub issue URL, in any mix. A URL must name this repo (`gh repo view --json nameWithOwner`). If one names another repo, stop, name that issue, and launch none of the batch.

2. **Check the primary checkout.** It must be on `main` with a clean tree. Run `git pull --ff-only`, so every worktree starts from the same current `main`. Otherwise stop and say what is wrong.

3. **Plan, and wait for "go".** Read each issue with `gh issue view <n>`. Name its branch `zorn/issue-<NNN>-<slug>`, as `/implement`'s Branch step does. Show one row per issue: number, title, branch, and the Herdr label (`#<NNN>` and the first two slug words). Wait for "go" before you create anything.

4. **Create each worktree.** Run `wt herdr <branch>`. Its last line is JSON. Read the new pane's ID from `.result.root_pane.pane_id`.

5. **Start each agent.** Name it after the issue, such as `issue-271`:

   ```sh
   herdr agent start issue-271 --kind claude --pane <pane-id>
   herdr agent prompt issue-271 "/implement 271" --wait --timeout 120000
   ```

   Each agent pauses inside its own workspace when `/implement` needs a decision, so `blocked` is expected later. If `agent start` returns `agent_not_ready`, read the agent before prompting it, as Herdr's guide says.

Launch is done when `herdr agent list` shows one agent per issue, each with its `cwd` in its own worktree. Report the table from Status.

## Status

Run this only when asked; do not poll. After `git fetch --prune`, build one row per linked worktree from `git worktree list`:

| Column | Source |
| --- | --- |
| Label | `herdr workspace list`, matched on `worktree.checkout_path` |
| Branch | `git worktree list` |
| Agent | `herdr agent list`, matched on `cwd`; "none" when no agent matches |
| Pull request | `gh pr list --head <branch> --state all --json number,state` |
| Checks | `gh pr checks <number>`, when a pull request exists |

A pull request closed without merging gets a row like any other. Its worktree stays until the user decides what to do with it.

## Clean up

1. **Refresh `main`.** It must be checked out in the primary checkout. Run `git pull --ff-only`, because worktrunk measures integration against the local `main`.

2. **Find the candidates.** Run `wt step prune --dry-run --min-age 0s --format=json`. Keep the entries whose `kind` is `worktree` and whose `reason` is not `same commit as`. A worktree whose branch still matches `main` has no work yet; it is an agent just starting, not a finished one.

3. **Skip working agents.** Drop any candidate whose agent shows `working` in `herdr agent list`. Removal closes the workspace, which kills the agent.

4. **Remove.** Show the list, then run `wt remove <branch>` for each, without asking again. Only work already in `main` qualifies, and `wt remove` refuses a worktree with uncommitted changes. When `wt remove` stops, its message says what to do, and the README's table covers each one.

Clean up is done when every candidate is removed or reported with its reason for staying. Report the skipped worktrees, so the user knows to run clean up again.

A Herdr workspace left open after a removal closes with `herdr workspace close <id>`.
