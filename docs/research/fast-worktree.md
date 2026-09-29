# What axelson/fast-worktree does

Research ticket: https://github.com/zorn/dotfiles/issues/41. Source read directly from a clone of https://github.com/axelson/fast-worktree at its default branch on 2026-09-21. Citations point at files and line ranges in that repo.

## Bottom line

fast-worktree makes a git worktree ready for Elixir work by *cloning*, not rebuilding: it copy-on-write-clones the golden checkout's `_build`, `deps`, and `assets/node_modules`, and template-clones the dev Postgres database in one `CREATE DATABASE ... TEMPLATE` call. It writes a per-worktree env file with a unique port slot and the cloned DB name, and leaves the Elixir-specific wiring (deriving `PORT`, reading DB names in `runtime.exs`, migrating) to project config and hooks. The reusable idea is the CoW-clone-plus-template-DB core; the main trade-off is that a cloned `_build` can go stale relative to the worktree's own source, so it depends on keeping the golden checkout compiled and current.

## What it is

fast-worktree (`fw`) is a bash worktree manager built around a "golden build" (`fast-worktree:6`, `docs/architecture.md:9-30`). The premise: keep the main checkout compiled and its database current, then make each new worktree a *copy* of those artifacts rather than a fresh build. It is not Elixir-only — it is stack-agnostic and presence-gated on config — but its defaults and its only end-to-end tutorial are Phoenix/Elixir (`docs/tutorial-phoenix.md`, `lib/config.sh:194`).

The entrypoint is one bash script (`fast-worktree`) that sources ~40 `lib/*.sh` modules (`fast-worktree:31-70`). It requires bash 4+ and re-execs itself under a newer bash if the shebang found 3.2 (`fast-worktree:8-22`).

## The create pipeline, in order

`cmd_create` (`lib/worktree.sh:473-619`) runs these steps. The setup work is split into a foreground half that blocks the switch and is rollback-protected, and a background half deferred into the new session (`lib/worktree.sh:312-359`).

1. Parse args, resolve the branch name and worktree name, validate the name (lowercase only, because it feeds unquoted Postgres identifiers — `lib/worktree.sh:8-10`), reject the reserved name `main` (`lib/worktree.sh:519-526`).
2. Resolve the base branch: an explicit `--base`, or the stack parent of a reused branch, or trunk; `--base=.` stacks on the branch checked out in the invoking cwd (`lib/worktree.sh:543-571`).
3. `git worktree add` the new branch from the base, off the golden checkout (`lib/worktree.sh:575-582`).
4. Foreground populate — `_populate_worktree_fg` (`lib/worktree.sh:322-346`), in this exact order:
   a. `write_worktree_env` — allocate a port slot, write the env file (`lib/envfile.sh:93-127`).
   b. `clone_assets` — CoW-clone the `cow_assets` directories (`lib/cow.sh:91-104`).
   c. Export the `FW_*` contract (`lib/hooks.sh:49-56`).
   d. `hook_pre_db` — optional project setup that must precede the DB step, e.g. writing secret/env files a DB setup command needs (`lib/worktree.sh:332-334`).
   e. `db_create_for_worktree` — template-clone the database (`lib/db.sh:26-58`).
   f. Regenerate the Caddy map and stamp recency (`lib/worktree.sh:340-345`).
5. Optionally set the Claude model in `settings.local.json` (`lib/worktree.sh:596-599`).
6. Background half — `hook_post_create` (setup that needs the DB to exist) is run via tmux send-keys in the new session's first window, so the switch does not wait on it (`lib/worktree.sh:606-608`, `355-359`).
7. Optionally launch Claude with a prompt, then switch into the worktree (`lib/worktree.sh:611-617`).

If any foreground step fails, `_rollback_create` drops the DB (only if this create made it), removes the worktree dir, deletes the branch (only if this create created it), and refreshes Caddy (`lib/worktree.sh:437-458`). Past the background half there is no rollback — the worktree is live (`lib/worktree.sh:604-608`).

## Dependencies and `_build`: copy-on-write cloning

`cow_assets` is the list of gitignored build/dependency directories cloned into each worktree. Its default is Elixir/Phoenix-shaped: `(_build deps assets/node_modules)` (`lib/config.sh:194`; also the tutorial, `docs/tutorial-phoenix.md:42-52`). `clone_assets` clones each one that exists under the golden checkout (`lib/cow.sh:91-104`).

The clone is a strategy chain, fastest first (`lib/cow.sh:5-12`, `55-78`):

