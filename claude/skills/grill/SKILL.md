---
name: grill
description: A relentless interview, asked in batched rounds, that pressure-tests a plan or design before any of it gets built.
disable-model-invocation: true
---

# Grill

Interview the user until you reach a shared understanding. Do not act on any
of it — no edits, no scaffolding, no "I'll just start on the easy part" —
until they say you have.

Map the work as a **decision tree**: every decision branches into the
decisions that hang off it.

## Rounds

Work the tree in rounds. The **frontier** is every decision whose
prerequisites are already settled — the questions you can ask *now* without
guessing at answers you have not heard yet.

Ask the whole frontier in one round, then wait. Each round of answers
reshapes the tree: settled decisions push the frontier outward and unblock
questions that depended on them. Recompute and ask the next round.

A question whose answer depends on another question still open in this round
belongs to a *later* round. Asking it now means asking the user to answer
twice.

The session is done when the frontier is empty — every branch visited,
nothing left silently assumed.

## How to ask a round

Ask the round the way the global instructions require anything answerable to
be presented: numbered, each with your recommended answer and a one-line
reason, coin flips declared as coin flips, and silence standing as agreement.
That contract is what makes a round cheaper than a conversation — the user
reads the whole thing, accepts most of it, and spends their attention on the
one or two that are wrong.

Two things it does not cover, specific to interviewing:

- **Never re-ask a question they passed over.** Silence settled it, and
  re-opening it spends the trust the contract runs on.
- **Compress the question, not the round.** Twelve questions is fine; twelve
  paragraphs is not. A question that seems to need a paragraph of setup is
  usually resting on a prerequisite you have not actually settled — ask
  *that* one instead.

## Facts are your job, decisions are theirs

Never ask the user for something you could look up. When a frontier question
turns on a fact from the environment — the filesystem, git history, an
existing convention, a tool's output — dispatch a sub-agent to find it.

Do not block on that. A running exploration is an unsettled prerequisite, so
only the questions downstream of it wait; ask the rest of the frontier now
and fold the answer in next round.

The **decisions** are the user's. Put each one to them and wait.

## What the session leaves behind

A grilling session produces two kinds of durable output, and both have their
own skill. Hand off rather than inventing a format here.

- **A term gets pinned down** — an argument turns out to be about what a word
  means, or a concept finally gets a name. Hand off to `domain-language` the
  moment it crystallizes, not at the end; the wording is freshest while the
  argument is still in view.
- **A real trade-off gets settled** — hard to reverse, and surprising to a
  future reader without the reasoning. Offer `adr` when that branch closes.
  That skill has its own gate for what is worth recording, so offer and let
  it decide; do not pre-filter, and do not write a decision for every
  question answered.

Both are for repos. A session that is not about a codebase just ends.
