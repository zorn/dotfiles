# dotfiles

My personal machine configuration, kept in git so it isn't trapped on one laptop. Public so I can link to individual pieces when I write about them.

This is a reference, not a product. There's no installer, nothing is versioned for release, and I'm not maintaining any of it on anyone else's behalf. Read it, take what's useful, adapt it.

## What's here

### Claude Code skills — `claude/skills/`

[Agent Skills](https://agentskills.io) I wrote by hand. Each is a directory with a `SKILL.md`, plus optional `scripts/` and `reference/` material.

A skill with malformed frontmatter fails silently — it just never activates, with no error to notice — so every pull request validates them against the [Agent Skills spec](https://agentskills.io/specification): the `name` rules, `name` matching the directory, a non-empty `description` within the length limit, plus relative links that resolve and Python that compiles.

Frontmatter is read strictly, so a `description` containing a colon or a `#` has to be in double quotes. Both are valid YAML unquoted and both quietly mangle the description — the colon by splitting it, the `#` by commenting out everything after it — which is precisely the failure with nothing else to report it.

### Global Claude instructions — `claude/CLAUDE.md`

The instructions every Claude Code session loads no matter which project it's in — how I want commits and pull requests written, and how I want Markdown formatted. Project-level `CLAUDE.md` files (including this repo's) layer on top of it.

## Setup

```bash
git clone https://github.com/zorn/dotfiles.git ~/ProjectRepos/dotfiles
~/ProjectRepos/dotfiles/bin/link
```

`bin/link` mirrors `claude/` into `~/.claude/` with symlinks: each skill into `~/.claude/skills/`, and `claude/CLAUDE.md` to `~/.claude/CLAUDE.md`. It's idempotent, and it refuses to overwrite anything that already exists as a real file or directory. Editing a file in this repo takes effect immediately — no reinstall step.

## Secrets

Nothing in this repo is a credential, and nothing ever should be.

Config that mixes shareable settings with a secret gets split: the shareable part lives here, the secret lives in an untracked sibling file that the tracked one loads at runtime.

[gitleaks](https://gitleaks.io) runs on every pull request as a required check, so a leak blocks the merge. It scans the working tree *and* the commit history, because this repo is public and git history is permanent — a credential that reaches GitHub is already scraped, and deleting it in the next commit fixes nothing.

To find out before you push rather than after:

```bash
brew install gitleaks actionlint shellcheck
./bin/check
```

`bin/check` is the same script CI runs, so there's one definition of "green" instead of two that drift apart. Secret scanning is only its first job: it also runs [actionlint](https://github.com/rhysd/actionlint) over the workflow files, [shellcheck](https://www.shellcheck.net) over the scripts in `bin/`, and `bin/check-skills` over the skills — hence the extra tools above, and why it exits rather than checking anything if one is missing. It needs `python3` on PATH for that last one, which any machine with the Xcode command line tools already has. The pull request check is the guarantee; `bin/check` is just the convenience.
