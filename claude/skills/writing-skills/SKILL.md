---
name: writing-skills
description: Reference for writing and editing skills well — the vocabulary and principles that make a skill predictable.
license: MIT
disable-model-invocation: true
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: writing-great-skills
  forked-on: "2026-08-03"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
---

A skill exists to wrangle determinism out of a stochastic system. **Predictability** — the agent taking the same _process_ every run, not producing the same output — is the root virtue; every lever below serves it.

**Bold terms** are defined in [`reference/glossary.md`](reference/glossary.md), and every definition lives there rather than here. What follows is the order to apply them in.

## Reviewing an existing skill

Work outward from the always-loaded material:

1. **The description**, and whether the skill should be **model-invoked** or **user-invoked** at all. It is the only part loaded every turn, so it earns the hardest pruning.
2. **Prune the body** — **relevance**, then **no-ops**, then **duplication**, in that order.
3. **Check the ladder** — is anything sitting in `SKILL.md` that belongs behind a **context pointer**, and does every **step** end on a **completion criterion** the agent can check?
4. **Check every failure mode** listed at the end of this file against the skill.

The review is done when each failure mode has been either found or explicitly ruled out — not when you run out of things you happened to notice. An unbounded pass reports whatever caught its attention that run, which is the variance this skill exists to remove.

## Frontmatter

The [Agent Skills spec](https://agentskills.io/specification) defines six fields. Only the first two are required, and most skills need nothing else:

- `name` — 1-64 characters, lowercase alphanumerics and single hyphens, matching the directory name.
- `description` — max 1024 characters. See below.
- `license` — a license name, or the name of a bundled license file. Worth setting on a skill derived from someone else's work, since the terms travel with the file rather than the repo.
- `compatibility` — environment requirements, max 500 characters. Most skills have none.
- `metadata` — an arbitrary map of string keys to string values, for anything the spec does not define. Provenance belongs here.
- `allowed-tools` — space-separated pre-approved tools. Experimental, and support varies between agents.

Any other field is a client extension: legitimate, but not portable. `disable-model-invocation` is one — it is how Claude Code makes a skill **user-invoked**, and no part of the spec.

## Invocation

Two choices, trading different costs. A **model-invoked** skill keeps its **description**, so the agent can fire it and other skills can reach it, and pays **context load** every turn. A **user-invoked** skill keeps its description too — the spec requires one — but hidden from the agent, so it pays nothing and spends **cognitive load** instead, because you become the index that has to remember it exists.

Pick model-invocation only when the agent must reach the skill on its own, or another skill must. If it only ever fires by hand, make it user-invoked. When user-invoked skills multiply past what you can hold in your head, a **router skill** is the cure.

## Writing the description

A model-invoked **description** does two jobs — state what the skill is, and list the **branches** that should trigger it. Every word increases **context load**, so a description earns even harder pruning than the body:

- **Front-load the skill's leading word** — the description is where it does its invocation work.
- **One trigger per branch.** Synonyms that rename a single branch are **duplication** — "build features using TDD … asks for test-first development" is one branch written twice. Collapse them; keep only genuinely distinct branches.
- **Cut identity that's already in the body.** Keep the description to triggers, plus any "when another skill needs…" reach clause.

A user-invoked skill's description is read by you, not the agent. Write one line naming whatever distinguishes this skill from your others, and strip the trigger phrasings entirely — nothing is matching against them.

## Information hierarchy

Content is **steps** or **reference**, mixing freely, and each piece sits somewhere on the **information hierarchy** — a ladder ranked by how immediately the agent needs it:

1. **Steps** in `SKILL.md` — the primary tier, when a skill has them.
2. **Reference** in `SKILL.md` — consulted on demand. Often a legitimately flat peer-set, which is a fine arrangement rather than a smell.
3. **Reference** behind a **context pointer** — loaded only when the pointer fires.

Push too little down and the top bloats; push too much and you hide material the agent actually needs. That tension is the whole decision, and **branching** is the cleanest test: inline what every branch needs, push behind a pointer what only some branches reach.

**Progressive disclosure** is the move down the ladder. A pointer's _wording_, not its target, decides when and how reliably the agent reaches the material — so a must-have behind a weak pointer is fixed by sharpening the wording, and pulled back inline only if sharpening fails. Where the ladder decides how far down a piece sits, **co-location** decides what sits beside it once there: a concept's definition, rules, and caveats under one heading rather than scattered.

## When to split

**Granularity** is how finely you divide skills, and each cut spends one of the two loads, so split only when the cut earns it. Split by **invocation** when a distinct **leading word** should trigger the new skill on its own, or another skill must reach it. Split by **sequence** when a step's **post-completion steps** tempt the agent to rush the step in front of it.

## Pruning

In order, cheapest first:

1. **Relevance** — does the line still bear on what the skill does?
2. **No-ops** — sentence by sentence, not line by line. Run the test on each sentence in isolation, and when one fails delete the whole sentence rather than trimming words from it. Be aggressive: most prose that fails should go, not be rewritten.
3. **Duplication** — keep each meaning in a **single source of truth**, so changing the behavior is a one-place edit.

## Leading words

A **leading word** is a compact concept already living in the model's pretraining that the agent thinks with while running the skill — _lesson_, _fog of war_, _tracer bullets_. It anchors a whole region of behavior in the fewest tokens by recruiting priors the model already holds, and it earns **predictability** twice: in the body it anchors execution, in the description it anchors invocation. Reach for a word you already use in your own prompts and docs, since the shared language is what makes the link.

Grade one with the **no-op** test. A word too weak to beat the default — _be thorough_, where the agent is already thorough-ish — buys nothing, and the fix is a stronger word rather than a different technique.

## Failure modes

Check each one against the skill under review, reading its glossary entry rather than working from the name — the name alone will not tell you what to look for.

- **Premature completion**
- **Duplication**
- **Sediment**
- **Sprawl**
- **No-op**
- **Negation**
