# AGENTS.md

This file provides guidance to coding agents when working with code in this repository. `CLAUDE.md` is a symlink to it, so Claude Code reads the same content.

## What this repo is

Mike Zornek's personal machine configuration, kept in git and public so individual pieces can be linked to in writing. It is a reference, not a product — no installer, no releases, no support burden for other people's setups.

There is no build, no test suite, and no linter. The only executable is `bin/link`.

## Layout and the symlink model

```
bin/link              # installer — symlinks tracked config into $HOME
claude/skills/<name>/ # one directory per hand-written Claude Code skill
  SKILL.md            #   required: YAML frontmatter (name, description) + body
  scripts/            #   optional: helper executables the skill shells out to
  reference/          #   optional: material the skill reads on demand
```

`bin/link` iterates the immediate subdirectories of `claude/skills/` and symlinks each into `~/.claude/skills/`. Consequences worth knowing:

- **Edits are live.** A skill in this repo is the same inode the agent loads. Never "reinstall" after editing; just edit.
- **Adding a skill means re-running `bin/link`.** Adding a file inside an already-linked skill does not.
- **The script refuses to clobber.** If a real file or directory already sits at the destination it prints `SKIP` and leaves it alone, so a bad run cannot eat untracked config. A wrong-target symlink *is* relinked.
- Any new category of dotfile added later should extend `bin/link` with the same idempotent, refuse-to-overwrite behavior rather than adding a second installer.

## Writing skills

- **Prefix every skill with `zorn-`.** `~/.claude/skills/` is a flat namespace shared with skills installed from elsewhere; the prefix prevents collisions.
- **The `description` in frontmatter is the routing signal.** It is what the agent matches against to decide whether to load the skill, so it must name the trigger phrases and the concrete steps — not just the topic. See `zorn-update-elixir-deps-with-pr/SKILL.md` for the intended density.
- **Structure the body as numbered steps, each ending in a `**Done when:**` line.** These are the checkpoints an agent verifies against before advancing.
- **State prerequisites in a `## Requirements` section.** Skills assume Mike's conventions (a `precommit` mix alias, an authenticated `gh`, his PR title rules); Requirements is where that assumption gets declared instead of failing mysteriously.
- **Scripts referenced from a `SKILL.md` must use the installed path** — `~/.claude/skills/<skill>/scripts/…` — not a repo-relative path, since the agent runs them from the user's project directory.
- **Helper scripts should fail loudly on unrecognized input.** `parse_mix_lock_diff.py` warns on stderr about lines that look like Hex lock entries but did not parse, so an upstream format change surfaces as a warning rather than as a silently short PR body.

## Secrets

Files are tracked one at a time, deliberately. There is deliberately no "track the whole home directory and ignore the bad parts" rule, because that pattern leaks the file you forgot about. Config mixing shareable settings with a secret gets split: the shareable half lives here, the secret lives in an untracked sibling that the tracked file loads at runtime.

## Conventions

- Commits use conventional-commit prefixes with lowercase subjects (`docs: unwrap hard-wrapped prose in README`). Work lands through pull requests.
- Markdown prose is soft-wrapped — one long line per paragraph — so editing a sentence does not reflow the diff. Existing `SKILL.md` files are hard-wrapped at ~80 columns; match whatever a file already does rather than converting it as a side effect.
- The README's skill table is hand-maintained. Adding a skill means adding its row.
