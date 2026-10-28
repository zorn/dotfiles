# Multi-user Review Axis

`/diff-review` gains a Multi-user axis that reviews a diff as if two people act on the same resource at once, which narrows [ADR 0002](0002-no-correctness-axis.md): races of this one kind are now checked here, and general correctness stays with `/code-review`. Flick shipped three stale-struct races in a row ([flick#276](https://github.com/zorn/flick/pull/276), [#330](https://github.com/zorn/flick/pull/330), [#341](https://github.com/zorn/flick/pull/341)), and only `/code-review`'s open-ended pass caught them. A fixed lens asks the question every time. Settled in [issue #113](https://github.com/zorn/dotfiles/issues/113).

## Consequences & Tradeoffs

Folding the concerns into the Database axis was rejected. The races also raise UI concerns: #276 and #341 each had to handle a newly reachable error in a LiveView, and #330 left the losing tab showing stale buttons. Reloading that tab and broadcasting the change to other viewers stayed out of scope in all three. A Database gate would have to fire on LiveView-only diffs to see any of this. Like Database ([ADR 0001](0001-conditional-database-axis.md)), the axis runs only when the diff touches a write path, and its baseline loads only then. "Read-modify-write without a lock" splits by who the second writer is: races between users belong here, and jobs and processes stay with Database.

The overlap with `/code-review` that ADR 0002 avoided is accepted here because the axis is a fixed lens with a named baseline, not a second open-ended bug hunt, so the two lists should not drift into duplicates. The name is Multi-user, not Concurrency, because in Elixir "concurrency" points a reviewer at processes and GenServers, which this axis does not cover.
