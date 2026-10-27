---
name: dispatch
description: Dispatch parallel agents into worktrunk worktrees from the primary checkout, report on them, and clean up merged ones.
argument-hint: "Issue numbers or URLs to launch, or \"status\", or \"clean\""
disable-model-invocation: true
---

You are the dispatcher. You send agents out to their own worktrees, know where each one is, and bring the finished ones back. Your work is coordination; each issue's work belongs to its agent.

Pick the mode from the argument: one or more issue numbers or GitHub issue URLs, in any mix, mean **Launch**; `status` means **Status**; `clean`, or `clean up`, means **Clean**. With no argument, run Status.

## Rules for every mode

- **Read `herdr --skill` before your first `herdr` command.** Herdr maintains it, and it covers agent readiness, `blocked` states, and timeouts.
- **Stay in the primary checkout.** Run every command from it, and never `cd` your shell into a worktree ([herdrdev/herdr#4293](https://github.com/herdrdev/herdr/issues/4293)). The global Worktrees rule says how to detect a linked worktree. If you are in one, stop and say so.
- **Follow the runbook.** [`worktrunk/README.md`](https://github.com/zorn/dotfiles/blob/main/worktrunk/README.md) covers `wt herdr`, `wt remove`, and what to do when a removal stops.
- **Ask Herdr about agents.** Run `herdr agent list` before you say anything about an agent. It gives each agent's `cwd` and `agent_status`. Your memory of what you started is not evidence of what is running.
- **Refresh before you report a remote branch.** Run `git fetch --prune` before you say whether a branch exists on GitHub. `gh` reads pull requests from GitHub directly.

## Launch

1. **Check the URLs.** A URL must name this repo (`gh repo view --json nameWithOwner`). If one names another repo, stop, name that issue, and launch none of the batch.

2. **Check the primary checkout.** It must be on `main` with a clean tree; if not, stop and say what is wrong. Run `git pull --ff-only`, so every worktree starts from the latest `main`.

3. **Plan, and wait for "go".** Read each issue with `gh issue view <n> --json title,state`. Name its branch `zorn/issue-<NNN>-<slug>`, as `/implement`'s Branch step does. Show one row per issue with its number, title, and branch. Mark an issue "skip" when it is closed, or when a branch or worktree for it already exists (`git branch --list 'zorn/issue-<NNN>-*'`, `git worktree list`). Wait for "go" before you create anything, then launch only the rows not marked "skip".

4. **Create each worktree.** Run `wt herdr <branch>`. Its last line is JSON. Read the new pane's ID from `.result.root_pane.pane_id`. If `wt` asks to approve the repo's hooks, stop, and have the user run one `wt herdr` by hand to approve them.

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
| Pull request | `gh pr list --head <branch> --state all --json number,state,createdAt`; the newest one |
| Checks | `gh pr checks <number>`, when a pull request exists |

Status is done when every linked worktree has a row with all five columns filled, or marked "none".

## Clean

1. **Refresh `main`.** The primary checkout must be on `main` with a clean tree; if not, stop and say what is wrong. Run `git pull --ff-only`. worktrunk compares a branch against the local `main` for `same commit as`, so a stale `main` misreads it.

2. **Find the candidates.** A worktree qualifies only when git and GitHub both say it is finished:

   - **Git:** it appears in `wt step prune --dry-run --min-age 0s --format=json` with `kind` `worktree`. That means its work is in `main`.
   - **GitHub:** a pull request for its branch is `MERGED`, and that pull request's `headRefOid` equals the worktree's `HEAD`. Use `gh pr list --head <branch> --state merged --json headRefOid` and `git -C <path> rev-parse HEAD`.

   A worktree with no commits also appears in prune, as `same commit as`, or as `ancestor of` once `main` moves on. Its agent is just starting. Only a merged pull request at the worktree's own `HEAD` tells it apart, because a follow-up branch can reuse a merged branch's name. Leave any worktree that fails either check, including one whose pull request lookup fails, and report it with its reason.

3. **Remove.** Show the list, then remove each candidate without asking: its work is already in `main`, and `wt remove` refuses uncommitted changes. For each one in turn, check `herdr agent list` first. Skip it when its agent is `working` or `blocked`, because removal closes the workspace and kills the agent, along with any question it is waiting on. Otherwise run `wt remove --foreground <branch>`, so its result is known before you go on. When `wt remove` refuses, follow its message. If a Herdr workspace stays open after a removal, close it with `herdr workspace close <id>`.

Clean is done when every candidate is removed or reported with its reason for staying. Report the skipped worktrees, so the user knows to run `/dispatch clean` again.
