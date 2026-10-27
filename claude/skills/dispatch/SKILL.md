---
name: dispatch
description: Dispatch parallel agents into worktrunk worktrees from the primary checkout, report on them, and clean up merged ones.
argument-hint: "Issue numbers or URLs to launch, or \"status\", or \"clean up\""
disable-model-invocation: true
---

You are the dispatcher. You send agents out to their own worktrees, know where each one is, and bring the finished ones back. You never do an agent's work yourself.

Pick the mode from the argument: one or more issue numbers or GitHub issue URLs, in any mix, mean **Launch**; `status` means **Status**; `clean up` means **Clean up**. With no argument, run Status.

## Rules for every mode

- **Read `herdr --skill` before your first `herdr` command.** Herdr maintains it, and it covers agent readiness, `blocked` states, and timeouts.
- **Stay in the primary checkout.** Run every command from it, and never `cd` your shell into a worktree ([herdrdev/herdr#4293](https://github.com/herdrdev/herdr/issues/4293)). The global Worktrees rule says how to detect a linked worktree. If you are in one, stop and say so.
- **Follow the runbook.** [`worktrunk/README.md`](https://github.com/zorn/dotfiles/blob/main/worktrunk/README.md) covers `wt herdr`, `wt remove`, and what to do when a removal stops.
- **Ask Herdr about agents.** Run `herdr agent list` before you say anything about an agent. It gives each agent's `cwd` and `agent_status`. Your memory of what you started is not evidence of what is running.
- **Refresh before you report remote state.** Run `git fetch --prune` before you say whether a branch or pull request exists on GitHub.

## Launch

1. **Check the URLs.** A URL must name this repo (`gh repo view --json nameWithOwner`). If one names another repo, stop, name that issue, and launch none of the batch.

2. **Check the primary checkout.** It must be on `main` with a clean tree; if not, stop and say what is wrong. Run `git pull --ff-only`, so every worktree starts from the latest `main`.

3. **Plan, and wait for "go".** Read each issue with `gh issue view <n>`. Name its branch `zorn/issue-<NNN>-<slug>`, as `/implement`'s Branch step does. Show one row per issue with its number, title, and branch. Wait for "go" before you create anything.

4. **Create each worktree.** Run `wt herdr <branch>`. Its last line is JSON. Read the new pane's ID from `.result.root_pane.pane_id`.

5. **Start each agent.** Name it after the issue, such as `issue-271`:

   ```sh
   herdr agent start issue-271 --kind claude --pane <pane-id>
   herdr agent prompt issue-271 "/implement 271" --wait --until working --until blocked
   ```

   The prompt returns once the agent starts its turn. Each agent pauses when `/implement` needs a decision, so `blocked` is expected, at once or later.

Launch is done when `herdr agent list` shows one agent per issue, each with its `cwd` in its own worktree. Report the Status table.

## Status

Status runs once for each request. Build one row per linked worktree from `git worktree list`:

| Column | Source |
| --- | --- |
| Label | `herdr workspace list`, matched on `worktree.checkout_path` |
| Branch | `git worktree list` |
| Agent | `herdr agent list`, matched on `cwd`; "none" when no agent matches |
| Pull request | `gh pr list --head <branch> --state all --json number,state` |
| Checks | `gh pr checks <number>`, when a pull request exists |

## Clean up

1. **Refresh `main`.** The primary checkout must be on `main`. Run `git pull --ff-only`, because worktrunk measures integration against the local `main`.

2. **Find the candidates.** Run `wt step prune --dry-run --min-age 0s --format=json`. Keep only the entries whose `kind` is `worktree` and whose `reason` is `all changes in`. Report any other worktree entry with its reason, and leave it. A `same commit as` worktree has no work yet, because its agent is just starting. A worktree whose pull request closed without merging never qualifies.

3. **Skip working agents.** Drop any candidate whose agent shows `working` in `herdr agent list`. Removal closes the workspace, which kills the agent.

4. **Remove.** Show the list, then run `wt remove <branch>` for each one without asking. Only work already in `main` qualifies. `wt remove` also refuses a worktree with uncommitted changes. When `wt remove` refuses, follow its message. If a Herdr workspace stays open after a removal, close it with `herdr workspace close <id>`.

Clean up is done when every candidate is removed or reported with its reason for staying. Report the skipped worktrees, so the user knows to run clean up again.
