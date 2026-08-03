---
name: diff-review
description: Review the diff since a fixed point along two axes — Standards (does it follow this repo's documented standards?) and Spec (does it do what the originating issue asked?). Use when the user wants changes reviewed, or asks to "review since X".
license: MIT
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: code-review
  note: renamed from code-review — the original name shadowed the native `/code-review ultra`
  forked-on: "2026-08-03"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards** — does the code conform to this repo's documented coding standards?
- **Spec** — does the code faithfully implement the originating issue / PRD / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point — a commit SHA, branch name, tag, `main`, `HEAD~5`, etc. If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

Before going further, confirm the fixed point resolves (`git rev-parse <fixed-point>`) and the diff is non-empty. A bad ref or empty diff should fail here — not inside two parallel sub-agents.

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

### 4. Spawn both sub-agents in parallel

Send a single message with two `Agent` tool calls. Use the `general-purpose` subagent for both.

**Standards sub-agent prompt** — include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full — the sub-agent has no other access to it.
- The brief: "Report a flat list of findings, nothing else — no preamble, no summary. One finding per entry, each on its own line as `<file>:<line> | <claim in one line> | <hard|judgment> | <evidence, at most two lines>`. Cover (a) every place the diff violates a documented standard, citing the standard file and rule in the evidence; and (b) any baseline smell, named. A documented repo standard overrides the baseline, and baseline smells are always judgment calls where documented-standard breaches can be hard. Skip anything tooling enforces. Return nothing if you find nothing."

**Spec sub-agent prompt** — include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report a flat list of findings, nothing else — no preamble, no summary. One finding per entry, each on its own line as `<file>:<line or -> | <claim in one line> | <missing|creep|wrong> | <the spec line it turns on>`. Cover (a) requirements the spec asked for that are missing or partial; (b) behavior in the diff that was not asked for; (c) requirements that look implemented but wrong. Quote the spec line for every finding. Return nothing if you find nothing."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Present the findings as a decision list

The sub-agents return raw finding lines, not a report. Never pass those through and never expand them back into narrative — a wall of prose findings buries the only thing the user actually has to do, which is decide what gets fixed.

Turn each line into a numbered item answerable at a glance, following the presentation contract in the global instructions. Keep the two axes under separate `## Standards` and `## Spec` headings and do not merge or rerank across them (see _Why two axes_), but number continuously so a reply can say "3 and 7" without naming an axis.

Each item is exactly this shape:

```
N. **<the claim in one line>** — `lib/my_app/tracking.ex:42`
   → Fix | Decline | Your call — <one-line reason>
   <two lines of evidence at most: the hunk, or the spec line it misses>
```

The contract covers the numbering, the recommendation, and silence-as-agreement. Three things it does not cover, specific to a review:

- **`Your call` is not the default.** The contract warns against manufacturing a recommendation you do not believe; the opposite failure is reaching for `Your call` on everything, which hands the review back rather than doing it. Use it where the choice is a genuine coin flip and nowhere else.
- **List the findings you would decline.** A sub-agent flagging something you disagree with is information; dropping it silently hides that the axis looked at all. `Decline` with a reason is the honest form.
- **Then act on exactly what came back.** A reply of "2 decline, 5 let's talk" means fixing the rest without re-asking.

End with one line per axis: how many findings, and how many are recommended `Fix`. No cross-axis winner — that is the reranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
