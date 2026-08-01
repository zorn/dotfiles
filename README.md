# dotfiles

My personal machine configuration, kept in git so it isn't trapped on one laptop. Public so I can link to individual pieces when I write about them.

This is a reference, not a product. There's no installer, nothing is versioned for release, and I'm not maintaining any of it on anyone else's behalf. Read it, take what's useful, adapt it.

## What's here

### Claude Code skills — `claude/skills/`

[Agent Skills](https://agentskills.io) I wrote by hand. Each is a directory with a `SKILL.md`, plus optional `scripts/` and `reference/` material.

| Skill | What it does |
|---|---|
| [`zorn-update-elixir-deps-with-pr`](claude/skills/zorn-update-elixir-deps-with-pr/SKILL.md) | Updates outdated Hex dependencies, verifies with `mix precommit`, and opens a PR whose body documents every direct and transitive version change with diff and changelog links. |

These assume my conventions — a `precommit` mix alias, an authenticated `gh`, and my PR title rules. Each skill's Requirements section spells out what it needs. The `zorn-` prefix exists to avoid collisions in the flat `~/.claude/skills/` namespace, which I share with skills installed from elsewhere.

## Setup

```bash
git clone https://github.com/zorn/dotfiles.git ~/ProjectRepos/dotfiles
~/ProjectRepos/dotfiles/bin/link
```

`bin/link` symlinks each skill into `~/.claude/skills/`. It's idempotent, and it refuses to overwrite anything that already exists as a real file or directory. Editing a skill in this repo takes effect immediately — no reinstall step.

## Secrets

Nothing in this repo is a credential, and nothing ever should be. Files are added to it one at a time, deliberately. There is no "track my whole home directory and ignore the bad parts" rule, because that leaks the file you forgot about.

Config that mixes shareable settings with a secret gets split: the shareable part lives here, the secret lives in an untracked sibling file that the tracked one loads at runtime.

That's a habit, though, and habits fail. [gitleaks](https://gitleaks.io) is the backstop that doesn't: it runs on every pull request as a required check, so a leak blocks the merge. It scans the working tree *and* the commit history, because this repo is public and git history is permanent — a credential that reaches GitHub is already scraped, and deleting it in the next commit fixes nothing.

To find out before you push rather than after:

```bash
brew install gitleaks
./bin/check
```

`bin/check` is the same script CI runs, so there's one definition of "green" instead of two that drift apart. There's no pre-commit hook on purpose — hooks are one `--no-verify` away from doing nothing, and they're silently missing until someone installs them. The pull request check is the guarantee; `bin/check` is just the convenience.

## Housekeeping

Two more pieces of automation, neither of which is looking for leaked secrets.

[`amannn/action-semantic-pull-request`](https://github.com/amannn/action-semantic-pull-request) runs on every pull request and checks its *title*: a conventional-commit type, and a subject that doesn't start with a capital. I squash-merge, so the title becomes the commit message — this is the thing that actually keeps the history readable, and I'd rather find out when I open the PR than when I merge it.

[Dependabot](.github/dependabot.yml) isn't a check at all. Once a month it reads the workflow files, finds the actions they pin, and opens a single grouped pull request for whatever has moved. It skips the pinned `gitleaks` release in `ci.yml` — that's a download URL and a checksum in an env var, not an action reference, so there's nothing there for it to recognize and that bump stays manual.
