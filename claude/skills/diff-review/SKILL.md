---
name: diff-review
description: Review the diff since a fixed point along five axes — Standards (does it follow this repo's documented standards?), Spec (does it do what the originating issue asked?), Prose (are the comments and docs grammatical, and no longer than they need to be?), Tests (whenever the diff touches code — do the tests flake, do they observe the new behavior, do they cost more than they need?), and Database (only when the diff touches the DB — migration safety, transaction consistency, query performance). Use when the user wants changes reviewed, or asks to "review since X".
license: MIT
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: code-review
  note: renamed from code-review — the original name shadowed the native `/code-review ultra`
  forked-on: "2026-08-03"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
---

Multi-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?
- **Prose** — are the comments and docs grammatical, and does every function doc and inline comment earn its length?
- **Tests** — whenever the diff touches code: do the tests flake, do they observe the new behavior, and do they cost more than the behavior needs?
- **Database** — only when the diff touches the DB: are migrations safe to deploy, are dependent writes transactional, and do queries scale?

The first three always run. Tests runs whenever the diff touches code, and Database only when the diff shows database signals, since most changes don't touch the DB. The axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here — not inside the parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages or branch name (`#123`, `Closes #45`, a `zorn/issue-123-…` branch) — fetch with `gh issue view <n> --comments`.
2. A path the user passed as an argument.
3. A PRD/spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Anything in the repo that documents how code should be written, such as `CODING_STANDARDS.md` or `CONTRIBUTING.md`.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below — a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgment call.** Each smell is a labeled heuristic ("possible Feature Envy"), never a hard violation — and, like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep traveling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Identify the prose standard

Anything the repo documents about how prose should read — a `STYLE.md`, a writing section in `CONTRIBUTING.md`. On top of that, the Prose axis always carries the **prose baseline** below, so it applies even when a repo documents nothing. The same two rules bind it as the smell baseline: a documented repo standard overrides, and every call is a judgment ("possible verbosity"), never a hard violation.

The baseline has two concerns:

- **Register and grammar** — across every comment, doc comment, and Markdown doc the diff touches: flag grammar errors, awkward phrasing, and British spellings (behaviour → behavior). Leave identifiers and quoted material alone; changing those breaks a reference rather than tidying it.
- **Length is the default suspect** — challenge every function doc and inline comment: can it be shorter, or deleted? A comment earns its bytes only by carrying the *why*; one that restates what the code plainly does is noise, and the fix is to delete it, not trim it. Split multi-clause comment sentences in the spirit of ASD-STE100 — one idea per sentence, active voice. This concern is for code-level copy, so do not shorten a Markdown doc that is deliberately thorough.

Boundary with Standards: a murky function *name* is Standards (Mysterious Name); a verbose *sentence* in its doc is Prose.

### 5. Identify the test standard

Anything the repo documents about how tests should be written — a testing section in `CONTRIBUTING.md`, a `test/README.md`. On top of that, the Tests axis always carries the **tests baseline** below, so it applies even when a repo documents nothing. The same two rules bind it as the smell baseline: a documented repo standard overrides, and every call is a judgment ("possible flake"), never a hard violation.

The axis runs whenever the diff touches code. A diff that is only docs, config, CI, or skill Markdown skips it; note the skip in the final report. Gate on code, not on test files: a change that adds behavior and no tests is exactly the diff this axis exists to catch, and a gate on `test/` would never see it.

The sub-agent judges from the diff alone. Flake is a pattern in the test source, and coverage is a map from each new behavior to the test that exercises it — so the project never has to boot, and the loudest coverage finding, new behavior with no test at all, is visible in the diff. A line-coverage report would say which lines ran, not which behaviors were asserted.

The baseline is ExUnit-first, since that is the stack these reviews target; the concern names — sleep-based sync, wall-clock dependence, untested error path, wrong seam — transfer off ExUnit. It has three concerns, and each item reads *what it is* → *how to fix*:

**Flake** — a result that depends on timing, order, or state the test does not control:

- **Sleep-based synchronization** — `Process.sleep` waiting for asynchronous work; passes on a fast machine, fails under CI load. → `assert_receive` on a message, a bounded poll, or make the work synchronous under test.
- **Wall-clock dependence** — `DateTime.utc_now()` compared against a literal, or a test that behaves differently at midnight or month end. → inject the clock, or derive the expectation from the same `now` the code uses.
- **Ordering assumption on unordered results** — asserting a list from a query with no `order_by`, or from a map. → add `order_by`, or sort before asserting.
- **Shared mutable state** — a named process, ETS table, or application env mutated without cleanup; a fixture with a fixed unique field. → per-test unique values, `start_supervised`, `on_exit` cleanup.
- **Unseeded randomness** the assertion depends on. → fixed values, or a property test where the range is the point.
- **`async: true` on a module that mutates a shared resource** — flakes only when scheduled beside a particular sibling. → remove the shared mutation, or `async: false` with a comment saying what is shared.

**Coverage** — new behavior the tests do not observe:

- **Untested public function** — new or changed, with no test that calls it. → add a test at the highest seam the project already has.
- **Untested branch or error path** — an `{:error, _}` clause, a `with` `else`, a guard — with no test that reaches it. → one `failure:` test per path.
- **Assertion-free test** — runs the new code but asserts nothing about its effect: a bare `refute is_nil`, or "does not raise". → assert the observable outcome.
- **Tautological assertion** — the expected value is computed the way the code computes it. → an independent literal from the spec or a worked example.
- **Deleted or weakened test** with no replacement in the diff. → restore it, or say in the PR why the behavior left.

**Performance** — a test that costs more than the behavior needs:

- **`async: false`, or `async` absent, with no comment saying what shared thing prevents it.** → `async: true`, or the comment. This is the headline finding; the rest are secondary.
- **Heavier seam than the behavior needs** — a `DataCase` test for a pure function, a `ConnCase` test for context logic. → drop to the cheapest seam that can observe the behavior.
- **Real network, filesystem, or sleep in the test path.** → a fake at the seam, or a fixture file.
- **Heavy setup repeated per test** that a fixture could share, or a large fixture where a small one would do (a hundred rows to test one). → `test/support/fixtures/`, sized to the assertion.

You are done with this step once you have decided the axis runs or is skipped.

### 6. Decide whether the Database axis runs

Scan the diff for **database signals** — migration files, `schema do`, `Repo.`/query calls, raw SQL. If none appear, the Database axis is skipped; note this in the final report and move on. If any appear, the Database sub-agent runs in step 7, and its baseline comes from `reference/database-baseline.md` — read that file and paste it into the sub-agent prompt, since the sub-agent has no other access to it.

The baseline is not inline here, unlike the smell, prose, and tests baselines, because it loads only on the reviews that touch the DB. Its migration-safety concern defers to project tooling: the baseline file carries the deferral rule, so the sub-agent decides it — you only gate on whether the diff touches the DB at all.

You are done with this step once you have decided the axis runs or is skipped, and — if it runs — have the baseline text in hand to paste.

### 7. Spawn the sub-agents in parallel

Send a single message with one `Agent` tool call per axis that runs — Standards and Prose always, Spec unless step 2 found no spec, Tests unless step 5 found no code changes, Database when step 6 found database signals. Use the `general-purpose` subagent for all of them.

**Standards sub-agent prompt** — include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report a flat list of findings, nothing else — no preamble, no summary. One finding per entry, each on its own line as `<file>:<line> | <claim in one line> | <hard|judgment> | <evidence, at most two lines>`. Cover (a) every place the diff violates a documented standard, citing the standard file and rule in the evidence; and (b) any baseline smell, named. A documented repo standard overrides the baseline, and baseline smells are always judgment calls where documented-standard breaches can be hard. Skip anything tooling enforces. Return nothing if you find nothing."

**Spec sub-agent prompt** — include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report a flat list of findings, nothing else — no preamble, no summary. One finding per entry, each on its own line as `<file>:<line or -> | <claim in one line> | <missing|creep|wrong> | <the spec line it turns on>`. Cover (a) requirements the spec asked for that are missing or partial; (b) behavior in the diff that was not asked for; (c) requirements that look implemented but wrong. Quote the spec line for every finding. Return nothing if you find nothing."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

**Prose sub-agent prompt** — include:

- The full diff command and commit list.
- The list of prose-standard files you found in step 4, **plus the prose baseline from step 4** pasted in full — the sub-agent has no other access to it.
- The brief: "Report a flat list of findings, nothing else — no preamble, no summary. One finding per entry, each on its own line as `<file>:<line> | <claim in one line> | <grammar|length|noise> | <the comment or doc text it turns on, at most two lines>`. Cover (a) grammar, awkward phrasing, and British spelling in any comment or doc the diff touches; (b) any function doc or inline comment longer than its content justifies — challenge length aggressively, since the tooling that wrote this copy runs verbose; (c) comments that only restate the code, tagged `noise` for deletion. Leave identifiers and quoted text alone. Exempt deliberately thorough Markdown docs from the length and noise checks, but still flag their grammar. Return nothing if you find nothing."

**Tests sub-agent prompt** (only when step 5 found code changes) — include:

- The full diff command and commit list.
- The list of test-standard files you found in step 5, **plus the tests baseline from step 5** pasted in full — the sub-agent has no other access to it.
- The brief: "Report a flat list of findings, nothing else — no preamble, no summary. One finding per entry, each on its own line as `<file>:<line or -> | <claim in one line> | <flake|coverage|performance> | <the hunk, or the untested function, at most two lines>`. Judge from the diff: flake by pattern in the test source, coverage by mapping each new or changed behavior to the test that exercises it. Apply each baseline concern where its signal appears. Every finding is a judgment call, and a documented repo standard overrides the baseline. Return nothing if you find nothing."

**Database sub-agent prompt** (only when step 6 found database signals) — include:

- The full diff command and commit list.
- The **database baseline from step 6** pasted in full — the sub-agent has no other access to it.
- The brief: "Report a flat list of findings, nothing else — no preamble, no summary. One finding per entry, each on its own line as `<file>:<line or -> | <claim in one line> | <migration|transaction|performance> | <the hunk it turns on, at most two lines>`. Apply each baseline concern where its signal appears in the diff. Every finding is a judgment call, and a documented repo standard overrides the baseline. When the baseline's migration-safety deferral applies, skip that concern and report the single line `- | migration safety enforced by tooling — skipped | migration | -`. Return nothing if you find nothing."

### 8. Present the findings as a decision list

The sub-agents return raw finding lines, not a report. Never pass those through and never expand them back into narrative — a wall of prose findings buries the only thing the user actually has to do, which is decide what gets fixed.

Turn each line into a numbered item answerable at a glance, following the presentation contract in the global instructions. Keep the axes under separate `## 📏 Standards`, `## 🎯 Spec`, `## ✍️ Prose`, `## 🧪 Tests`, and `## 🛢️ Database` headings, leaving out the heading of any axis that skipped, and do not merge or rerank across them (see _Why separate the axes_), but number continuously so a reply can say "3 and 7" without naming an axis.

Each item leads with a colored dot for the recommendation, so the eye lands on what needs a decision and skims the rest. The three recommendations, each an action addressed to the user:

- 🔴 **Fix** — change it.
- ⚪ **Keep** — leave it as-is; a finding you disagree with.
- 🟡 **Weigh** — a genuine coin flip you hand to the user; state both sides.

Each item is exactly this shape:

```
<dot> N. **<the claim in one line>** — `lib/my_app/tracking.ex:42`
   → <Fix | Keep | Weigh> — <one-line reason>
   <two lines of evidence at most: the hunk, or the spec line it misses>
```

The contract covers the numbering, the recommendation, and silence-as-agreement. Three things it does not cover, specific to a review:

- **🟡 Weigh is not the default.** Reaching for it on everything hands the review back rather than doing it; use it only for a genuine coin flip. Unanswered, a Weigh defaults to Keep — silence leaves the code as-is, the reversible choice.
- **List the findings you would ⚪ Keep.** Dropping one you disagree with silently hides that the axis looked at all; Keep with a reason is the honest form.
- **Then act on exactly what came back.** A reply of "2 keep, 5 let's talk" means fixing the rest without re-asking.

End with one line per axis: how many findings, and how many are recommended 🔴 Fix. An axis that did not run gets a line here too, in place of the count — `Spec — skipped, no spec`, `Tests — skipped, no code changes`, or `Database — skipped, no database changes` — so a skip is visible without an empty heading above the fold. No cross-axis winner — that is the reranking the separation exists to prevent. Close the footer with `Correctness — not an axis here; run /code-review`, so the reader is told where that check lives rather than left to assume it ran.

## Why separate the axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**
- Code that is correct and on-spec but buries its intent in verbose or ungrammatical comments → **Standards and Spec pass, Prose fail.**
- Code that is clean, on-spec, and clearly written but ships with a test that sleeps its way to green → **the other three pass, Tests fails.**
- Code that is clean, on-spec, clearly written, and honestly tested but N+1s every request under load → **the other four pass, Database fails.**

Reporting them separately stops one axis from masking another.
