# Database review baseline

Ecto/Postgres-first. The concern *names* — N+1, unbounded query, missing index, missing transaction — transfer off Ecto even where the specific *fix* does not.

Three concerns, each keyed to a signal in the diff: migration files trigger migration safety; query and `Repo.` code trigger transaction consistency and query performance.

## Migration safety

Defers to project tooling. If the project depends on [`excellent_migrations`](https://github.com/Artur-Sulej/excellent_migrations) or wires the equivalent Ecto Credo checks, skip this concern rather than applying the items below. Otherwise apply them.

- Non-concurrent index — `create index` locks writes for the whole build. → `concurrently: true` with `@disable_ddl_transaction` and `@disable_migration_lock`.
- Column with a default on older engines, or `NOT NULL` on an existing column — table rewrite or full scan under lock. → add nullable first, backfill, then constrain.
- FK or check constraint validated in place — the validation scans and locks the table. → add with `validate: false`, then validate in a later migration.
- Column or table rename or drop while old code still runs — the running app version breaks the moment the schema changes. → schema-only rename via `source:`, or add-new / backfill / drop-old across deploys; drop only after the field has left the Ecto schema.
- Column type change — rewrites the table. → new column, dual-write, backfill, swap reads, drop old.
- Backfill inside the migration transaction, or unthrottled — locks rows for the whole migration, or spikes DB CPU. → `@disable_ddl_transaction`, keyset-batch with `update_all`, sleep between batches.
- Live schema module used in a data migration — the schema drifts from the table and breaks re-runs. → raw SQL or an inline snapshot schema; keep backfills in their own file, with `flush()` between DDL and data.
- `json` column — no equality operator, breaks `SELECT DISTINCT` and comparisons. → use `jsonb`.

## Transaction consistency

- Dependent writes with no transaction — a mid-sequence failure leaves partial state. → wrap in `Ecto.Multi` / `Repo.transaction`.
- Read-modify-write without a lock — a lost update under concurrency. → `lock: "FOR UPDATE"` or an atomic `update_all`.
- Side effects (email, Oban job, HTTP call) fired inside the transaction — a later rollback can't recall them. → enqueue after commit.

## Query performance

- N+1 — a query issued per row of a prior result, or a missing `preload`. → preload the association, or join.
- Unbounded query — a whole table loaded, or a list endpoint with no `limit`. → paginate or cap.
- New frequent query pattern with no supporting index — a sequential scan. → add the index, concurrently.
