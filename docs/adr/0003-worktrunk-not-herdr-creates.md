# Worktrunk, Not Herdr, Creates

> **Refined by [ADR 0004](0004-worktree-values-in-an-env-file.md)** — the common Elixir setup runs in the global config's blocking `pre-start`, not a per-repo `post-start`, and a repo's own config adds only its database step.

> **Correction:** the upstream issue for Herdr's handling of externally created worktrees is [herdrdev/herdr#2981](https://github.com/herdrdev/herdr/issues/2981), closed as a feature request: Herdr does not detect them, and `herdr worktree open` attaches one. The [herdrdev/herdr#729](https://github.com/herdrdev/herdr/issues/729) cited below is an unrelated fix that shipped in 0.7.1.

The Elixir/Phoenix worktree tooling uses worktrunk (`wt`) to create worktrees, and Herdr — the agent/pane TUI — attaches to a worktree after the fact rather than creating it. Researching Herdr ([issue #40](https://github.com/zorn/dotfiles/issues/40)) surfaced a Herdr-native path: create the worktree in Herdr and run the Elixir init from a `worktree.created` plugin hook. Researching worktrunk ([issue #46](https://github.com/zorn/dotfiles/issues/46)) showed worktrunk already owns the plumbing that path would have us rebuild — create/list/remove/merge, copy-on-write copying of `_build`/`deps`, deterministic ports (`hash_port`), DB-safe names (`sanitize_db`), config layering, and a `remove` hook for teardown — so we let worktrunk create and Herdr observe. Settled in [issue #45](https://github.com/zorn/dotfiles/issues/45).

## Consequences & Tradeoffs

The rejected alternative was Herdr-native creation. It reads well because Herdr is the agent runtime the worktrees live in, but choosing it means reimplementing worktrunk's plumbing by hand, and it mixes creators at a moment when Herdr's handling of externally-created worktrees is still being hardened upstream (herdrdev/herdr#729) — a worktree worktrunk made, opened in Herdr, is exactly that external case. Picking one creator, and picking the one that already carries the plumbing, avoids both.

The cost lands in two places. Herdr's `worktree.created` hook goes unused, so a worktree spun up from inside Herdr's TUI gets no init — the workflow standardizes on `wt` to create, then attach in Herdr. And the Elixir init lives in a committed per-repo `.config/wt.toml` `post-start` hook (a shell script with an explicit shebang; worktrunk runs hooks under a fixed `sh -c`, never the login shell, so a fish default shell does not touch them), backed by a global worktrunk config layer kept in this dotfiles repo.
