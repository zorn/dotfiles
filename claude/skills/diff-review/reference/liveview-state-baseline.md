# LiveView state baseline

Phoenix LiveView–first. The concern *names* — full struct, should-be-stream, refetchable data, unrendered sensitive fields — transfer to any stateful server UI even where the specific *fix* does not.

Each LiveView process holds its assigns for as long as the page stays open, so the cost multiplies with the number of connected users. Large assigns also slow the diff LiveView computes after each change.

An unbounded query is a Database finding when the query is in the diff. When only the assign is in the diff, flag the unbounded load here, because the Database axis may not run.

Judge each new or changed assign from both ends, even when the diff leaves them unchanged. Read the query or context function that builds it, to see which struct, columns, and preloads it holds. Read the template that renders it, the `.heex` file or `render/1`, to see which fields the page uses.

- Full struct where the template reads a few fields — the assign holds a whole Ecto struct, with every column and preload, and the page renders only a few of them. → a small map of the fields the page reads, such as `select: map(p, [:id, :name])`. A partial `select: struct(p, [...])` also works, but its unselected fields are `nil`, so a later template read renders blank instead of failing.
- Collection that should be a stream — a list assign that grows, or that renders as a long feed or table. The whole list stays in server memory until the page closes. → `stream/3`, which frees each item once it renders. Use it only when the server does not need the list again, such as for a count, a select-all, or a server-side filter.
- Data the page could fetch again on demand — picker options, search results, or a detail record kept in assigns after the interaction ends. → clear the assign then, and fetch again when the interaction starts over.
- Sensitive fields the page never renders — encrypted columns, PII, or third-party API payloads ride along in an assign. The size problem and the exposure problem share one fix. → select only the fields the page renders.
