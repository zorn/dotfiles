# Worktree Values in an Env File

`wt` computes a worktree's port and database names when it creates the worktree, but `mix phx.server` and `mix test` need them later, in a shell that worktrunk never touches. worktrunk cannot set a variable in that later shell, so its hooks write the values into a gitignored `.env.worktree` at the worktree root. The app's `config/runtime.exs` reads that file when it exists.

## Consequences & Tradeoffs

[fast-worktree](https://github.com/axelson/fast-worktree) uses the same file name and shape. The decision was settled in [issue #51](https://github.com/zorn/dotfiles/issues/51#issuecomment-5841005506).

Two alternatives were rejected. direnv (or mise) looks like the obvious choice, because it is the usual tool for per-directory environments. But coding agents run `mix test` in non-interactive shells that never load it, and those shells are exactly the case this tooling exists for. It also needs a `direnv allow` in every new worktree. Calling `wt step eval` from `runtime.exs` would recompute the values without any file, but then every `mix` run in the repo depends on worktrunk being installed.

The cost lands on each adopting app. The app adds a few lines to `runtime.exs` and a line to `.gitignore`. It must also treat a missing file as "use the defaults", which keeps the primary checkout on its usual port and database.

This refines [ADR 0003](0003-worktrunk-not-herdr-creates.md), which put the Elixir setup in a per-repo `post-start` hook. worktrunk starts user and project `post-start` hooks together, so neither can rely on the other. The common setup therefore runs in the global config's blocking `pre-start`, and it writes the port. A repo that wants its own databases adds their names in its own `pre-start`, which runs after the global one. The names must land before `wt` returns. Otherwise a `mix` run in a half-ready worktree falls back to the primary database and migrates it. Only creating and migrating the databases runs in the background `post-start`.
