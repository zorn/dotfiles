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

Off updated `main`:

```
git checkout main && git pull --ff-only
git checkout -b zorn/issue-<NNN>-<short-slug>
```

The `zorn/issue-<NNN>-` prefix is required — it is what ties the branch back to its issue, both for `code-review`'s spec axis and for anyone reading a branch list. The slug is a few kebab-case words, not the whole title.

Work with no issue behind it gets `zorn/<short-slug>`, and is the exception rather than the shape to aim for.

## 3. Build with TDD

Hand off to `tdd` and stay inside its loop. Its rules bind here: seams confirmed with the user before any test is written, one vertical slice at a time, red before green.

Run the project's typecheck and the test file under change as you go; run the full suite once before moving on.

## 4. Review before the PR exists

Run `code-review` against `main`. Reviewing here rather than after pushing is the whole point of the ordering — the diff is still cheap to change.

Apply what it recommends. Findings arrive as a numbered decision list, so the user's reply governs: anything they did not speak to proceeds as recommended.

`/code-review ultra` is the deeper multi-agent pass and is **user-triggered only** — this skill cannot launch it. When a change is large or risky enough to want it, say so and let the user type it, rather than proceeding as though the pass happened.

## 5. Push and open the PR

Push the branch and open a real PR, not a draft. Title it as a conventional commit whose subject does not start with a capital — squash-merging makes the title the commit message. The body says what changed and why, and closes the issue (`Closes #<NNN>`).

## 6. Work the Copilot feedback

Opening the PR triggers an automatic Copilot review. Watch for it:

```
scripts/watch-pr-feedback.sh <pr-number>
```

It emits one line per new review comment, review summary, or failed check, and remembers what it has already reported so nothing is announced twice.

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

Merging is the user's call. Do not merge.