1. `apfsclone` — a bundled C helper that does a single `clonefile(2)` syscall (macOS/APFS), atomic CoW (`scripts/apfsclone/apfsclone.c:1-11`). It builds itself from source on first use with `cc`, once per process, falling back to `cp` if there is no compiler (`lib/cow.sh:16-53`).
2. `cp -cR` — per-file `clonefile` on macOS.
3. `cp -a --reflink=auto` — reflink on Linux btrfs/XFS, silent plain copy elsewhere.
4. `cp -a` — plain copy, works everywhere.

A failed strategy removes its partial destination before the next runs, because `cp` into an existing directory nests instead of replacing (`_build/_build`) — the clone is idempotent for the same reason, so `fw refresh` clears the destination first (`lib/cow.sh:55-78`, `docs/architecture.md:26-30`). `fw refresh` re-clones a worktree's artifacts and stops any running server first so it never `rm -rf`s a live `_build` (`lib/cow.sh:80-89`).

There is no `mix deps.get` or `mix compile` anywhere in create — dependencies and compiled BEAM files arrive purely as a filesystem copy of the golden checkout's `deps` and `_build`. Recompilation, if needed, happens later when the developer runs `fw start` / `fw check` / `mix` in the worktree, not at create time.

The tutorial flags one Elixir-specific hazard the code cannot fix: a `mix.exs` dep given as a relative `path:` breaks in a worktree because `../` resolves to inside the worktrees directory, not the main checkout; the fix is an absolute path or a symlink (`docs/tutorial-phoenix.md:54-58`).

## Database: template clone, dev only

DB support is entirely presence-gated on `db_source`; unset, there are no database steps (`lib/db.sh:5`, `28`). When set, `db_create_for_worktree` clones with `createdb --strategy=file_copy -T <template> <db>` (`lib/db.sh:38`). The file_copy strategy copies the template's files directly instead of WAL-logging every block — the header cites ~0.5s vs ~7s for a 500MB DB on APFS, and notes it requires Postgres 15+ for the `--strategy` flag (`lib/db.sh:8-13`).

Config keys (`lib/config.sh:203-212`, defaults; `docs/tutorial-phoenix.md:78-100`):
- `db_source` — the dev database; setting it enables cloning, drop-on-delete, and `fw db`.
- `db_template` — a dedicated golden template to clone from, so a live dev-server connection to `db_source` never blocks or stalls the clone; falls back to `db_source` when unset (`lib/db.sh:33-37`).
- `db_prefix` — prefix for cloned DB names; defaults to `<project>_` (`lib/config.sh:396-397`).
- `db_setup_cmd` — a fallback (e.g. `mix ecto.setup`) run in the worktree env when the template clone fails (`lib/db.sh:48-56`).

Before cloning, it terminates connections to the template (`lib/db.sh:15-20`, `37`). A pre-existing target DB is treated as a stale-leftover error, not a fallback (`lib/db.sh:42-46`). On delete, `db_drop_for_worktree` drops the recorded DBs with `DROP DATABASE ... WITH FORCE` to avoid racing the worktree's own connection pool (`lib/db.sh:81-103`).

Code-vs-doc observation worth flagging: the env file records both `FW_DB_NAME` (dev) and `FW_TEST_DB_NAME` (test) (`lib/envfile.sh:108-117`), but `db_create_for_worktree` clones **only the dev DB** — `db="$(db_name_for_worktree "$name")"` with no `_test` suffix (`lib/db.sh:31`). So the test database name is allocated and written into the env, but the test DB itself is not created by fast-worktree. Creating and migrating the test DB is left to the project — either the `db_setup_cmd` fallback (`mix ecto.setup` covers both), a `hook_post_create`, or the developer running `MIX_ENV=test mix ecto.create`. The README/tutorial phrasing ("clones a fresh database") reads as if both are cloned; the code clones one. The tutorial's `hook_sync` keeps only the dev template migrated (`docs/tutorial-phoenix.md:90-96`).

## Ports: a slot, not a port

`fw` assigns each worktree a unique "port slot" in 100-999 (`FW_PORT_SLOT`), not a port. `allocate_port_slot` picks a random free slot, requiring the slot *and both neighbors* to be free, because hooks commonly derive several adjacent ports from one slot (`lib/envfile.sh:64-91`, `docs/architecture.md:104-112`). Slots are unique across **all registered projects**, not just the current one, since different projects' hooks may derive the same base port (`lib/envfile.sh:48-59`).

