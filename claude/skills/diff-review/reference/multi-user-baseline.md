# Multi-user review baseline

Phoenix LiveView–first. The concern *names* — stale read, lost update, unhandled conflict — transfer off Phoenix even where the specific *fix* does not.

Read every write path in the diff as if two people act on the same resource at once, one in each browser tab, each holding the struct their page loaded. The items fall into three groups, each keyed to a signal in the diff. Context functions that write trigger the server group. LiveViews and controllers that call them trigger the UI group. Either one triggers the test group.

## Server: the stored row decides

- Stale-struct guard — a state check (published? closed? still a draft?) reads the struct the caller passed in, not the stored row, so a tab that loaded it earlier acts on a stale state. → recheck the stored row under a lock inside the transaction, or fold the check into a conditional update.
- Repeatable one-shot transition — a transition meant to happen once (close, publish, approve) runs again from a second tab and overwrites the first timestamp. → `UPDATE … WHERE <column> IS NULL` through `update_all`, and return an error when no row matched.
- Read-modify-write without a lock — a value is read, changed in Elixir, and written back, so a concurrent writer's change is lost. → `lock: "FOR UPDATE"`, or an atomic `update_all`.
- Unguarded concurrent edits — two people can edit the same resource, with no `lock_version` and no stated choice of last-write-wins. → `Ecto.Changeset.optimistic_lock/3`, or a comment that records last-write-wins as deliberate.

## UI: the losing tab recovers

- Newly reachable error the UI doesn't handle — the context now returns an error the LiveView never saw before, and a `{:error, changeset}` match crashes on it. → handle every error the context can return, with a flash that says what happened.
- The losing tab keeps stale state — it shows a flash but keeps the old assigns, so it still offers buttons for a state that no longer exists. → reload the resource when a conflict error comes back.
- Other viewers never hear about the change — the transition sends no PubSub broadcast, or a page that shows the resource never subscribes, so other tabs show the old state until a refresh. → broadcast on the transition, and subscribe where the resource is shown.

## Tests: the stale struct is exercised

- Guarded transition with no stale-struct test — nothing calls the function with a struct that is out of date. → load the struct, change the row underneath it, then call the function and assert the error. A real two-process race test is costly under the SQL sandbox, so this is the cheap proxy.
