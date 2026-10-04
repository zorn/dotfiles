---
name: retro
description: Conduct a retrospective on a coding session — find where the agent struggled and propose changes to its environment so the next run goes better.
argument-hint: "[session id or path] [number of past sessions to scan]"
license: MIT
disable-model-invocation: true
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: retro
  forked-on: "2026-10-04"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
---

The user has asked for a **retrospective**. You are proposing improvements to the coding agent's **environment** — the files, checks, tools, and steering it works inside — so that future runs go better.

## Steps

### 1. Read the session

The **primary session** is the current one, unless the user names another. Session logs live in `~/.claude/projects/<slug>/<session-id>.jsonl`, where `<slug>` is the project's absolute path with every character that is not a letter or digit replaced by `-`.

Find the moments the agent struggled: it hunted a long time for a file or fact, made a mistake a tool could have caught, slipped a mistake past review, made an expensive tool call for little return, lacked information it had no way to reach, or was corrected by the user.

The step is done when every struggle is listed with the moment it happened.

### 2. Scan recent sessions for repeats

Dispatch one sub-agent to read the **five most recent other sessions of the same repo**. A number in the arguments overrides the count. Each worktree gets its own `~/.claude/projects/<slug>/` directory, so the repo's sessions are spread across several. Give the sub-agent the repo's `git rev-parse --git-common-dir`, and have it keep a session only when `git -C <cwd> rev-parse --git-common-dir` matches, where `<cwd>` is the `cwd` field the session's log records. A worktree removed after merging fails that check, and those are most of the past sessions. Keep those sessions by path: a `cwd` under the repo's own directory (Claude's `.claude/worktrees/`), or under `~/.herdr/worktrees/<repo directory name>/`. The sub-agent reads the raw logs so you do not — they are large, and only the patterns matter here.

Give it the list of struggles from step 1, and the brief: "For each struggle, report the sessions where the same struggle recurs, citing the session id and what happened in one line. Then report any other struggle that recurs in two or more of these sessions. Report only struggles that recur."

Past sessions add weight. A struggle seen in several sessions is a pattern, whether or not the primary session shows it, and a pattern raises its severity.

### 3. Find candidates

Look for candidates in these categories. Every candidate must point back to a specific moment in a session. A candidate you cannot trace to one is generic advice — drop it.

- **Navigation**: how easy was it for the agent to find the right files? Are there hidden dependencies between files? Would a **navigation pointer** make it easier? _Use when_ the session took a long time to find a piece of information.
- **Automated checks**: are there automated checks that could catch errors the agent made? Linting, typing, tests, filesystem linters? Read the repo's own check command first (its build-tool `lint`/`check` scripts, its CI workflow), so a check that already exists but sits unwired or silently broken is the finding, not a reinvention. A repo with no **guardrail** (no pre-commit hook and no CI job running its lint/typecheck/test command) is itself a finding: an un-linted repo is a standing missed opportunity, not a neutral default. Cite the moment the agent finished work that no check ever ran against. _Use when_ the agent made a mistake an automated check could have caught, or the repo has no guardrail at all.
- **Coding standards**: should the reviewer — `diff-review`, whose Standards axis reads the repo's documented standards — be given a new rule to enforce? Should an existing rule be removed or clarified? Classify the violation first. A **mechanical** one (a fixed syntactic pattern, a banned API, an import shape, a file-location rule) gets a deterministic check: a custom rule in the repo's own linter, a new pre-commit hook, or a new CI job, whichever the repo's language and existing guardrail make cheapest. Reserve `CODING_STANDARDS.md` for genuine **judgment calls** (cross-file consistency, "matches the surrounding style," anything no guardrail could ever substitute for). _Use when_ the reviewer failed to catch a mistake.
- **Steering files**: `AGENTS.md`/`CLAUDE.md` (the repo's, and the global `~/.claude/CLAUDE.md`) and the auto-memory index `MEMORY.md` all load into every session. Are there instructions in them that should move to coding standards, a check, or a skill? Are there **no-ops** — lines that do not change the agent's behavior? Is a memory being recorded again and again? A feedback memory that keeps returning is a rule the environment has not absorbed; propose the skill edit or check that would make it unnecessary. _Use when_ the agent ignored a steering instruction, tripped over one, or followed one into a mistake, or a memory recurs.
- **Skills**: did a skill mislead the agent, omit a step it needed, or fail to trigger? Was there a repeated procedure that no skill covers? _Use when_ the agent followed a skill into a mistake, or improvised a process it has improvised before.
- **Tool economy**: did the agent make expensive tool calls that could be streamlined? Is there any custom tooling (CLIs, MCPs) that is particularly token-inefficient? _Use when_ the agent made an expensive tool call.
- **Information access**: look for opportunities to increase the agent's access to information. For example, tee the dev server log to a file the agent can read, or give it read-only access to a third-party service. _Use when_ a crucial piece of information was not available to the agent.

The step is done when every struggle from steps 1 and 2 is either a candidate or dropped as untraceable.

### 4. Route each candidate to its scope

A fix lives in one of two places, and the candidate names which:

- **Repo** — the project the session worked in: its `AGENTS.md`, `CODING_STANDARDS.md`, docs, linter config, or CI.
- **Global** — the dotfiles repo that `~/.claude/` links into, found by resolving any symlink in `~/.claude/skills/`: a skill, the global `CLAUDE.md`, hooks, or settings. Name the source path in dotfiles, not the `~/.claude/` path.

Memory is the exception: it lives in `~/.claude/projects/<slug>/memory/`, and its fix is usually to delete the memory once a repo or global fix makes it redundant.

### 5. Present the candidates

Present the candidates as a numbered decision list, most severe first. Severity is the cost to future runs: a repeated struggle outranks a one-off, and a mistake that shipped outranks one that got caught. Each one leads with a colored verdict and its claim in a single line:

- 🔴 **Fix** — build it.
- 🟡 **Weigh** — a genuine coin flip; state both sides. It defaults to Keep if the user does not mention it.
- ⚪ **Keep** — a struggle you surfaced but would not change the environment for.

Under the claim, cite the moment it came from, its scope, and the concrete change. End by saying that anything the user does not mention stands as recommended.

The run ends at the list. The user's reply decides which candidates get built.

## Reference

### Implementation vs Review

All work goes through two stages: implementation (`implement`, `tdd`) and review (`diff-review`). The implementation agent has the most **context pressure**. It is responsible for exploration, writing code, and debugging failures.

The review agent has the least context pressure — it receives a diff, so no exploration is needed.

So the review agent imposes coding standards, not the implementation agent.

### Files

- `AGENTS.md`/`CLAUDE.md`: pushed into the context window of any agent working in the repo. Use them very sparingly — usually only for **navigation pointers** to other files, and the gotchas an agent cannot learn by looking.
- `CODING_STANDARDS.md`: read during review, not implementation. Add **navigation pointers** to docs folders if the standards file grows past 1,000 lines. If the repo has none, propose starting it the first time a judgment-call rule turns up; `CONTRIBUTING.md` serves the same purpose where it exists.
- Docs: reference files, pointed to by other files. Look for existing docs before writing new ones.
- Skills: use skills for guidance only needed for one kind of task (since only their description goes into the agent's context window), or for user-invoked commands.
- `MEMORY.md`: the auto-memory index, loaded into every session in that project. Each line costs what an `AGENTS.md` line costs.