The project turns the slot into a real port in `hook_worktree_env`, whose output is appended to the env file (`lib/envfile.sh:124-126`). The canonical Phoenix example: `echo "PORT=$((4000 + FW_PORT_SLOT))"` (`docs/tutorial-phoenix.md:64-68`). `fw stop` frees ports; its default convention is any env key ending in `_PORT`, but Phoenix's bare `PORT` needs an explicit `stop_port_vars=(PORT)` allowlist (`lib/worktree.sh:216-230`, `docs/tutorial-phoenix.md:70-76`).

## Env and config: fw writes FW_*, the project derives the rest

fast-worktree writes only canonical `FW_*` keys into the env file — `FW_WORKTREE`, `FW_BRANCH`, `FW_PORT_SLOT`, and (when DB is on) `FW_DB_NAME` / `FW_TEST_DB_NAME` (`lib/envfile.sh:104-118`). The default env file path is `.env.worktree` at the repo root (`lib/config.sh:187`). The project's `hook_worktree_env` appends stack-shaped lines derived from those (`lib/envfile.sh:124-126`, `docs/architecture.md:100-113`).

A key limitation the tutorial makes explicit: **fw does not load the env file into your shell, and `mix` does not read it either** (`docs/tutorial-phoenix.md:103-111`). Two consequences:
- The app must read `PORT` and the DB names at runtime in `config/runtime.exs`, guarded so an unset var leaves defaults intact (`docs/tutorial-phoenix.md:113-133`).
- `fw start` and `fw check` are what apply the env-file keys: they run `start_cmd` / `check_cmd` through `_run_in_worktree_env`, which cds into the worktree, exports `FW_*`, sources the env file (`set -a`), and evals the command (`lib/run.sh:24-45`, `lib/hooks.sh:77-89`). Plain `mix phx.server` in the worktree sees none of it unless the project loads the file itself — the tutorial's optional path is the `dotenv_parser` Hex package loading `.env`/`.env.worktree` at the top of `runtime.exs` (`docs/tutorial-phoenix.md:135-162`).

Config is plain sourced bash across four layers (built-in defaults, global, repo, per-project; last wins), with hooks as ordinary functions that *chain* across layers rather than overriding (`docs/architecture.md:58-85`, `lib/hooks.sh:20-32`). The Elixir defaults from `config.sh`: `env_file=.env.worktree`, `cow_assets=(_build deps assets/node_modules)`, `branch_prefix=$USER` (`lib/config.sh:183-194`).

## How it is invoked

Install: clone the repo, put `fast-worktree` on `PATH`, alias it to `fw`, run `fw setup` once per machine (`README.md:27-64`). Then per repo:

- `fw init` — register the repo, write a commented config template (`docs/tutorial-phoenix.md:26-37`).
- `fw create <name>` — the pipeline above; supports `--base BRANCH|.`, `--model M`, `--claude PROMPT`, `--no-switch` (`fast-worktree:87`, `lib/worktree.sh:473`).
- `fw switch` / `sw`, `fw start`, `fw check`, `fw db`, `fw stop`, `fw refresh`, `fw regen-env`, `fw delete` — the daily loop (`docs/tutorial-phoenix.md:174-186`).
- `fw sync` — fast-forward trunk, run `hook_sync` (build/migrate steps), sync the stack backend; this is what keeps the golden checkout compiled and the template migrated so future creates stay fast (`lib/sync.sh:9-39`, `docs/tutorial-phoenix.md:90-96`).

The active project is derived from the working directory on every call, so there is no "active project" state (`docs/architecture.md:33-44`).

## Prerequisites

From `README.md:211-231` and the code:
- **bash 4+, git, tmux, fzf 0.45+** — the core set (`fast-worktree:10-22`, `README.md:217-220`).
- **PostgreSQL 15+** — only when `db_source` is set; 15+ specifically for `createdb --strategy` (`lib/db.sh:13`).
- **A C compiler** (`cc`, Xcode CLT) — only for the fast macOS clone helper; optional, with a `cp -cR` fallback (`lib/cow.sh:31-35`, `README.md:61-64`).
- **A CoW-capable filesystem** for the speed win — APFS on macOS, btrfs/XFS reflink on Linux; elsewhere the workflow works but copies are plain and slow (`README.md:213-215`, `lib/cow.sh:74-77`).
- **gh** for PR/CI commands, **Graphite (`gt`)** only when `stack_backend=graphite`, **fish** only for the shipped completions (`README.md:221-227`).
- Implicitly: a **golden checkout kept built and migrated**. The whole model assumes `deps`/`_build`/DB in the main checkout are current; `fw sync` is the maintenance command for that (`docs/architecture.md:9-24`).

