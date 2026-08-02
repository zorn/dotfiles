---
name: domain-language
description: Build and sharpen a project's ubiquitous language. Use when the user wants to pin down domain terminology, name a concept, settle what a word means in this project, or resolve a fuzzy or overloaded term — and when another skill needs the project's vocabulary kept current.
---

# Domain Language

Actively build and sharpen the project's ubiquitous language as you design.
This is the *active* discipline — challenging terms, inventing edge-case
scenarios, and writing definitions down the moment they crystallise. Merely
*reading* the glossary for vocabulary is not this skill; that's a one-line
habit any skill can do. This is for when you're changing the language, not
just consuming it.

Decisions are a separate concern. When a real trade-off gets settled, hand off
to the `adr` skill rather than recording it here.

## The file

One file per project, holding the whole ubiquitous language. Find it before
creating it:

1. An existing `docs/ubiquitous_language.md` or root `UBIQUITOUS_LANGUAGE.md`
   — use it, whatever else the repo's layout suggests.
2. Otherwise infer from the project: a `mix.exs` at the root means
   `docs/ubiquitous_language.md`, so `ex_doc` can publish it. Anything else
   gets `UBIQUITOUS_LANGUAGE.md` at the repo root.
3. If neither rule clearly applies, ask before creating. Never guess silently
   about where the first one goes — a glossary in the wrong place gets
   abandoned rather than moved.

Create it lazily, when the first term is actually resolved. Don't open a
session by generating a glossary nobody asked for.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with a definition already in the
file, call it out immediately. "The glossary defines *cancellation* as X, but
you seem to mean Y — which is it?"

### Sharpen fuzzy language

When a term is vague or overloaded, propose a precise canonical one. "You're
saying *account* — do you mean the Customer or the User? Those are different
things."

### Discuss concrete scenarios

When domain relationships are being worked out, stress-test them with specific
scenarios. Invent cases that probe the edges and force a decision about where
one concept stops and the next begins.

### Cross-reference with code

When the user states how something works, check whether the code agrees. A
contradiction is worth surfacing: "The code cancels whole Orders, but you just
said partial cancellation is possible — which is right?"

### Write it down inline

When a term is resolved, update the file right then. Don't batch them up to
the end of the session; a definition captured three topics later has already
lost the reasoning that produced it.

## What belongs

Only terms specific to *this project's* domain. Before adding one, ask whether
it is a concept unique to this project or a general programming concept.
General ones — timeouts, error types, utility patterns, and DDD vocabulary
like Entity and Value Object — stay out even when the project leans on them
heavily. They're the same in every project, so recording them here buries the
handful of words that aren't.

The file is a glossary and nothing else. Not a spec, not a scratch pad, not a
home for implementation decisions. Keep it free of implementation detail: a
definition says what a thing *is*, not how it is stored or which module owns
it.

When a term doesn't belong, say so and leave it out — "that's a general
software term rather than your domain language" is a complete answer. Two
exceptions, and only when the file already exists: a repo with a
`docs/software-terms.md` or `docs/ui-language.md` has somewhere to put the
term, so put it there and link that file from the glossary's opening
paragraph. Never create those files. A project that hasn't asked for that
split shouldn't be given one.

## Format

```md
# {Project Name}

{One or two sentences on what this project is and what this file is for.}

## Language

**Order**:
A customer's request to buy, once submitted and priced.
_Avoid_: Purchase, transaction

**Report range**:
How far back a Report looks — the rule fixing which Months it covers. Named
_range_, not "window," because a window in this app is a native desktop window
(see [ADR 0006](docs/adr/0006-multi-window-desktop-shell.md)).
```

**Be opinionated.** When several words exist for one concept, pick the best
and list the rest under `_Avoid_`.

**`_Avoid_` is for a bare rejected synonym** — the case where there's nothing
to say beyond "we picked one." When the rejection has a *reason*, write the
reason into the definition instead, as the Report range entry above does.
"Not X, because X means something else here" teaches what a list can't.

**Keep definitions tight.** One or two sentences. Define what the thing IS.
Longer is warranted only when a boundary is genuinely subtle.

**Link to the decision that settled a term** when there is one. That link is
the connective tissue between this file and `docs/adr/` — it turns a
definition into something a reader can trace back to its argument.

**Group under subheadings** when natural clusters emerge. A flat list is fine
while every term belongs to one cohesive area.

### Sharp Edges

Some misalignments belong to no single term — they exist *between* two, and
recording them under either one hides them from a reader who looks up the
other. Those go in a numbered `## Sharp Edges` section, with the affected
definitions pointing at the entry:

```md
## Sharp Edges

1. The schema is `RankedVoting.RankedAnswer`, and ballot creation asks for
   `Possible Answers`, but vote capture asks for `First Preference`, `Second
   Preference`, and so on. Those preferences are stored as `RankedAnswer`s.
   The presentation reads better than the alignment would, and that trade is
   deliberate.
```

Tension that sits *inside* one definition doesn't need this — write it into
the definition, the way the Report range entry contrasts itself with "window."
Reach for Sharp Edges when the mismatch spans terms, or spans code and UI.

## Publishing (ex_doc projects)

A file at `docs/ubiquitous_language.md` doesn't reach the generated docs
unless it's listed in `extras()` in `mix.exs`. If the project depends on
`ex_doc` and the file isn't listed, offer the edit and show the diff — don't
make it silently, and don't nag if the user declines. It needs an entry in
`extras()` and usually one in `groups_for_extras()` alongside the project's
other guides.

`mix docs` already warns about a link to any `.md` not covered by `extras`, so
an unwired file that something links to announces itself.
