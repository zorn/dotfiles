---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
license: MIT
disable-model-invocation: true
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: handoff
  forked-on: "2026-08-03"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
---

Write a document that lets a fresh agent continue this work without reading the conversation. That is the bar the handoff is finished against: if the next session would have to ask what was already decided, it is not done.

Save it to the session scratchpad directory when one is provided, otherwise to the OS temp directory. Not the workspace — a handoff is session state rather than a project artifact, and it should not turn up in a diff.

## What to write

Carry the state, not the story. A retelling of what happened is the thing the next agent is being spared:

- **Where the work stands** — what is finished, what is half-done and exactly where it stops, what has not been started.
- **What is blocked**, and on what.
- **What was decided, and why** — for anything a fresh agent would otherwise reopen. Rejected approaches belong here; they are the cheapest thing to re-litigate by accident.
- **What is still open** — questions raised and left unsettled.
- **Which skills the next agent should invoke**, named explicitly. A user-invoked skill will not suggest itself.

Reference other artifacts by path or URL rather than restating them. Specs, plans, decision documents, issues, commits, and diffs already hold their own content, and a second copy in the handoff is one that goes stale.

Redact secrets and personal data — API keys, tokens, passwords, and anything identifying a person.

If the user said what the next session will focus on, weight the document toward it: the parts of the state that bear on that work get the detail, the rest gets a line.
