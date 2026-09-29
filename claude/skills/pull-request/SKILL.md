---
name: pull-request
description: Tell the story of a change in its pull request — the problem, the fix, and what deserves the reviewer's attention — then open it. Use when a change is ready for a PR, when an existing PR body needs rewriting, and when another skill needs a PR opened.
license: MIT
metadata:
  origin: https://github.com/zorn/dotfiles/issues/28
  research: docs/research/pr-writing-skill.md
  editor: Mike Zornek
---

# Pull Request

A PR body has one reader: someone without your context, who will skim anything long. **Tell the story** — what was wrong, what you did about it, and what they should push back on — in about 250 words.

## 1. Read the change and name its flavor

`git diff main...HEAD` for the change, and `gh issue view <n> --comments` for the issue behind it — decisions get made in comment threads, and a body-only read misses them.

Three flavors, told apart by what the reviewer cannot get from the diff alone:

- **Behavior change** — the software now does something different. The reviewer needs to *see* it behave, so this is the flavor that carries a demo path and screenshots.
- **Artifact** — the change commits a document: research, an ADR, a spec, a prototype. The artifact *is* the diff, so reading it is the review. The body gives the headline of each finding and the decision it changes, not the findings themselves.
- **Mechanical** — dependency bumps, generated output, sweeping renames. The reviewer needs the verification evidence and whatever you did by hand against the pattern.

Name the flavor before drafting. It decides which moves below apply.

Then, when the repo has a `render.yaml`, **decide whether the change deploys**. Render deploys every merge to `main` unless the merge commit message carries `[skip render]`. Skip only when no changed file reaches the running app — CI workflows, dev tooling, agent config, docs, and tests. When any file is in doubt, let it deploy: a needless deploy costs minutes, but a wrongly skipped one leaves production silently stale.

## 2. Tell the story

Four moves, in order. Name each heading after its own content — `Three findings that change the shape of #147`, `What changes in a browser` — rather than reaching for `Summary` or `What changed`.

1. **Open with what this is and where it sits.** One or two sentences under no heading: the change, and the arc it belongs to. Link the issue or PR it follows from, and say what it leaves for later.
2. **Disclose the risk.** What did *not* change, and what the suite says — "No production behavior changes here; the suite is unchanged at 327 passing." One sentence, and the one a reviewer leans on to decide how hard to look. A skipped deploy goes here too — "Skips the Render deploy: nothing here reaches the running app" — so the reviewer can overturn it.
3. **Carry the substance under content-named headings.** Lead each with a claim rather than a topic. Cite `path:line` for anything the reviewer would otherwise go hunting for, and link it when the file lives in this repo.
4. **End with `Worth a reviewer's attention`.** Bold-led bullets, one per judgment call the reviewer might overturn — a skipped lint rule, a deviation from what the issue specified, a trade-off you picked a side on. This is the section that earns the review; write it even when the list has one item.

Alternatives you considered belong here as a headline and a link to where they were argued. The reader who wants the full case follows the link; everyone else needs the sentence.

## 3. Show it working

For a behavior change, give the reviewer both a way to see it and a picture of it.

**The demo path** costs nothing and goes stale slower than an image. Take the port from the project's config and the route from the router's own generated list (`mix phx.routes` in a Phoenix app) rather than reading the router by eye, then say what to click. Where the repo already documents how to inspect a running app, link that document rather than restating it.

**The screenshot is the part reviewers actually look at, so a visible change gets one.** Capture the new state with browser automation against the running app, and reference it in the body by its absolute path. `gh` resolves a relative path from the directory it runs in, not the body file's, so a relative reference breaks as soon as the two differ. Step 4 uploads it with `gh --attach`, which rewrites the reference in place and keeps its position and alt text. The flag needs `gh` 2.99.0 or later, so check `gh --version` before capturing anything. [reference/images.md](reference/images.md) covers what the upload does, the two forms that silently fail, and the theme-aware light/dark pair that `--attach` cannot serve.