## Trade-offs

1. **Copying `_build` vs recompiling.** Copying is near-instant on CoW filesystems and skips a cold `mix compile`, but the cloned `_build` reflects the golden checkout's source, not the worktree's branch. The first `mix`/`fw start` in the worktree recompiles only what changed (Elixir's incremental compile), so this is usually cheap — but a `_build` far behind the branch, or cross-version drift, means a larger recompile than a from-scratch build would suggest. The model leans entirely on keeping the golden checkout current via `fw sync`; a stale golden checkout degrades every clone. The code does nothing to detect or warn about staleness.
2. **CoW vs plain copy.** Off APFS/reflink filesystems the copy falls back to `cp -a`, which duplicates every byte of `deps`/`_build` per worktree — slow and disk-heavy (`lib/cow.sh:72-77`). The speed story is filesystem-dependent.
3. **Template DB clone.** `--strategy=file_copy` is fast but needs Postgres 15+ and forces a checkpoint before and after (negligible on an idle local template) (`lib/db.sh:8-13`). Cloning from a live `db_source` can stall on open connections, hence the recommended dedicated `db_template` (`README.md:135-141`). Only the dev DB is cloned; the test DB is the project's responsibility (see above).
4. **Env not auto-loaded.** Because fw does not export the env file into the shell, the app must be refactored to read config at runtime, and plain `mix` commands miss the worktree env unless the project adds `dotenv_parser`. This is real setup friction, not a drop-in (`docs/tutorial-phoenix.md:103-162`).
5. **Postgres-only, macOS-first.** DB cloning is Postgres-specific with no abstraction (`lib/db.sh`). The fast clone helper is Darwin-only C; Linux relies on reflink support being present.
6. **Personal tool.** The author states it is written primarily for personal use and is not looking for PRs (`README.md:17-25`, `233-237`) — adopt ideas, not necessarily the dependency.

## Worth adopting / skip (for custom Elixir worktree tooling)

**Adopt:**
- **CoW-clone `_build` + `deps` + `assets/node_modules` from a kept-built main checkout** rather than `mix deps.get` + `mix compile` per worktree. This is the core win and it is filesystem-native (`clonefile(2)` / `cp --reflink`), not tool-specific (`lib/cow.sh`, `scripts/apfsclone/apfsclone.c`).
- **Template-clone the dev DB** with `createdb --strategy=file_copy -T <template>` instead of dump/restore or `mix ecto.setup` per worktree — near-instant on a warm template (`lib/db.sh:26-58`).
- **Clone from a dedicated migrated template DB, not the live dev DB**, to dodge open-connection stalls (`README.md:135-141`).
- **A per-worktree port slot with neighbor-aware allocation**, deriving the real `PORT` in one place, plus reading `PORT`/DB in `runtime.exs` behind unset-guards (`lib/envfile.sh:64-91`, `docs/tutorial-phoenix.md:113-133`). This is the cleanest part to lift even without the tool.
- **The clear-partial-before-fallback idempotency rule** for copies, to avoid the nested-`_build` corruption bug (`lib/cow.sh:55-78`).
- **Rollback-on-failure discipline**: drop only the DB you created, delete only the branch you created (`lib/worktree.sh:437-458`).

**Skip / weigh:**
- The full 40-module bash tool, tmux session management, Claude/usage/Caddy/Graphite layers — far more than worktree-readiness, and it is an explicitly personal tool.
- The `dotenv_parser` env-loading approach is optional; a custom tool could instead export the env directly into the shell it launches, avoiding the "mix doesn't read the env" friction entirely.
- Remember to create/migrate the **test DB** yourself — fast-worktree does not.

## Ambiguities noted from the code

- **Test DB creation**: env records `FW_TEST_DB_NAME`, but no clone creates that DB (`lib/db.sh:31` vs `lib/envfile.sh:115`). The docs' "clones a fresh database" phrasing overstates what the clone step does.
- **`hook_post_create` failure is non-fatal in `create`**: unlike `pull`/`restore`, a failed post-create hook leaves the worktree live and only reports on the session's shell prompt (`lib/worktree.sh:604-608`, `627-648`). So a project that puts test-DB setup in `hook_post_create` can end up with a worktree that exists but is not fully DB-ready, without a hard failure.
- **Recompilation cost is unstated**: nothing in the code measures or bounds how stale a cloned `_build` is; "ready to run in a few seconds" (`README.md:8`) assumes the golden checkout is current and the incremental recompile on first `mix` is small.
