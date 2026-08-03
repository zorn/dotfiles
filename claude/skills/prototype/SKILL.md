---
name: prototype
description: Build a throwaway prototype to answer a design question. Use when the user wants to sanity-check whether a state model or logic feels right, or explore what a UI should look like.
license: MIT
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: prototype
  forked-on: "2026-08-03"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
---

# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

## Pick a branch

Identify which question is being answered — from the user's prompt, the surrounding code, or by asking if the user is around:

- **"Does this logic / state model feel right?"** → [logic.md](reference/logic.md). Build a tiny interactive terminal app that pushes the state machine through cases that are hard to reason about on paper.
- **"What should this look like?"** → [ui.md](reference/ui.md). Generate several radically different UI variations on a single route, switchable via a URL search param and a floating bottom bar.

The two branches produce very different artifacts — getting this wrong wastes the whole prototype. If the question is genuinely ambiguous and the user isn't reachable, default to whichever branch better matches the surrounding code (a backend module → logic; a page or component → UI) and state the assumption at the top of the prototype.

## Rules that apply to both

1. **Throwaway from day one, and clearly marked as such.** Locate the prototype code close to where it will actually be used (next to the module or page it's prototyping for) so context is obvious — but name it so a casual reader can see it's a prototype, not production. For throwaway UI routes, obey whatever routing convention the project already uses; don't invent a new top-level structure.
2. **One command to run.** A mix alias or `mix run <path>` in an Elixir project; whatever the project's existing task runner supports otherwise. The user must be able to start it without thinking.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is _checking_, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE — wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype _runnable_, no abstractions. The point is to learn something fast.
5. **Surface the state.** After every action (logic) or on every variant switch (UI), print or render the full relevant state so the user can see what changed.
6. **Capture it when done.** Fold any validated decision into the real code, then capture the prototype itself as a **primary source**: commit it to a throwaway branch, out of `main`, and comment a pointer to that branch on the implementation issue with `gh issue comment`. Capture the answer too — the verdict and the question it settled. `main` keeps only the validated decision.

   When a prototype produced a snippet that encodes a decision more precisely than prose can — a state machine, reducer, schema, or type shape — carry that snippet into the spec or ticket rather than describing it. Trim it to the decision-rich parts: not a working demo, just the bits that pin the decision down. This is the rule `to-spec` and `to-tickets` defer to.
