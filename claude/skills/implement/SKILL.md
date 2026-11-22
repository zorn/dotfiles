---
name: implement
description: Build an issue end to end — branch, TDD, review, PR, and the Copilot feedback loop.
argument-hint: "Issue number, or a spec/ticket path"
license: MIT
disable-model-invocation: true
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: implement
  forked-on: "2026-08-03"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
  note: substantially rewritten — upstream was five lines with no branch, PR, or review-response steps
---

Take a piece of work from an issue to a pull request with its review threads answered. The steps are ordered and each has a bar to clear; do not run ahead of them.

## 1. Read the work

The argument is an issue number, or a path to a spec or ticket. For an issue, read the body **and every comment** — `gh issue view <n> --comments`. Decisions get made in comment threads, and a body-only read misses them.

If the work is not settled enough to build, stop and say so. `/grill` settles it; `/to-tickets` splits it when it is settled but too big for one branch. Neither is something to push through.

## 2. Branch

In a linked worktree, the global Worktrees rule governs this step. Check the branch's PR first:

- **The PR has merged or closed:** stop, and hand over `wt herdr` as that rule says.
- **The branch names a different issue from the one you were given:** stop and hand over `wt herdr` the same way. Each issue gets its own worktree.
- **No PR yet:** work on the current branch, and skip the commands below.
- **The PR for this issue is still open:** work on the current branch. When the tree is clean and `HEAD` equals the PR's head commit (`gh pr view --json headRefOid`), the build is done and the worktree is back for review, so go straight to step 6. Otherwise local work has not reached the PR yet, so continue from step 3, and it goes through review and push like any other round.

In the primary checkout, branch off updated `main`:

```
git checkout main && git pull --ff-only
git checkout -b zorn/issue-<NNN>-<short-slug>
```

The `zorn/issue-<NNN>-` prefix is required — it is what ties the branch back to its issue, both for `diff-review`'s spec axis and for anyone reading a branch list. The slug is a few kebab-case words, not the whole title.

Work with no issue behind it gets `zorn/<short-slug>`, and is the exception rather than the shape to aim for.

## 3. Build with TDD

Hand off to `tdd` and stay inside its loop. Its rules bind here: seams confirmed with the user before any test is written, one vertical slice at a time, red before green.

Run the project's typecheck and the test file under change as you go; run the full suite once before moving on.

## 4. Review before the PR exists

Run `diff-review` against `main`. Reviewing here rather than after pushing is the whole point of the ordering — the diff is still cheap to change.

Apply what it recommends. Findings arrive as a numbered decision list, and that skill's contract governs how the user's reply is read.

Once those findings are settled, invoke the `code-review` skill yourself at the `high` level, or at the level the user names. It hunts correctness bugs, which `diff-review` targets only for races between users. Running it here means its fixes land before Copilot and the reviewer see the diff. When the change is large or risky, suggest that the user run `/code-review ultra`. Apply its findings the same way as `diff-review`'s.

Then list the pages the change touches, so the user can check them by hand without asking. Give each one as a full URL on this worktree's dev server port, with the role to sign in as and what to look for. When the change shows on no page, say so in one line.

Move to step 5 only after the `code-review` findings are settled, or the user says to skip the pass, and the page list is given.

## 5. Push and open the PR

Push the branch, then hand off to `pull-request`. It owns the body and the opening — the story, the flavor, the reviewer's evidence, and the checks that run before `gh pr create`. Pass it the issue number so it can read the work behind the change.

Two things it needs from here that it cannot see on its own: open a real PR rather than a draft, and carry over the findings from step 4 that you declined and a reviewer might reasonably overturn — a trade-off you picked a side on, a risk you are accepting, a deviation from the issue. Leave out false positives, nits, and out-of-scope suggestions; the PR body is for a reviewer who has not seen the work, not a log of the review.

## 6. Work the Copilot feedback

Opening the PR triggers an automatic Copilot review. Watch for it — **as a `Monitor` command, never as a blocking foreground call**:

```
Monitor(
  description: "PR feedback and checks on #<pr-number>",
  command: "WATCH_SETTLE=1 ~/.claude/skills/implement/scripts/watch-pr-feedback.sh <pr-number>",
)
```

The script polls until told to stop, so running it in the foreground buys nothing and burns the whole tool timeout while showing you nothing. `Monitor` turns each new item into a notification that arrives while you keep working; `WATCH_SETTLE=1` lets the watch end itself once checks are done and the review has landed, rather than sitting armed until timeout.

It emits one line per new inline review comment, review summary, or PR comment, and one per check that fails or is canceled — so a crashed job does not read as silence. It remembers what it has already reported in a state file, `${TMPDIR:-/tmp}/pr-feedback-seen-<owner>-<repo>-<pr-number>.txt`, so nothing is announced twice. That file outlives the session and the worktree. When the PR predates this session, delete the file before you start the watcher, so it reports every comment again, and skip any thread that already has your reply. Progress goes to stderr, so `Read` the monitor's output file to see elapsed time and the check rollup without waiting for an event.

**Evaluate every comment before acting on it. Copilot is a reviewer, not an authority** — it does not know this repo's conventions and has been confidently wrong about them. Declining a comment is a legitimate outcome; ignoring one is not.

Reply in each thread:

```
gh api repos/<owner>/<repo>/pulls/<pr>/comments/<comment-id>/replies -f body="$(cat reply.md)"
```

Write the body to a file and pass it with `$(cat …)` — an inline body loses backticks in fish, silently.

A reply is a sentence or two saying what you did or why you did not. "Fixed in `<sha>`" is complete; so is a declined finding with its reason. An unanswered thread reads as one you missed.

## 7. Done

The work is done when every review thread has a reply, checks are green, and the branch is pushed.

Report which comments you applied and which you declined. A summary listing only the fixes hides the judgment calls, and those are the ones worth the user's attention.

Say what the change needs beyond merging — a re-link, a reload, a restart, or a doc that now describes it wrongly — or that it needs nothing. The user should not have to ask.

Merging is the user's call. Do not merge.
