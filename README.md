# dotfiles

My personal machine configuration, kept in git so it isn't trapped on one laptop. Public so I can link to individual pieces when I write about them.

This is a reference, not a product. There's no installer, nothing is versioned for release, and I'm not maintaining any of it on anyone else's behalf. Read it, take what's useful, adapt it.

## What's here

### Claude Code skills — `claude/skills/`

[Agent Skills](https://agentskills.io) I maintain. Each is a directory with a `SKILL.md`, plus optional `scripts/` and `reference/` material.

Most began as forks of [mattpocock/skills](https://github.com/mattpocock/skills) and were reshaped — split, merged, or rewritten — to fit how I actually work. Every forked skill records where it came from in its `metadata` frontmatter, and `LICENSE` carries the upstream notice. `elixir-deps-update` and `pull-request` are the exceptions: I wrote them from scratch, so they carry no `forked-from`.

A skill with malformed frontmatter fails silently — it just never activates, with no error to notice — so every pull request validates them against the [Agent Skills spec](https://agentskills.io/specification): the `name` rules, `name` matching the directory, a non-empty `description` within the length limit, plus relative links that resolve and Python that compiles.

Frontmatter is read strictly, so a `description` containing a colon or a `#` has to be in double quotes. Both are valid YAML unquoted and both quietly mangle the description — the colon by splitting it, the `#` by commenting out everything after it — which is precisely the failure with nothing else to report it.

### Global Claude instructions — `claude/CLAUDE.md`

The instructions every Claude Code session loads no matter which project it's in — how I want git work handled, and how I want Claude to write prose and present findings to me. Project-level `CLAUDE.md` files (including this repo's) layer on top of it.

### Claude Code settings — `claude/`

My Claude Code `settings.json`, `keybindings.json`, and status line script. The settings file holds an `autoMode` block that describes private work repos. That block lives in an untracked `~/.claude/settings.private.json`, and `bin/link` merges the two into the live file. [ADR 0005](docs/adr/0005-built-claude-settings.md) explains why.

### worktrunk config — `worktrunk/`

The global config for [worktrunk](https://worktrunk.dev) (`wt`), the tool I create and remove git worktrees with. It lets parallel coding agents each run a Phoenix app with its own port and databases. Its hooks ready each new worktree and tear it down again, and a `wt herdr` alias opens a new worktree in [Herdr](https://herdr.dev). [`worktrunk/README.md`](worktrunk/README.md) is the runbook: setting up a machine, the create, work, and remove flow, and how to opt a Phoenix app in.

### fish config — `fish/`

My [fish](https://fishshell.com) `config.fish`: PATH setup, including asdf's shims. Only that one file is tracked. Fish writes `fish_variables` into the same directory, and installers add their own generated functions and completions there. Those files are machine state, so on a fresh machine they come back from the tools that write them:

- `conf.d/rustup.fish` — installing rustup
- `completions/asdf.fish` — `asdf completion fish > ~/.config/fish/completions/asdf.fish`
- `functions/wt.fish` and `completions/wt.fish` — `wt config shell install`

Secrets and machine-only settings go in `~/.config/fish/local.fish`, which `config.fish` loads if it exists. It lives outside the repo, so it cannot be committed.

### Zed settings — `zed/`

My [Zed](https://zed.dev) `settings.json`. Its `auto_install_extensions` list makes a fresh machine install the extensions the language-server settings rely on. Only that file is tracked. My theme is a built-in, so `themes/` is empty and not tracked. The rules database in `~/.config/zed/prompts/` is binary and stays out.

### asdf tool versions — `asdf/`

My global [asdf](https://asdf-vm.com) `.tool-versions`: the Erlang, Elixir, Ruby, and Node versions a directory gets when no project pins its own. `asdf set --home` writes through the symlink, so a version bump shows up here as a diff.

### zsh startup files — `zsh/`

I work in fish, but zsh is still my login shell, and GUI apps like Zed build their environment by starting a zsh login shell. `zprofile` puts Homebrew on that PATH and `zshenv` puts cargo there. Without them, those apps can't find either.

## Setup

```bash
git clone https://github.com/zorn/dotfiles.git ~/ProjectRepos/dotfiles
~/ProjectRepos/dotfiles/bin/link
```

`bin/link` mirrors `claude/` into `~/.claude/` with symlinks: each skill into `~/.claude/skills/`, and `CLAUDE.md`, `keybindings.json`, and `statusline-command.sh` to the same names. It builds `~/.claude/settings.json` instead, from `claude/settings.json` and the private file. It links the worktrunk config into `~/.config/worktrunk/`, `fish/config.fish` into `~/.config/fish/`, `git/config` and `git/ignore` into `~/.config/git/`, `zed/settings.json` into `~/.config/zed/`, and `asdf/tool-versions`, `zsh/zprofile`, and `zsh/zshenv` to their dotted names in `~` the same way. It also points `core.hooksPath` at `githooks/` so the pre-commit secret scan runs. It's idempotent, and it refuses to overwrite anything that already exists as a real file or directory. Editing a linked file takes effect immediately — no reinstall step. After editing `claude/settings.json`, re-run `bin/link`. It rebuilds the live file unless a change made in Claude Code's UI is there, which it shows as a diff instead of overwriting.

## Secrets

Nothing in this repo is a credential, and nothing ever should be.

Config that mixes shareable settings with a secret gets split: the shareable part lives here, the secret lives in an untracked sibling file that the tracked one loads at runtime. Claude Code's `settings.json` cannot load another file, so `bin/link` merges it with its sibling instead.

[Betterleaks](https://github.com/betterleaks/betterleaks) runs on every pull request as a required check, so a leak blocks the merge. It scans the working tree *and* the commit history, because this repo is public and git history is permanent — a credential that reaches GitHub is already scraped, and deleting it in the next commit fixes nothing.

A pre-commit hook in `githooks/` runs Betterleaks over the staged changes, so a secret is caught before the commit exists rather than after the push. It refuses the commit when Betterleaks is not installed, because a scan that did not run must not look like a clean one.

To run every check before you push:

```bash
brew install betterleaks actionlint shellcheck jq
./bin/check
```

`bin/check` is the same script CI runs, so there's one definition of "green" instead of two that drift apart. Secret scanning is only its first check: it also runs [actionlint](https://github.com/rhysd/actionlint) over the workflow files, [shellcheck](https://www.shellcheck.net) over the scripts in `bin/`, `claude/`, `worktrunk/hooks/`, and `githooks/`, `bin/check-skills` over the skills, and `bin/test-link`, which runs `bin/link` against a throwaway home directory — hence the extra tools above, and why it exits rather than checking anything if one is missing. It needs `python3` on PATH for `bin/check-skills`, which any machine with the Xcode command line tools already has. Name a section, such as `./bin/check secrets`, to run only that one. The pull request check is the guarantee; `bin/check` is just the convenience.
