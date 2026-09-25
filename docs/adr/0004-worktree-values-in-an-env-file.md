# Worktree Values in an Env File

A worktree's port and database names are computed when `wt` creates it, but they are needed later, when someone runs `mix phx.server` or `mix test` in a shell that worktrunk never touches. worktrunk has no way to push a value into that later shell, and it passes its hooks no environment variables either. So the hooks write the values into a gitignored `.env.worktree` at the worktree root, as plain `KEY=VALUE` lines, and the app's `config/runtime.exs` reads that file when it exists. [fast-worktree](https://github.com/axelson/fast-worktree) uses the same file name and the same shape. Settled in [issue #51](https://github.com/zorn/dotfiles/issues/51#issuecomment-5841005506).

## Consequences & Tradeoffs

Two alternatives were rejected. direnv (or mise) reads well because it is the usual tool for per-directory environments, but coding agents run `mix test` in non-interactive shells that never load it, which is exactly the case this tooling exists for. It also needs a `direnv allow` in every new worktree. Calling `wt step eval` from `runtime.exs` would recompute the values without any file, but then every `mix` run in the repo depends on worktrunk being installed.

The cost lands on each adopting app. It adds a few lines to `runtime.exs` and a line to `.gitignore`, and it must treat a missing file as "use the defaults", which is what keeps the primary checkout on its usual port and database. It also creates an ordering rule: the database names must land in the file during the blocking `pre-start`, not the background `post-start`. Otherwise a `mix` run in a half-ready worktree falls back to the primary database and migrates it.
