# dotfiles

My personal machine configuration, kept in git so it isn't trapped on one
laptop. Public so I can link to individual pieces when I write about them.

This is a reference, not a product. There's no installer, nothing is versioned
for release, and I'm not maintaining any of it on anyone else's behalf. Read it,
take what's useful, adapt it.

## What's here

### Claude Code skills — `claude/skills/`

[Agent Skills](https://agentskills.io) I wrote by hand. Each is a directory with
a `SKILL.md`, plus optional `scripts/` and `reference/` material.

| Skill | What it does |
|---|---|
| [`zorn-update-elixir-deps-with-pr`](claude/skills/zorn-update-elixir-deps-with-pr/SKILL.md) | Updates outdated Hex dependencies, verifies with `mix precommit`, and opens a PR whose body documents every direct and transitive version change with diff and changelog links. |

These assume my conventions — a `precommit` mix alias, an authenticated `gh`,
and my PR title rules. Each skill's Requirements section spells out what it
needs. The `zorn-` prefix exists to avoid collisions in the flat
`~/.claude/skills/` namespace, which I share with skills installed from
elsewhere.

## Setup

```bash
git clone https://github.com/zorn/dotfiles.git ~/ProjectRepos/dotfiles
~/ProjectRepos/dotfiles/bin/link
```

`bin/link` symlinks each skill into `~/.claude/skills/`. It's idempotent, and it
refuses to overwrite anything that already exists as a real file or directory.
Editing a skill in this repo takes effect immediately — no reinstall step.

## Secrets

Nothing in this repo is a credential, and nothing ever should be. Files are
added to it one at a time, deliberately. There is no "track my whole home
directory and ignore the bad parts" rule, because that leaks the file you forgot
about.

Config that mixes shareable settings with a secret gets split: the shareable
part lives here, the secret lives in an untracked sibling file that the tracked
one loads at runtime.
