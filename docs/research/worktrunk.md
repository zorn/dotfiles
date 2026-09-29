# Research: worktrunk (`wt`) as the worktree tool

Background for [#46 "Evaluate worktrunk as the worktree tool"](https://github.com/zorn/dotfiles/issues/46), feeding the build-vs-adopt synthesis in [#39](https://github.com/zorn/dotfiles/issues/39). Primary sources only — the [worktrunk.dev](https://worktrunk.dev/) docs and the [max-sixty/worktrunk](https://github.com/max-sixty/worktrunk) source (MIT OR Apache-2.0, Rust). Where a claim rests on inference rather than a document, it says so.

The headline: **worktrunk plus a project `post-start` hook can replace a bespoke worktree CLI, but not the Elixir readiness policy inside it.** worktrunk owns the plumbing — worktree create/list/remove/merge, copy-on-write copying of gitignored files, deterministic per-worktree ports, config layering, and create/remove lifecycle hooks. What it does *not* give you is anything Elixir-aware: no database clone, no `mix`/`ecto` steps, no `_build` staleness handling. Those become the ~dozen lines of hook you still write. Notably, the Leopardi copy-script this whole map is built around ([#42](https://github.com/zorn/dotfiles/issues/42)) *is already* a worktrunk `post-create` hook — so adopting worktrunk is adopting the thing his setup already runs.

One naming correction up front: the canonical create-time hooks are **`pre-start` / `post-start`**, not `post-create`. The ticket's `[post-create]` still works — `pre-create`/`post-create` are accepted as silent backward-compatibility aliases in the source — but the documented name is `post-start`.

---

## 1. Readying a worktree

### The hook model

worktrunk runs shell commands at lifecycle points. Each event has a blocking `pre-` form and a background `post-` form ([hook docs](https://worktrunk.dev/hook/)):

| Event | `pre-` (blocking, failure aborts) | `post-` (background, output logged) |
| --- | --- | --- |
| switch | `pre-switch` | `post-switch` |
| **create** | **`pre-start`** | **`post-start`** |
| commit | `pre-commit` | `post-commit` |
| merge | `pre-merge` | `post-merge` |
| remove | `pre-remove` | `post-remove` |

The create event is the readiness event. `pre-start` "runs once when a new worktree is created, blocking `post-start`/`--execute` until complete"; `post-start` "runs once when a new worktree is created, in the background" with output logged unless run `--foreground` ([hook docs](https://worktrunk.dev/hook/)). The internal enum in [`src/cli/hook.rs`](https://github.com/max-sixty/worktrunk/blob/main/src/cli/hook.rs) names these variants `PreCreate`/`PostCreate` but maps them to the canonical config strings `pre-start`/`post-start`, keeping `pre-create`/`post-create` as undocumented aliases — so both spellings resolve to the same hook.

Hooks take three forms ([hook docs](https://worktrunk.dev/hook/)): a single command string, a table of named commands that run **concurrently**, or an array-of-tables that runs as a **sequential pipeline**. The pipeline form matters for Elixir because DB-name-then-DB-launch has to be ordered:

```toml
[[post-start]]
install = "mix deps.get"

[[post-start]]
build  = "mix compile"
server = "mix phx.server"
```

`pre-` hooks run user hooks first, then project hooks; a failing `pre-` hook aborts the operation. Project hooks require an approval on first run (saved to `~/.config/worktrunk/approvals.toml`); user hooks need no approval. `wt hook <type>` triggers a hook on demand, and `--yes` / `--no-hooks` bypass approvals or skip hooks in CI ([hook docs](https://worktrunk.dev/hook/)).

Templates are minijinja/Jinja2. Useful variables: `{{ branch }}`, `{{ worktree_path }}`, `{{ repo }}`, `{{ repo_path }}`, `{{ primary_worktree_path }}`, and `{{ vars.<key> }}` (per-branch state). Filters that carry the Elixir-relevant work: `sanitize` (path-safe branch), `sanitize_db` (DB-safe identifier, max 48 chars with a hash suffix), `hash_port` (deterministic port in **10000–19999**), and `codename(n)` (friendly names) ([hook docs](https://worktrunk.dev/hook/)).

### `wt step copy-ignored` + `.worktreeinclude`

This is worktrunk's answer to copying `_build`/`deps` — the exact job the Leopardi script and fast-worktree's `cow_assets` do. `wt step copy-ignored` "transfers gitignored files between worktrees to eliminate cold starts" and is "the centerpiece for managing build caches and dependencies" ([step docs](https://worktrunk.dev/step/)). It **reflinks** (copy-on-write) where the filesystem supports it — APFS on macOS, btrfs/XFS on Linux, ReFS on Windows — so a large directory shares disk blocks until one side writes; the docs cite a 14GB `target/` copied in ~20s with ~0 extra disk. On ext4/NTFS (no reflink) every file is copied fully ([step docs](https://worktrunk.dev/step/)). On the user's macOS/APFS machine this is the same CoW mechanism fast-worktree relies on.

`.worktreeinclude` filters *which* gitignored files copy — gitignore-style patterns, and a file copies only if it is both gitignored **and** matched ([step docs](https://worktrunk.dev/step/)). Without the file, `copy-ignored` copies *all* gitignored files. `[step.copy-ignored] exclude = [...]` in config subtracts further, and `wt step copy-ignored --require-include` makes the file mandatory (the docs note this "matches Claude Code desktop behavior"). The wiring is a one-liner:

```toml
[post-start]
copy = "wt step copy-ignored"
```

The docs give language-specific notes for Rust (`target/`), Node (`node_modules/`, which they suggest *symlinking* instead), and Python (venvs "contain absolute paths and cannot be copied" — use `uv sync`). **There is no Elixir note.** Whether copied `_build`/`deps` carry absolute paths that break relocation into a sibling worktree directory is **not documented** — treat it as untested for Elixir rather than assume it works. (In practice Elixir `deps`/`_build` are generally relocatable across sibling paths, but the docs make no claim, so verify before relying on it.)

### Global vs per-project config

Two layers ([config docs](https://worktrunk.dev/config/)):

- **User / global**: `~/.config/worktrunk/config.toml` (or `$XDG_CONFIG_HOME`). Personal, not committed, applies to all repos.
- **Project**: `.config/wt.toml`. Committed and shared with teammates, scoped to the repo.

Precedence, high to low: `--config-set` inline > `WORKTRUNK_`-prefixed env vars > `[projects."owner/repo"]` entries inside the user config > global user config > a system-wide file. Config keys are kebab-case; env vars are `SCREAMING_SNAKE_CASE` with `__` for nested sections ([config docs](https://worktrunk.dev/config/)). The Elixir readiness logic belongs in the committed project `.config/wt.toml` so it travels with the repo — which is exactly where Leopardi keeps his ([#42](https://github.com/zorn/dotfiles/issues/42)).

Per-branch state is first-class: `wt config state vars set key=value` stores values (in git config as `worktrunk.state.<branch>.*`) that later hooks read as `{{ vars.key }}` ([config docs](https://worktrunk.dev/config/)). This is how a DB name and port computed at create time survive to later pipeline steps and to the remove hook.

### Built-in handling of deps / `_build` / ports / database

This is the crux, and the answer is **mechanism, not policy** — worktrunk supplies generic primitives, none of them Elixir-aware:

- **deps / `_build`**: no language awareness. Handled generically by `copy-ignored` + `.worktreeinclude` (CoW reflink). There is **no "golden built checkout"** concept — worktrunk copies from the *source* worktree (typically primary) at create time, so a new worktree inherits whatever primary has compiled right now. No `_build` staleness detection.
- **ports**: the `hash_port` filter yields a deterministic port in 10000–19999 from any string ([hook docs](https://worktrunk.dev/hook/)). It is a **hash, not a slot** — not `4000 + N` sequential, and there is no reservation or collision tracking beyond determinism. You inject it into the app yourself (`PORT={{ branch | hash_port }}` in a dev-server command or an env line). Mapping to Phoenix's conventional 4000 is on you.
- **database**: **no built-in DB command.** The [tips-patterns doc](https://worktrunk.dev/tips-patterns/) documents a per-worktree DB only as a *pattern you assemble* — a `post-start` pipeline that (1) sets `vars` for container name, port (`{{ ('db-' ~ branch) | hash_port }}`), and `db_url` (`{{ branch | sanitize_db }}`), then (2) `docker run` a fresh `postgres:16`, and cleans up on remove with `docker stop {{ vars.container }}`. That spins up an **empty** database — you still run `ecto.create`/`migrate`/`seed`. There is **no template-database clone** (`createdb --template`) built in.
- **env**: no dedicated handling. Copy a stable `.env` via `copy-ignored`, or generate one in `pre-start`. The `WORKTRUNK_` env prefix configures worktrunk itself, not the app.

---

## 2. Relation to Herdr

**Complementary in the main, with a narrow overlap on worktree creation.** Herdr ([herdrdev/herdr](https://github.com/herdrdev/herdr), "the runtime your coding agents live on") is a terminal multiplexer and agent orchestrator — panes, tabs, workspaces, agent lifecycle. worktrunk is the worktree lifecycle and readiness engine. Different centers of gravity.

The overlap: **both can create worktrees.** Herdr's [CLI reference](https://herdr.dev/docs/cli-reference/) documents `herdr worktree create`, which "creates a Git worktree checkout, opens it as a workspace, and groups it with the parent repo workspace" (running `git worktree add` under the hood), plus `worktree remove` and `worktree open`. So in a combined setup you choose *one* creator.

The official docs of neither tool cross-reference the other: [worktrunk.dev/claude-code](https://worktrunk.dev/claude-code/) never mentions Herdr, and [herdr.dev's CLI reference](https://herdr.dev/docs/cli-reference/) never mentions worktrunk. The integration is community-built — there are Herdr plugins that wire in worktrunk ([devashish2203/herdr-worktrunk](https://github.com/devashish2203/herdr-worktrunk), [unfixed3854/herdr-worktrunk](https://github.com/unfixed3854/herdr-worktrunk)) and a shared "Herdr + worktrunk" layout ([simoncrypta/agentic-dev-setup](https://github.com/simoncrypta/agentic-dev-setup)) — which is consistent with the ticket's premise that Leopardi runs them together.

**Can a worktrunk-created worktree be surfaced/opened in Herdr?** Partly, and with a documented caveat from the sibling research. Herdr's CLI has `herdr worktree open [--cwd PATH]`, which opens a workspace at a path — so a `wt`-created worktree can be opened by path (documented capability). But per [#40](https://github.com/zorn/dotfiles/issues/40), Herdr fires its `worktree.created` plugin hook **only for worktrees Herdr itself creates**; a CLI-made worktree is *observable* (`worktree.list`/`worktree.open`) but gets **no auto-init trigger**. So a `wt`-created worktree can be viewed and opened in Herdr, but it will not fire Herdr's creation hook — the readiness has to come from worktrunk's own `post-start` hook, not from Herdr. (This is the finding of #40, not a worktrunk doc claim; some external-worktree behaviors there remain untested.) The idiomatic combined path is therefore: let **one** tool create — either create through Herdr and run Elixir init from `worktree.created`, or create through `wt` and run init from `post-start` — not both.

---

## 3. Bottom line: could this replace custom tooling, and what is the gap?

### worktrunk vs fast-worktree for Elixir worktree readiness

| Capability | worktrunk (`wt`) | fast-worktree (`fw`) |
| --- | --- | --- |
| CoW copy of `_build` / `deps` / `node_modules` | Yes — `wt step copy-ignored` + `.worktreeinclude`, reflink on APFS/btrfs/XFS ([step docs](https://worktrunk.dev/step/)) | Yes — `cow_assets=(_build deps assets/node_modules)`, reflink ([fw README](https://github.com/axelson/fast-worktree)) |
| Source of the copy | The source worktree (usually primary), as-is now | A kept-built **golden checkout** ([#41](https://github.com/zorn/dotfiles/issues/41)) |
| `_build` staleness handling | None documented | None (called out as a watch-item in [#41](https://github.com/zorn/dotfiles/issues/41)) |
| Per-worktree database | **Pattern only** — DIY `docker run` fresh empty Postgres via `post-start` + `vars`; no template clone ([tips-patterns](https://worktrunk.dev/tips-patterns/)) | **First-class** — `db_source` + optional `db_template`, template-clones the dev DB ([fw README](https://github.com/axelson/fast-worktree)) |
| Test DB | Not handled (your job) | Not handled — dev DB only ([#41](https://github.com/zorn/dotfiles/issues/41)) |
| Ports | `hash_port` filter, deterministic hash in 10000–19999 ([hook docs](https://worktrunk.dev/hook/)) | Sequential **port slots**, e.g. `PORT=$((4000 + FW_PORT_SLOT))` ([fw README](https://github.com/axelson/fast-worktree)) |
| Env / agent config copying | Via `copy-ignored` (if stable) or generate in `pre-start` | Via `cow_assets` / hooks |
| Lifecycle hooks | Full set: `pre/post` for switch, create, commit, merge, remove ([hook docs](https://worktrunk.dev/hook/)) | `hook_*` functions ([fw README](https://github.com/axelson/fast-worktree)) |
| Teardown symmetry | Hook points exist (`pre-remove`/`post-remove`); DB drop / port free are DIY | `fw delete`; DB/port teardown per its hooks |
| Elixir / Phoenix / `mix` / `ecto` awareness | **None** — generic shell in hooks | None built in, but ships a **Phoenix example config** ([fw README](https://github.com/axelson/fast-worktree)) |
| Merge / PR / commit workflow | Rich — `wt merge`, LLM commit messages, PR checkout, CI status in `wt list` ([config docs](https://worktrunk.dev/config/)) | Not its focus |
| Config layering | Global `~/.config/worktrunk/config.toml` + committed project `.config/wt.toml` + precedence chain ([config docs](https://worktrunk.dev/config/)) | Shell config with `hook_*` functions |
| License / language | MIT OR Apache-2.0, Rust | Shell |

### Could adopting worktrunk + a post-create hook replace building custom Elixir worktree tooling?

**Yes for the engine; no for the Elixir readiness policy.** Adopt worktrunk as the worktree engine and write the Elixir logic as a committed project `.config/wt.toml`:

- a `post-start` pipeline: `wt step copy-ignored` (for `_build`/`deps`/env/agent config), compute `PORT` from `hash_port`, create/clone the DB, then `mix ecto.setup`;
- a `pre-remove`/`post-remove` hook for teardown (drop DB, stop container, free the port).

That replaces building a bespoke worktree CLI outright — you inherit create/list/remove/merge, CoW copying, port hashing, config layering, approvals, and the whole `wt merge`/PR/CI surface for free. And it is not speculative: Leopardi's copy-script *is* this hook ([#42](https://github.com/zorn/dotfiles/issues/42)).

**What it will NOT cover for Elixir/Phoenix — the gap you still own:**

1. **Database clone.** worktrunk has no template-DB clone; its documented pattern gives you an *empty* Postgres per branch. fast-worktree's `db_source`/`db_template` (a `createdb --template` of the built dev DB) is the piece worth keeping, and you would reproduce it as a hook command yourself. The test DB is unhandled by both.
2. **Elixir readiness itself.** No `mix deps.get`, `mix compile`, `ecto.create`/`migrate`/`seed`, or `_build` staleness check exist as primitives — you write each as a hook step.
3. **Port ergonomics.** `hash_port` is a hash in 10000–19999, not a `4000 + N` slot, with no reservation/collision tracking. Functional, but you map it to Phoenix conventions yourself.
4. **`_build` relocation is undocumented for Elixir.** worktrunk documents reflink caveats for Rust/Node/Python but says nothing about Elixir `_build`/`deps` carrying absolute paths across sibling worktree dirs. Verify before relying on the copy; do not assume.
5. **Teardown logic.** The hook *points* exist (`pre-remove`/`post-remove`), but the Elixir teardown (drop DB, stop container, free port) is code you write — the teardown symmetry #39 lists as unspecified is enabled, not solved, by worktrunk.

Net: worktrunk replaces the *plumbing*, shrinking the custom tooling from "a worktree CLI" to "a project `.config/wt.toml` hook of roughly a dozen lines" — with the database-template clone as the one fast-worktree idea worth porting into that hook.
