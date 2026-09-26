# dotfiles

My personal machine configuration, kept in git so it isn't trapped on one laptop. Public so I can link to individual pieces when I write about them.

This is a reference, not a product. There's no installer, nothing is versioned for release, and I'm not maintaining any of it on anyone else's behalf. Read it, take what's useful, adapt it.

## What's here

### Claude Code skills — `claude/skills/`

[Agent Skills](https://agentskills.io) I maintain. Each is a directory with a `SKILL.md`, plus optional `scripts/` and `reference/` material.

All but one began as forks of [mattpocock/skills](https://github.com/mattpocock/skills) and were reshaped — split, merged, or rewritten — to fit how I actually work. Every forked skill records where it came from in its `metadata` frontmatter, and `LICENSE` carries the upstream notice. `elixir-deps-update` is the exception, written from scratch, and the only skill here with no `forked-from`.

A skill with malformed frontmatter fails silently — it just never activates, with no error to notice — so every pull request validates them against the [Agent Skills spec](https://agentskills.io/specification): the `name` rules, `name` matching the directory, a non-empty `description` within the length limit, plus relative links that resolve and Python that compiles.

Frontmatter is read strictly, so a `description` containing a colon or a `#` has to be in double quotes. Both are valid YAML unquoted and both quietly mangle the description — the colon by splitting it, the `#` by commenting out everything after it — which is precisely the failure with nothing else to report it.

### Global Claude instructions — `claude/CLAUDE.md`

The instructions every Claude Code session loads no matter which project it's in — how I want commits and pull requests written, and how I want Markdown formatted. Project-level `CLAUDE.md` files (including this repo's) layer on top of it.

### worktrunk config — `worktrunk/`

The global config for [worktrunk](https://worktrunk.dev) (`wt`), the tool I create and remove git worktrees with. Its `pre-start` hook readies each new worktree by project type. When the worktree has a `mix.exs`, the hook copies the build state and writes the worktree's port to `.env.worktree`. In any other repo it does nothing. A Phoenix app that wants its own databases opts in from its `.config/wt.toml` by calling `worktrunk/hooks/postgres`. The header of that script shows the lines to add. Removing a worktree with `wt remove` drops its databases, and a server or IEx session still connected to one stops the removal until it is closed. The app's `config/runtime.exs` reads `.env.worktree`, for the reasons in [ADR 0004](docs/adr/0004-worktree-values-in-an-env-file.md).

```bash
brew install worktrunk
```

Run `bin/link` before worktrunk writes a config of its own, for example with `wt config create`. `bin/link` never overwrites a real file. If `~/.config/worktrunk/config.toml` already exists, it prints `SKIP` and the tracked config never loads.

## Setup

```bash
git clone https://github.com/zorn/dotfiles.git ~/ProjectRepos/dotfiles
~/ProjectRepos/dotfiles/bin/link
```

`bin/link` mirrors `claude/` into `~/.claude/` with symlinks: each skill into `~/.claude/skills/`, and `claude/CLAUDE.md` to `~/.claude/CLAUDE.md`. It links the worktrunk config into `~/.config/worktrunk/` the same way. It's idempotent, and it refuses to overwrite anything that already exists as a real file or directory. Editing a file in this repo takes effect immediately — no reinstall step.

## Secrets

Nothing in this repo is a credential, and nothing ever should be.

Config that mixes shareable settings with a secret gets split: the shareable part lives here, the secret lives in an untracked sibling file that the tracked one loads at runtime.

[gitleaks](https://gitleaks.io) runs on every pull request as a required check, so a leak blocks the merge. It scans the working tree *and* the commit history, because this repo is public and git history is permanent — a credential that reaches GitHub is already scraped, and deleting it in the next commit fixes nothing.

To find out before you push rather than after:

```bash
brew install gitleaks actionlint shellcheck
./bin/check
```

`bin/check` is the same script CI runs, so there's one definition of "green" instead of two that drift apart. Secret scanning is only its first job: it also runs [actionlint](https://github.com/rhysd/actionlint) over the workflow files, [shellcheck](https://www.shellcheck.net) over the scripts in `bin/`, the skills, and `worktrunk/hooks/`, and `bin/check-skills` over the skills — hence the extra tools above, and why it exits rather than checking anything if one is missing. It needs `python3` on PATH for that last one, which any machine with the Xcode command line tools already has. The pull request check is the guarantee; `bin/check` is just the convenience.
