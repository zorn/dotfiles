# Worktrees with worktrunk

A runbook for running several copies of a Phoenix app side by side, one per git worktree, so parallel coding agents never share a port or a database. [worktrunk](https://worktrunk.dev) (`wt`) creates and removes each worktree, and its hooks ready it and tear it down. [Herdr](https://herdr.dev) is where you work in it. [ADR 0003](../docs/adr/0003-worktrunk-not-herdr-creates.md) and [ADR 0004](../docs/adr/0004-worktree-values-in-an-env-file.md) record why the pieces fit this way.

## Create and remove only through `wt`

The hooks run only when `wt` creates or removes a worktree. A worktree made another way comes up without its build state, port, or databases. A worktree removed another way leaves its databases behind, with nothing left that records their names. Removing another way includes `git worktree remove`, Herdr's "Delete worktree checkout", and deleting the directory.

## Set up each machine once

1. Install worktrunk and jq: `brew install worktrunk jq`. The teardown uses jq to find a worktree's Herdr workspace.
2. Run `bin/link` from this repo. It links `config.toml` and `hooks/` into `~/.config/worktrunk/`. Run it before anything else writes a worktrunk config. `bin/link` never overwrites a real file, so it would skip the config, and the tracked config would never load.
3. Run `wt config shell install fish`. It lets `wt switch` change your shell into the new worktree. It creates `functions/wt.fish` and `completions/wt.fish` under `~/.config/fish/`. This repo does not track those files, so repeat this step on each machine.

The first time `wt` runs a repo's own hooks, it asks you to approve them.

## Run the flow

**1. Create.** In Herdr, open a console in the repo's workspace, at the primary checkout, and run:

```sh
wt herdr <branch>
```

That creates the worktree and opens it in Herdr as its own workspace. Before `wt` returns, the hooks copy `_build` and `deps`, and write the worktree's port and database names to `.env.worktree`. The databases are then created and migrated in the background. `wt config state logs get` lists the log files, and that step's log is `post-start/postgres.log`.

Keep the repo workspace's consoles out of the worktree directory. In Herdr 0.9.x, if one of them is inside the worktree, `herdr worktree open` can take over the repo's workspace instead of opening a new one ([herdrdev/herdr#4293](https://github.com/herdrdev/herdr/issues/4293)). `wt herdr` passes `--no-cd` to `wt switch` for this reason.

Outside Herdr, use `wt switch --create <branch>`, which changes your shell into the new worktree.

**2. Work.** Drive the agent in the new Herdr workspace. `mix phx.server` serves on the worktree's own port, which is `PORT` in `.env.worktree`. `mix test` runs against the worktree's own test database.

**3. Remove.** From the repo's console, run:

```sh
wt remove <branch>
```

The hook closes the worktree's Herdr workspace, which also stops anything still running in it. It then drops the worktree's dev and test databases and clears its stored database names and port. `wt` removes the worktree last, and deletes the branch when it is merged. `wt merge` runs the same teardown, because it removes the worktree too. Run from a console in the worktree's own workspace, either command leaves that workspace open, because closing it would stop `wt` mid-removal. Close it yourself afterward.

## When removal stops

When removal stops, the worktree and its databases stay in place. Only uncommitted changes stop it before the hook runs. Every other stop comes after the hook has closed the worktree's Herdr workspace, so reopen it with `herdr worktree open --path <worktree>` if you need it. Each message says what to do.

| Message | What to do |
| --- | --- |
| `has uncommitted changes` | Commit or stash them, or run `wt remove --force <branch>` to discard them. |
| `could not drop the databases for this worktree` | A session is still connected, or the code does not compile. Close the session or fix the code, then retry. |
| `stored under branch <name>, but it is not on that branch now` | In the worktree, run `git switch <name>`, then retry. |
| `no branch stores their names` | Run the printed `wt remove --no-hooks` and the two `mix ecto.drop` commands. |

To give up on the teardown, `wt remove --no-hooks <branch>` removes the worktree without it. First note the database names, which are in the worktree's `.env.worktree`. Afterward, close the worktree's Herdr workspace, and drop both databases from the primary checkout:

```sh
DEV_DATABASE_NAME=<dev name> mix ecto.drop
MIX_ENV=test TEST_DATABASE_NAME=<test name> mix ecto.drop
```

## Opt a Phoenix app in

An app opts in with four changes in its own repo. [zorn/flick#194](https://github.com/zorn/flick/pull/194) shows each one.

- **`.worktreeinclude`** lists the gitignored files a new worktree needs: `_build/`, `deps/`, `assets/node_modules/`, and `.claude/settings.local.json`.
- **`.config/wt.toml`** calls `hooks/postgres names` in `[pre-start]` and `hooks/postgres create` in `[post-start]`. The header of [`hooks/postgres`](hooks/postgres) shows the exact lines. An app without a database leaves this file out.
- **`config/runtime.exs`** reads `.env.worktree` in dev and test. It uses `PORT`, `DEV_DATABASE_NAME`, and `TEST_DATABASE_NAME` when present, and keeps its defaults when the file is absent.
- **`.gitignore`** ignores `/.env.worktree`.

## What is here

- [`config.toml`](config.toml) registers the hooks and the `wt herdr` alias.
- [`hooks/pre-start`](hooks/pre-start) copies build state and writes the port, for any repo with a `mix.exs`.
- [`hooks/postgres`](hooks/postgres) names, creates, and drops per-worktree databases for an app that opts in.
- [`hooks/herdr`](hooks/herdr) closes a worktree's Herdr workspace.
- [`hooks/pre-remove`](hooks/pre-remove) runs the Herdr close, the database drop, and the port clear.