Include a **before** shot whenever it is cheap — the base ref is already built, or the change is confined to markup and styles. When capturing it would mean a cold rebuild of the base ref, describe the old state in a sentence and show the new one alone. Seed both captures from the same fixtures, so the difference in the image is the change and nothing else. If the app renders differently across clients, say which one you captured.

Stack the pair vertically rather than side by side — two half-width images make the difference between them harder to see, which is the one thing the pair exists to show.

```markdown
**Before**

![Settings panel, before](<scratch>/before.png)

**After**

![Settings panel, after](<scratch>/after.png)
```

**A screen recording** earns its place when the change is an interaction rather than a state — a drag, a transition, a multi-step flow. Save it as mp4, mov, or webm and put the bare reference on a paragraph of its own, `![](<scratch>/demo.mp4)`, which GitHub renders as an inline player. Video takes no alt text, so say what it shows in the sentence above it. Size limits are in [reference/images.md](reference/images.md).

**A runtime transcript** earns its place when the change's value is a return shape or an edge case that reads better as a session than as a test name. Compose it from `mix run -e` output against seeded fixtures. Piping into `iex -S mix` prints the prompt and the result with the input missing — `iex(1)> 2` for an input of `1 + 1` — so the transcript it produces misrepresents what was typed.

## 4. Check, then open

Mechanical checks, no judgment in any of them:

- **Title** matches `^(fix|feat|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?: [^A-Z].*$`, which is the composite of the `types` list and the `subjectPattern` that the repo's Lint PR workflow passes to `amannn/action-semantic-pull-request`. Read that workflow rather than trusting the regex if a title is rejected.
- **Title ends in `[skip render]` when step 1 skipped the deploy.** A suffix, because the pattern needs the type first.
- **The commit subject too, where the repo squashes from the commit.** `gh api repos/<owner>/<repo> --jq .squash_merge_commit_title` returns `COMMIT_OR_PR_TITLE` in some repos, and there a single-commit PR lands on `main` under the *commit* subject while the lint only ever read the title. That subject needs the `[skip render]` suffix too, or Render never sees it.
- **Issue link present** — `Closes #<n>` on the first line when merging resolves the issue, `Refs #<n>` when it does not. Repeat the keyword per issue (`Closes #10, closes #12`); one keyword does not distribute across a comma list. Closing keywords fire only when the PR targets the default branch.
- **Paragraphs are single unwrapped lines.**
- **Every local image or video path in the body is absolute and gets an `--attach` for the same file.** An unmatched reference ships as a broken image, and `gh` still exits 0.

Open it with a body file rather than an inline `--body`, which loses backticks in fish, silently. Add one `--attach` per referenced file; rewriting an existing PR's body takes the same flags on `gh pr edit <n>`:

```
gh pr create --title "<title>" --body-file <path> --attach <scratch>/before.png --attach <scratch>/after.png
```

A failed attachment still creates the PR and prints its URL, but `gh` exits non-zero. Recover with `gh pr edit <n> --body-file <path>` and every `--attach` again, since the original body file still holds the local paths.

Then confirm the link took: `gh pr view --json closingIssuesReferences` comes back non-empty whenever you used a closing keyword.

Opening the PR triggers an automatic Copilot review here, so comments arrive within a minute or two and the work is not done when the PR exists. `implement` step 6 owns that loop and its script; when this skill ran outside `implement`, say the review is coming and pick up the same loop rather than reporting the PR as finished.

## Wayfinder artifact PRs

A PR cannot be a child of a wayfinder map — sub-issues and dependencies are issue-scoped, and `gh pr edit` carries no `--parent`. So an artifact PR references rather than joins. The body names its ticket and its map as links wrapping their titles, per wayfinder's own "Refer by name" rule, and uses `Refs #<n>`, because the ticket resolves through wayfinder's resolution flow rather than on merge.
