# dotfiles

My personal machine configuration, kept in git so it isn't trapped on one laptop. Public so I can link to individual pieces when I write about them.

This is a reference, not a product. There's no installer, nothing is versioned for release, and I'm not maintaining any of it on anyone else's behalf. Read it, take what's useful, adapt it.

## What's here

### Claude Code skills — `claude/skills/`

[Agent Skills](https://agentskills.io) I wrote by hand. Each is a directory with a `SKILL.md`, plus optional `scripts/` and `reference/` material.

## Setup

```bash
git clone https://github.com/zorn/dotfiles.git ~/ProjectRepos/dotfiles
~/ProjectRepos/dotfiles/bin/link
```

`bin/link` symlinks each skill into `~/.claude/skills/`. It's idempotent, and it refuses to overwrite anything that already exists as a real file or directory. Editing a skill in this repo takes effect immediately — no reinstall step.

## Secrets

Nothing in this repo is a credential, and nothing ever should be.

Config that mixes shareable settings with a secret gets split: the shareable part lives here, the secret lives in an untracked sibling file that the tracked one loads at runtime.

[gitleaks](https://gitleaks.io) runs on every pull request as a required check, so a leak blocks the merge. It scans the working tree *and* the commit history, because this repo is public and git history is permanent — a credential that reaches GitHub is already scraped, and deleting it in the next commit fixes nothing.

To find out before you push rather than after:

```bash
brew install gitleaks
./bin/check
```

`bin/check` is the same script CI runs, so there's one definition of "green" instead of two that drift apart. The pull request check is the guarantee; `bin/check` is just the convenience.
