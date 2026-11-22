# Database review baseline

Ecto/Postgres-first. The concern *names* — N+1, unbounded query, missing index, missing transaction — transfer off Ecto even where the specific *fix* does not.

Four concerns, each keyed to a signal in the diff: migration files trigger migration safety and migration reversibility; query and `Repo.` code trigger transaction consistency and query performance.

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

## Migration reversibility

Always applies, even when the migration-safety deferral above skips that concern. Safety tooling such as `excellent_migrations` flags unsafe DDL but does not check that a migration rolls back, and a `change` migration hides an irreversible step until someone runs `mix ecto.rollback`.

- `execute/1` inside `change` — Ecto cannot reverse raw SQL, so the rollback raises. → `execute/2` with the down SQL, or split into `up` and `down`.
- `remove` with no type inside `change` — Ecto cannot re-add a column it knows nothing about. → `remove :field, :type, opts`.
- `modify` with no `:from` inside `change` — Ecto cannot restore the old type or options. → `modify :field, :new_type, from: :old_type`.
- `drop table` or `drop_if_exists` inside `change` — the table's definition is gone, so nothing can recreate it. → `up` and `down`, with `down` recreating the table.
- `up` with a `down` that does not undo all of it — the rollback runs but leaves a column, index, or constraint behind. → make `down` the exact mirror of `up`.
- An irreversible migration with no explicit `down` — a rollback fails with Ecto's generic error, or silently does nothing. → when the change truly cannot be undone, such as dropping a column that holds data, write a `down` that raises `Ecto.MigrationError` with the reason.

## Transaction consistency

Leave races between users to the Multi-user axis. This concern covers concurrent writes from jobs and processes.

- Read-modify-write without a lock in a job or process — an Oban worker or GenServer reads a value, changes it in Elixir, and writes it back, so a concurrent writer's change is lost. → `lock: "FOR UPDATE"`, or an atomic `update_all`.
- Dependent writes with no transaction — a mid-sequence failure leaves partial state. → wrap in `Ecto.Multi` / `Repo.transaction`.
- Side effects (email, Oban job, HTTP call) fired inside the transaction — a later rollback can't recall them. → enqueue after commit.

## Query performance

- N+1 — a query issued per row of a prior result, or a missing `preload`. → preload the association, or join.
- Unbounded query — a whole table loaded, or a list endpoint with no `limit`. → paginate or cap.
- New frequent query pattern with no supporting index — a sequential scan. → add the index, concurrently.
