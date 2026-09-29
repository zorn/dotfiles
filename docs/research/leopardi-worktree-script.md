# The Leopardi worktree script

**Ticket:** [zorn/dotfiles#42](https://github.com/zorn/dotfiles/issues/42) — "The Leopardi worktree script"
**Sources:** [whatyouhide/dotfiles](https://github.com/whatyouhide/dotfiles) pinned at commit `5c0059ea4110906e31d70ed90c56c40c3dac2270`; worktrunk docs at [worktrunk.dev](https://worktrunk.dev/). whatyouhide is Andrea Leopardi.

## Bottom line

The exact copy-script from the talk is **not** in the public `whatyouhide/dotfiles` repo. That repo carries the *machine* setup, not the *per-project* worktree hooks. What the talk showed is a worktrunk **post-create hook**, and those live in each project's own `.config/wt.toml` — a file that ships with the Elixir app, not with the dotfiles. The dotfiles do confirm the whole surrounding toolchain: worktrunk (`wt`), herdr, direnv, the linear CLI, Claude Code, and Mix. So I cannot quote the talk script line-for-line from a primary source, and I say so plainly below. Everything about *which tool owns each copied artifact* is grounded in the dotfiles; the copy list itself is taken from the talk screenshot described in the ticket.

## What is in the dotfiles (primary source, quoted)

The dotfiles install and wire up worktrunk, but they do not contain the copy list. Three files carry the evidence.

The shell integration that turns on the `wt` command, `zsh/config.zsh:49-50`:

```zsh
# Worktrunk
if command -v wt > /dev/null 2>&1; then eval "$(command wt config shell init zsh)"; fi
```

The Homebrew install of the worktree tooling, `homebrew/Brewfile:240-242` and `:241`:

```ruby
# CLI for Git worktree management, designed for parallel AI agent workflows
brew "worktrunk"
```

herdr — the worktree/agent TUI — is installed and configured too (`homebrew/Brewfile`, `herdr/config.toml`), with worktree keybindings and a worktree directory setting commented in `herdr/config.toml:76-78` and `:139-140`. herdr is the pane manager that runs agents across worktrees; worktrunk is the tool that creates the worktrees and runs the setup hook.

No file in the repo references `_build`, `deps`, `.envrc`, `dev.env`, `.linear.toml`, `.mcp.json`, `.claude/settings.local.json`, or `local-bin` as a copy source. I grepped the full tree at the pinned commit. The only hits for those names are the linear CLI in `homebrew/Brewfile` and `claude/permissions.json`, and the herdr worktree comments — none of them a copy script.

## How worktrunk runs the script (mechanism)

worktrunk configures hooks in two places: a global `~/.config/worktrunk/config.toml` and a per-project `.config/wt.toml` ([worktrunk.dev/config](https://worktrunk.dev/config/), [worktrunk.dev/hook](https://worktrunk.dev/hook/)). A `[post-create]` hook runs after a new worktree is cut. worktrunk also ships `wt step copy-ignored`, which copies gitignored files from the main checkout into the new worktree and can be narrowed with a `.worktreeinclude` file. The talk's explicit copy list is the hand-written version of that same idea: copy the files a fresh `git worktree add` does not bring across, because a worktree checks out tracked files only and starts with an empty gitignored surface.

So the script lives in the *project* repo as a post-create hook, and the dotfiles' job is only to make `wt` exist and be shell-initialized. That split is why it is absent here.

## The copy list and why each artifact is copied, not regenerated

The list below is the one shown in the talk screenshot, as recorded in the ticket. Each row copies from `$MAIN` (the primary checkout) into the new worktree. The rationale is the same for all of them: the artifact is gitignored, so a bare worktree does not have it, and rebuilding it is either slow, network-bound, or impossible offline. Copying is a filesystem operation measured in seconds; regenerating is measured in minutes and often needs credentials.

| Artifact | What it is | Why copy, not regenerate |
|---|---|---|
| `.envrc` | direnv entry file that loads the project env on `cd`. The dotfiles hook direnv in `zsh/config.zsh:46`. | Gitignored per-checkout config. Copying gives the worktree a working shell env immediately; regenerating means re-deriving local values by hand. |
| `dev.env` | The actual dev environment variables (DB URLs, secrets, ports) that `.envrc` or the dotenv hook sources. The dotfiles carry a dotenv `chpwd` hook in `zsh/lib/dotenv.zsh`. | Holds real secrets and machine-local values. It cannot be regenerated — there is nothing to regenerate it *from*. It must be copied. |
| `.linear.toml` | Config for the `linear` CLI (schpet/linear-cli). Installed in `homebrew/Brewfile:280`, allowed in `claude/permissions.json:20`, and added as a skill in `agents/Skillfile`. | Ties the checkout to a Linear team/workspace. Small, stable, gitignored. Copying keeps `linear issue view` working in the worktree with no re-auth. |
| `.mcp.json` | Claude Code MCP server definitions for the project. | Wires the agent to its MCP servers. Gitignored, may contain tokens. Copy so the agent in the worktree has the same tools as `$MAIN` without re-registering servers. |
| `.claude/settings.local.json` | Per-checkout Claude Code settings and the local permission allowlist (the private sibling of the shared settings). | Local, gitignored, and per-machine by design. Copying preserves the agent's approved permissions so the worktree agent is not re-prompted for everything. |
| `.claude/commands` | Project slash-command definitions for Claude Code. | Even when tracked, copying guarantees the agent in a fresh worktree has the same commands the moment it starts, before any checkout race. |
| `deps` | Fetched Mix dependencies (`mix deps.get` output). | Regenerating means a full `mix deps.get` — network-bound, slow, and pointless when `$MAIN` already has the exact same locked versions (`mix.lock` is tracked). Copy is near-instant. |
| `_build` | Compiled BEAM artifacts (`.beam`, app files, NIFs) per env. | The expensive one. A cold `mix compile` of a large app is minutes; copying `_build` lets the worktree start from a warm build and only recompile what changed. This is the single biggest time saver in the list. |
| `local-bin` | Project-local executables / shims on `PATH` (the dotfiles put `$HOME/.local/bin` on `PATH` in `zsh/env.zsh`; a project `local-bin` is the repo-scoped analog). | Gitignored tooling the project expects on `PATH`. Regenerating means re-running whatever built them; copying is one step. |

The pattern: **copy anything gitignored that is slow or impossible to rebuild, and that `$MAIN` already holds in the exact form the worktree needs.** Tracked source needs no copy — the worktree checkout already has it.

## Implications for an Elixir-flavored worktree init

The list generalizes cleanly into a checklist for cutting a fresh Elixir worktree. Order matters: copy build state before the agent starts, so it never triggers a cold compile.

1. **Copy `_build` and `deps` from the main checkout first.** These are the costly ones; a warm `_build` turns a minutes-long cold compile into an incremental one. `mix.lock` is tracked, so the copied `deps` are guaranteed to match.
2. **Copy the env layer: `.envrc` and `dev.env` (and any `.env`).** Secrets and machine-local values that cannot be regenerated. Without them the worktree's app will not boot or connect to its DB.
3. **Copy the agent layer: `.mcp.json`, `.claude/settings.local.json`, `.claude/commands`.** So the agent in the worktree opens with the same tools, permissions, and commands as `$MAIN` and is not re-prompted.
4. **Copy per-tool config: `.linear.toml` and any `local-bin` shims.** Small, gitignored glue that keeps CLIs and PATH tooling working.
5. **Leave tracked source alone.** The worktree checkout already has it; copying it would be wrong, not just wasteful.
6. **Prefer a hook over memory.** worktrunk's `[post-create]` in `.config/wt.toml` (or `wt step copy-ignored` + `.worktreeinclude`) is where this belongs, so every new worktree gets it automatically. In a dotfiles-driven setup the machine layer only needs to install `wt` and shell-init it; the copy list is project-scoped and ships with the app.

A useful test for whether an artifact belongs on the list: *is it gitignored, and is copying it cheaper than regenerating it?* If yes on both, copy it. `_build` and `deps` are the Elixir-specific headline; the rest is the generic agent-and-env surface any language would need.

## Caveat on sourcing

I could not open the talk video or slide to transcribe the script verbatim, and the script is not committed to the public dotfiles, so the copy list above is quoted from the ticket's description of the screenshot rather than from a primary file. Every claim about *what each artifact is for* and *which tool owns it* is grounded in the pinned dotfiles commit and worktrunk's own docs, both cited above. If the verbatim hook is wanted, it would be found in one of Andrea's Elixir project repos under `.config/wt.toml`, not in `whatyouhide/dotfiles`.
