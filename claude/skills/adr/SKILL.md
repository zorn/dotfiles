---
name: adr
description: Record an architecture decision as a numbered document in docs/adr/. Use when a real trade-off has been settled and is worth writing down, when a new decision amends or overturns an earlier one, or when another skill needs a decision recorded. Reading an existing decision is not this skill.
---

# Architecture Decision Records

Capture the reasoning behind a choice while it's still in someone's head. The
value is in recording *that* a choice was made and *why* — not in filling out
a form.

Say "decision" when talking to the user; write to `docs/adr/`. The path
carries the searchable term of art, the conversation doesn't need it.

## When to offer one

All three must be true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will look at the code and
   wonder "why on earth did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and
   one was picked for specific reasons.

If a choice is easy to reverse, skip it; it'll just get reversed. If it isn't
surprising, nobody will wonder why. If there was no real alternative, there's
nothing to record beyond "we did the obvious thing."

Offer sparingly. A repo where every choice became a decision document is a
repo where nobody reads them.

Something that fails the test but still deserves writing down is usually a
coding standard or a glossary term rather than a decision — for the latter,
hand off to the `domain-language` skill.

### What qualifies

- **Architectural shape.** "The write model is event-sourced, the read model
  is projected into Postgres."
- **Technology choices carrying lock-in.** Database, message bus, auth
  provider, deployment target — the ones that would take a quarter to swap,
  not every library.
- **Boundary and scope decisions.** "Customer data is owned by the Customer
  context; everything else references it by ID." The explicit no's are as
  valuable as the yes's.
- **Deliberate deviations from the obvious path.** "Manual SQL instead of an
  ORM, because X." Anything a reasonable reader would assume the opposite of.
  These stop the next person from "fixing" something that was intentional.
- **Constraints invisible in the code.** "We can't use AWS, for compliance
  reasons." "Responses must be under 200ms, per the partner API contract."
- **Rejected alternatives whose rejection is non-obvious.** If GraphQL was
  considered and REST won for subtle reasons, record it — otherwise someone
  proposes GraphQL again in six months.

## Where they live

Find the directory before creating one:

1. An existing `docs/adr/` or `docs/decisions/` — use it, and **match the
   numbering already there** rather than imposing a new scheme. A repo whose
   decisions run `1-timestamps.md`, `2-…` keeps single digits; renumbering to
   four would break every link pointing at them, and the decisions are
   immutable anyway.
2. Otherwise create `docs/adr/`, with the four-digit convention.
3. If a repo has both directories, or something else again, ask rather than
   picking one and splitting the history in two.

## Writing one

The conventions live in [reference/about.md](reference/about.md) — when to
write, how short to keep it, the title-length limit, the numbering, and how to
amend an earlier decision. Read it before writing, and follow it rather than
this file: it is the copy that ships to the repo, so it stays right when the
two would otherwise drift.

If the directory doesn't exist yet, create it along with the first decision and
seed it with [reference/about.md](reference/about.md) and
[reference/template.md](reference/template.md) (as `about.md` and
`__template.md`). Those two put the convention in the repo, where a human
reader and any other agent will find it.

If the directory exists but has no `about.md`, don't add one uninvited — offer.
A repo that has been keeping decisions without it has a convention of its own,
and reading the existing documents tells you more than seeding a file would.

## Publishing (ex_doc projects)

Adding a decision should require no `mix.exs` edit. The pattern that achieves
that globs the numbered files into `extras()`, so a new one publishes on its
own:

```elixir
[
  ...,
  "docs/adr/about.md"
] ++ Enum.sort(Path.wildcard("docs/adr/0*.md"))
```

Note what the glob excludes. `about.md` doesn't match `0*.md`, so it gets its
own entry and leads the section; `__template.md` doesn't match either, which
is deliberate — the template isn't a document anyone should read in published
docs. A repo numbering its decisions some other way needs a glob to match:
`0*.md` only covers a four-digit scheme.

If the project depends on `ex_doc` and this wiring is missing, offer the edit
and show the diff. Make it once, on the first decision; after that the glob
carries every new one. A `Decisions:` group in `groups_for_extras()` keeps
them together in the sidebar under a name that reads better than the path
does.
