---
name: dispatch
description: Dispatch parallel agents into worktrunk worktrees from the primary checkout, one per issue or pull request, report on them, release ones whose work is on GitHub, and clean up merged ones.
argument-hint: "Issue or PR numbers or URLs to launch, or \"status\", \"release <numbers, branches, or all>\", or \"clean\""
disable-model-invocation: true
---

You are the dispatcher. You send agents out to their own worktrees, know where each one is, and bring the finished ones back. Your job is coordination; each issue's work belongs to its agent.

An **issue row** launches an agent that runs `/implement` on a GitHub issue. A **PR row** launches an agent on a pull request, and that agent waits for instructions. Use one to review someone's pull request with the app running, or to work a second round on your own. Pick the mode from the argument:

- **Launch:** one or more issue or PR numbers or URLs, in any mix.
- **Status:** `status`, or no argument.
- **Release:** `release`, followed by issue or PR numbers, branches, or `all`.
- **Clean:** `clean`, or `clean up`.

GitHub numbers issues and pull requests from one sequence, so a bare number is one or the other, never both. A URL says which by its `/issues/` or `/pull/` path. For a bare number, `gh api repos/{owner}/{repo}/issues/<n> --jq '.pull_request != null'` prints `true` for a pull request.

## Rules for every mode

- **Read `herdr --skill` before your first `herdr` command.** Herdr maintains it, and it covers agent readiness, `blocked` states, and timeouts.
- **Stay in the primary checkout.** Run every command from it, and never `cd` your shell into a worktree ([herdrdev/herdr#4293](https://github.com/herdrdev/herdr/issues/4293)). The global Worktrees rule says how to detect a linked worktree. If you are in one, stop and say so.
- **Follow the runbook.** [`worktrunk/README.md`](https://github.com/zorn/dotfiles/blob/main/worktrunk/README.md) covers `wt herdr`, `wt herdr-resume`, `wt remove`, and what to do when a removal stops.
- **Ask Herdr about agents.** Run `herdr agent list` before you say anything about an agent. It gives each agent's `cwd` and `agent_status`. Your memory of what you started is not evidence of what is running.
- **Refresh before you report a remote branch.** Run `git fetch --prune` before you say whether a branch exists on GitHub. `gh` reads pull requests from GitHub directly.
- **Remove one worktree at a time, with its agent idle.** Release and Clean both remove this way. Just before each removal, check `herdr agent list`, and skip the worktree unless every agent in it is `idle` or `done`: removal closes the workspace and kills the agent, along with any question it is waiting on. Herdr reports `unknown` when it cannot tell, and that does not prove the agent has finished. Run `wt remove --foreground`, so its result is known before you go on. When it refuses, follow its message. If a Herdr workspace stays open after a removal, close it with `herdr workspace close <id>`.

## Launch

1. **Check the issue URLs.** An issue URL must name this repo (`gh repo view --json nameWithOwner`). If one names another repo, stop, name that issue, and launch none of the batch. A PR row's repo is checked in step 3.

2. **Check the primary checkout and its database.** It must be on `main` with a clean tree; if not, stop and say what is wrong. Run `git pull --ff-only`, so every worktree starts from the latest `main`.

   When `.config/wt.toml` calls `hooks/postgres`, each worktree creates its databases in a background step, which fails without telling anyone when Postgres is down. So run `mix ecto.migrations` in the primary checkout first. It connects through the app's own Repo config, so it reaches the database on whatever port the project uses, such as a Docker container's. When it exits non-zero, stop, and ask the user to start the database, usually by starting Docker. A repo without that hook needs no check.

3. **Plan, and wait for "go".** Read each issue with `gh issue view <n> --json title,state`. Give it the agent name `issue-<n>`, and a branch named `zorn/issue-<NNN>-<slug>`, as `/implement`'s Branch step names it. The prefix ties every branch to its issue, so an earlier run is found by the prefix, whatever its slug.

   Show one row per issue with its number, title, agent name, and branch. Mark a row "skip" when its issue is closed, or when it is already dispatched. It is already dispatched when any of these exists:

   - **The planned branch, or any local branch or worktree with the issue's prefix:** `git branch --list 'zorn/issue-<NNN>-*'`, `git worktree list`.
   - **A live agent with the same name:** `herdr agent list`.
   - **An open pull request of yours on a branch with the issue's prefix:** `gh pr list --state open --author @me --json number,headRefName`. Keep `--author @me`, so another person's pull request on a same-named branch is never resumed. One exception: when no worktree exists for that pull request's branch and no live agent has the row's agent name, the issue is **released**, not dispatched. A local branch may still exist, because a plain `wt remove` keeps an unmerged branch. When that branch has commits origin lacks, mark the row "skip" and name the branch. Otherwise mark its row "resume", not "skip", and use the pull request's branch. When the repo has per-worktree databases, say on the row that the resumed worktree gets new ones, so dev data from before the release is gone.

   For a row that is neither skipped nor resumed, check that the planned branch name is unused on GitHub too: `git ls-remote --heads origin <branch>` and `gh pr list --head <branch> --state all`. An issue whose earlier pull request closed or merged gets the same slug again. Reusing it would branch from `main` beside the old remote branch, and `/implement` would find the old pull request and stop. When the name is taken, pick a different slug, for example by adding a word from the issue's title.

   [`scripts/preflight.sh`](scripts/preflight.sh) `<branch> <issue number>` runs every check in this step except the issue's state and the collisions between rows below, and prints a JSON verdict: `clear`, `skip`, `resume`, or `rename`, with its reason and the branch to launch. Run it once per issue row. The rules here say what each verdict means.

   For a PR row, run `scripts/preflight.sh --pr <number or URL>` instead. Its row uses the pull request's branch and the agent name `pr-<number>`. Its verdict is one of three:

   - **`refuse`:** the pull request belongs to another repo, is not open, or comes from a fork. Stop, name it, and launch none of the batch.
   - **`skip`:** its worktree already exists here, its local branch has commits origin lacks, or its agent is live.
   - **`pr`:** launch it. Say on the row whether `mine` is true, because the agent's prompt depends on it.

   To get `/implement`'s review feedback loop on your own pull request, name its issue rather than the pull request.

   The user may edit an issue row's slug in the table, but not its `zorn/issue-<NNN>-` prefix. A "resume" row or a PR row keeps its pull request's branch. `/implement` keeps the branch its worktree was made with, so the name chosen here is final.

   Preflight sees one row at a time, so it cannot see two rows that collide. After every row has its verdict, and again after any edit, mark a row "skip" when its branch or agent name repeats an earlier launchable row's. A pull request given by number and by URL, or an issue beside its own released pull request, both produce such a pair. Wait for "go" before you create anything, then launch only the rows not marked "skip".

4. **Create each worktree.** Run `wt herdr <branch>`. For a "resume" row or a PR row, run `wt herdr-resume <branch>` instead. `wt herdr` passes `--create`, which ignores the remote branch and starts a new one from `main` without the pull request's commits. When preflight reported `fast_forward: true`, first run `git fetch origin <branch>:<branch>`, so `wt herdr-resume` builds on the pull request's commits rather than a stale local branch. Either command's last line is JSON. Read the new pane's ID from `.result.root_pane.pane_id`. If `wt` asks to approve the repo's hooks, stop, and have the user run one `wt herdr` by hand to approve them.

5. **Start each agent** under its agent name:

   ```sh
   herdr agent start issue-271 --kind claude --pane <pane-id>
   herdr agent prompt issue-271 "/implement 271" --wait --until working --until blocked
   ```

   The prompt returns once the agent starts its turn. Each agent pauses when `/implement` needs a decision, so `blocked` is expected, at once or later. A resumed agent finds its open pull request, and `/implement` sends it straight to the review feedback.

   A PR row's prompt names no skill, because the user decides what runs:

   ```sh
   herdr agent prompt pr-123 "This worktree holds PR #123 (<title>) by <author>, on branch <branch>. Wait for instructions." --wait --until working --until blocked
   ```

   When `mine` is false, add "Do not commit or push." to the prompt. The branch belongs to someone else.

Launch is done when `herdr agent list` shows one agent per launched row, each with its `cwd` in its own worktree. Report the Status table.

## Status

Build the table once for each request, and do not poll. Run [`scripts/worktree-status.sh`](scripts/worktree-status.sh), which prints one JSON row per linked worktree, and render each row as a table row:

| Column | Field |
| --- | --- |
| Label | `label` |
| Branch | `branch` |
| Agent | `agents`, named with their status; the agent name identifies the issue or pull request; "none" when empty |
| Pull request | `pr`, or "none" |
| Checks | `checks`, the counts by bucket, or "unavailable" when the lookup failed |
| Releasable | `releasable` |

Status is done when every linked worktree has a row with all six columns filled, or marked "none".

## Release

Release removes a worktree whose work is safe on GitHub, so the user can move on while its pull request waits. The pull request and the remote branch stay. Launch resumes it later. [ADR 0008](https://github.com/zorn/dotfiles/blob/main/docs/adr/0008-release-needs-head-on-github.md) records why Release, unlike Clean, removes unmerged work.

1. **Find the worktrees.** The argument names issues, pull requests, branches, or `all`. An issue's number names the linked worktree whose branch has its `zorn/issue-<NNN>-` prefix in `git worktree list`. When none does, report the issue as not releasable. A pull request's number or URL names its `headRefName`, from `gh pr view <number or URL> --json headRefName,url,isCrossRepository`. Refuse a pull request from another repo or a fork, as Launch does, because its branch name can match an unrelated worktree here. `all` means every linked worktree that passes the check in step 2. Never release the primary checkout.

2. **Check each one.** A worktree is releasable only when all of these hold:

   - **A pull request holds its work:** a pull request for its branch, in any state, has a `headRefOid` that equals the worktree's `HEAD` or descends from it. That proves GitHub has every commit, even when a later push moved the pull request on.
   - **Its tree is clean:** `git -C <path> status --porcelain` prints nothing.
   - **Its agent is idle:** every agent in `herdr agent list` with its `cwd` in the worktree is `idle` or `done`.

   `scripts/worktree-status.sh <branch>` applies all three, and its `releasable` field is `yes` or the first reason that fails. Leave any worktree that fails a check, and report the reason. Never push, commit, or stash to make one pass, and never pass `-f`. Those choices are the user's.

3. **Wait for "go", then remove.** Show the list. When the repo has per-worktree databases, say that releasing drops them. Wait for "go", because `-D` deletes local branches that are not merged. Then, for each one in turn, check that its agent is still idle, as the removal rule says, and close its Herdr workspace with `herdr workspace close <workspace_id>`, which stops the agent. Take the ID from the worktree's Status row, not from a label, because labels can repeat. An idle agent can wake during the wait, for example on review feedback, and commit without pushing, and a clean tree does not stop `wt remove`, so `-D` would delete that commit. With the agent stopped, run step 2's checks again with `scripts/worktree-status.sh <branch>`, and nothing can change between that check and the removal. Skip any worktree that now fails, report why, and say that `herdr worktree open --path <path>` reopens it. Otherwise remove it as the removal rule says, with `wt remove --foreground -D <branch>`.

Release is done when every named worktree is removed or reported with its reason for staying. For each released worktree whose pull request is open, tell the user that `/dispatch <issue>` resumes it, or `/dispatch <PR>` for a PR row.

## Clean

[ADR 0006](https://github.com/zorn/dotfiles/blob/main/docs/adr/0006-dispatch-cleans-up-via-prune.md) records why removal needs both checks below.

1. **Refresh `main`.** The primary checkout must be on `main` with a clean tree; if not, stop and say what is wrong. Run `git pull --ff-only`. worktrunk compares a branch against the local `main` for `same commit as`, so a stale `main` misreads it.

2. **Find the candidates.** A worktree qualifies only when git and GitHub both say it is finished:

   - **Git:** it appears in `wt step prune --dry-run --min-age 0s --format=json` with `kind` `worktree`. That means its work is in `main`.
   - **GitHub:** at least one merged pull request for its branch has a `headRefOid` equal to the worktree's `HEAD`. Use `gh pr list --head <branch> --state merged --json headRefOid`, and compare every result with `git -C <path> rev-parse HEAD`.

   A worktree with no commits also appears in prune, as `same commit as`, or as `ancestor of` once `main` moves on. Its agent has likely just started. Only a merged pull request at the worktree's own `HEAD` tells a finished worktree from a new one, because a follow-up branch can reuse a merged branch's name. Leave any worktree that fails either check, including one whose pull request lookup fails, and report it with its reason.

3. **Remove.** Show the list, then remove each candidate without asking, as the removal rule says, with `wt remove --foreground <branch>`. Its work is already in `main`, and `wt remove` refuses uncommitted changes.

Clean is done when every candidate is removed or reported with its reason for staying. Report the skipped worktrees, so the user knows to run `/dispatch clean` again.
