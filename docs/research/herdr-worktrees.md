# How Herdr handles worktrees

Research ticket: [zorn/dotfiles#40](https://github.com/zorn/dotfiles/issues/40). Sources are Herdr's own site and docs at [herdr.dev](https://herdr.dev/) and its open-source repo [herdrdev/herdr](https://github.com/herdrdev/herdr) (Rust, Apache-2.0). Community plugins are cited only where they demonstrate the first-party API surface, not as authority for it. Researched 2026-09-21.

## Bottom line

Herdr both creates worktrees itself and can discover worktrees that exist in the repo, and it exposes a first-party post-create hook — but the hook fires only for worktrees Herdr creates, not for worktrees created behind its back on the CLI. So custom init tooling has a clean idiomatic path only when the worktree is created through Herdr; a "standalone CLI that Herdr merely observes" gets observation but no automatic init trigger.

## What Herdr is

Herdr is "a runtime for coding agents" — a background server and terminal multiplexer that keeps agent sessions alive across restarts and machines ([herdr.dev](https://herdr.dev/)). Worktrees are one of the things it manages, exposed through its socket API and its plugin system rather than as a headline feature.

## Herdr creates and manages worktrees (documented)

The [Socket API](https://herdr.dev/docs/socket-api/) defines three worktree methods and three matching events:

- `worktree.create` "creates a checkout and returns the new `workspace`, `tab`, `root_pane`, and `worktree` records. If the requested branch already exists locally, it checks out that branch; otherwise it creates the branch from the requested base or `HEAD`."
- `worktree.open` "opens an existing checkout or returns the already-open workspace." It takes exactly one of `path` or `branch`.
- `worktree.remove` "runs `git worktree remove` against a linked child workspace and never deletes the branch."
- Events emitted: `worktree.created` (opened workspace + created worktree), `worktree.opened` (target workspace, opened worktree, `already_open`), `worktree.removed` (`workspace_id`, removed worktree, `forced`).

A created worktree becomes a Herdr workspace, and "Workspace responses include optional `worktree` provenance when a workspace belongs to a Herdr worktree group" ([Socket API](https://herdr.dev/docs/socket-api/)).

## Does Herdr detect a worktree created outside it?

Partly yes, by two documented mechanisms, but not through an automatic push into the UI.

1. Full-repo discovery. The [Socket API](https://herdr.dev/docs/socket-api/) states: "Attached worktree provenance is included on workspace records. Full repo worktree discovery remains `worktree.list`." Read against that contrast, `worktree.list` enumerates the repository's git worktrees rather than only the ones Herdr created — so a CLI-created worktree is visible to Herdr through that call.
2. Explicit open. `worktree.open` with a `path` "opens an existing checkout," which is how an existing on-disk worktree becomes a Herdr workspace.

What is NOT documented, and matters for the ticket: whether Herdr's TUI automatically surfaces CLI-created worktrees without an explicit `worktree.open`, and how reliably it recognizes their provenance. The repo shows this is an active, not-yet-settled area. Issue [herdrdev/herdr#729](https://github.com/herdrdev/herdr/issues/729) ("worktree create should check out existing local branches") and related discussion note that "a workspace opened from a real Git linked worktree should preserve a durable/canonical worktree identity that `worktree.remove` can later resolve," and that "reopening a historical linked checkout must not downgrade it to an ordinary workspace merely because Herdr did not create the checkout in the current session." That wording is evidence the externally-created case is handled imperfectly and is being hardened.

## Is there a post-create hook / extension point?

Yes — the plugin event system, which is the intended extension point for project-specific init. Per the [Plugins docs](https://herdr.dev/docs/plugins/), a plugin manifest subscribes to events:

```toml
[[events]]
on = "worktree.created"
command = ["herdr", "workspace", "list"]
```

The hook command receives context through environment variables: "event hooks additionally receive `HERDR_PLUGIN_EVENT_JSON`," and "`HERDR_PLUGIN_CONTEXT_JSON` can include workspace, tab, focused pane, worktree, agent, selected text, clicked URL, and link handler fields when they are available for that invocation" ([Plugins docs](https://herdr.dev/docs/plugins/)). So a plugin can run an arbitrary command — e.g. an Elixir `mix deps.get` / setup step — against the freshly created worktree, with the worktree's path available in the context JSON.

This is exactly what multiple community plugins do on the `worktree.created` event: copy gitignored files, symlink shared paths, install deps, and run configurable post-create commands (for example [lamngockhuong/herdr-worktree-setup](https://github.com/lamngockhuong/herdr-worktree-setup), [piesuke/herdr-worktree-bootstrap](https://github.com/piesuke/herdr-worktree-bootstrap), and the generic [freethinkel/herdr-plugin-git-worktree-hooks](https://github.com/freethinkel/herdr-plugin-git-worktree-hooks)). They confirm the hook is real and usable; the authority for the mechanism is Herdr's own plugin docs above.

The decisive nuance: `worktree.created` fires from `worktree.create`, i.e. when Herdr makes the worktree. A worktree made on the CLI produces no `worktree.created`; the most Herdr would emit is `worktree.opened` when someone later opens it. So the native post-create hook triggers only for Herdr-created worktrees.

## What this means for the three options in the ticket

1. Standalone CLI that Herdr merely observes — weakest fit. Herdr can see the CLI-made worktree via `worktree.list` and can open it, but no first-party hook fires on external creation, so the init step would not run automatically. The CLI would have to run its own init.
2. Init step layered onto Herdr-created worktrees, via a hook Herdr invokes — best fit and idiomatic. Create the worktree through Herdr (`worktree.create`), and let a plugin on `worktree.created` run the Elixir setup with the worktree path from `HERDR_PLUGIN_CONTEXT_JSON`. This is precisely the pattern the existing worktree plugins implement.

Options 2 and 3 in the ticket collapse into the same Herdr-native answer: the "init step" is delivered as the "hook Herdr invokes."

## Open / unresolved (not settled by docs)

1. Automatic UI surfacing of external worktrees. Docs confirm `worktree.list` does "full repo worktree discovery," but do not state whether the TUI automatically lists CLI-created worktrees without an explicit `worktree.open`, or only shows Herdr workspaces. Unknown.
2. Provenance fidelity for external worktrees. `worktree.open` on an existing checkout may not preserve durable worktree identity/provenance the way a Herdr-created one does; issue #729 indicates this is imperfect and in flux. Unknown how it behaves today.
3. Hook coverage for the external case. The plugin docs show only `worktree.created` by example. The API also emits `worktree.opened`, but the docs do not confirm plugins can subscribe to `worktree.opened` (or `worktree.removed`) to run init when an external worktree is opened. Unknown.

### Empirical tests a human can run to close these

- Create a worktree with plain `git worktree add ../wt-foo`, start/attach Herdr on that repo, and observe whether `wt-foo` appears in the TUI unprompted, and whether `worktree.list` returns it. Answers open item 1.
- Open that external worktree via `worktree.open` (by path), then run `worktree.remove` and check whether Herdr resolves it cleanly and reports worktree provenance on the workspace record. Answers open item 2.
- Add a plugin manifest with `on = "worktree.opened"` running a marker command; open an external worktree and see whether the command runs. Answers open item 3.
