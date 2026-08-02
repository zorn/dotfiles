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

## Writing one

Decisions live in `docs/adr/`, named with a four-digit sequential prefix and a
short kebab-case slug: `0001-which-rust-library.md`. Take the next number
after the highest existing one.

**Keep the title short — 30 characters or fewer.** It's used verbatim in the
generated docs' sidebar, which truncates with an ellipsis. A concise noun
phrase ("Automerge Rust Library") beats a sentence.

One to three sentences — the situation, the choice, the reason — is a complete
decision, and most should be exactly that. `__template.md` offers **Problem
Statement**, **Decision Made**, and **Consequences & Tradeoffs** as optional
sections; reach for one only when it carries weight the summary cannot, and
delete the headings that go unused. Filling out every heading turns a record
into an essay nobody rereads.

If `docs/adr/` doesn't exist yet, create it along with the first decision and
seed it with [reference/about.md](reference/about.md) and
[reference/template.md](reference/template.md) (as `about.md` and
`__template.md`). Those two put the convention in the repo, where a human
reader and any other agent will find it.

## Amending an earlier decision

**Decision documents are immutable.** Never rewrite one to match how the code
works today — that turns a record of *why we chose* into a second, competing
statement of *what we do*, and the two drift apart.

When a new decision narrows, extends, or overturns an older one, say so in the
new document **and add a pointer to the top of the old one**, directly under
its title:

```md
# In-Window Secondary Views

> **Scoped by [ADR 0022](0022-report-refreshes-on-demand.md)** — the Report is
> read-only and refreshes on demand rather than on every `{:book_updated}`.
```

That pointer is the one edit an existing decision may receive. It costs a line
and means a reader landing on the old document learns immediately that it
isn't the end of the story, instead of reconstructing the chain backwards from
the newest one.

Non-semantic fixes — broken links, renamed paths, typos — are always fine.
They change nothing the decision asserts.

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
docs.

If the project depends on `ex_doc` and this wiring is missing, offer the edit
and show the diff. Make it once, on the first decision; after that the glob
carries every new one. A `Decisions:` group in `groups_for_extras()` keeps
them together in the sidebar under a name that reads better than the path
does.
