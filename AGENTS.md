# AGENTS.md

This file provides guidance to coding agents when working with code in this repository. `CLAUDE.md` is a symlink to it, so Claude Code reads the same content.

## What this repo is

Mike Zornek's personal machine configuration, kept in git and public so individual pieces can be linked to in writing. It is a reference, not a product — no installer, no releases, no support burden for other people's setups.

There is no build and no test suite. The two executables are `bin/link` (install) and `bin/check` (the CI checks, runnable locally).

## Layout and the symlink model

```
bin/link              # installer — symlinks tracked config into $HOME
bin/check             # the checks CI runs; run before pushing
.github/workflows/    # CI — one job, which invokes bin/check
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

## CI and `bin/check`

CI is one job, `gitleaks`, defined in `.github/workflows/ci.yml`. It runs on every pull request and on pushes to `main`, and it is a required status check on `protect-main`, so a finding blocks the merge button.

The job installs `gitleaks` and then runs `./bin/check`. That indirection is the point: **CI and the local command call the same entry point**, so there is one definition of "green" instead of two that drift. Adding a check means editing `bin/check`, not the workflow. Never inline a check into `ci.yml` that `bin/check` does not also run.

`bin/check` scans twice — the working tree (`gitleaks dir`) and the commit history reachable from HEAD (`gitleaks git`). The history pass is why the workflow checks out with `fetch-depth: 0`; a shallow clone would silently give it nothing to scan. It exits 127 with install instructions when `gitleaks` is missing, rather than passing vacuously.

The workflow pins the `gitleaks` version and its tarball checksum; `bin/check` uses whatever is on `PATH`, which locally means whatever Homebrew last installed. So the *script* never drifts but the *ruleset* can, and a local pass with a much older gitleaks is weaker evidence than a CI pass. Bumping the pin means bumping the checksum beside it, from the release's `gitleaks_<version>_checksums.txt`.

There is deliberately **no pre-commit hook**. Hooks are bypassed with `--no-verify`, are silently absent until someone installs them, and tax every commit to catch something rare. The PR check is the guarantee; `bin/check` is the convenience for finding out before you push.

## Writing skills

- **Prefix every skill with `zorn-`.** `~/.claude/skills/` is a flat namespace shared with skills installed from elsewhere; the prefix prevents collisions.
- **The `description` in frontmatter is the routing signal.** It is what the agent matches against to decide whether to load the skill, so it must name the trigger phrases and the concrete steps — not just the topic. See `claude/skills/zorn-update-elixir-deps-with-pr/SKILL.md` for the intended density.
- **Structure the body as numbered steps, each ending in a `**Done when:**` line.** These are the checkpoints an agent verifies against before advancing.
- **State prerequisites in a `## Requirements` section.** Skills assume Mike's conventions (a `precommit` mix alias, an authenticated `gh`, his PR title rules); Requirements is where that assumption gets declared instead of failing mysteriously.
- **Scripts referenced from a `SKILL.md` must use the installed path** — `~/.claude/skills/<skill>/scripts/…` — not a repo-relative path, since the agent runs them from the user's project directory.
- **Helper scripts should fail loudly on unrecognized input.** `parse_mix_lock_diff.py` warns on stderr about lines that look like Hex lock entries but did not parse, so an upstream format change surfaces as a warning rather than as a silently short PR body.

## Secrets

Files are tracked one at a time, deliberately. There is deliberately no "track the whole home directory and ignore the bad parts" rule, because that pattern leaks the file you forgot about. Config mixing shareable settings with a secret gets split: the shareable half lives here, the secret lives in an untracked sibling that the tracked file loads at runtime.

That judgment is the primary defense; gitleaks is the backstop for when it fails. Treat a history finding as a live incident: the repo is public and git history is permanent, so a credential that reached GitHub has already been scraped. Fixing it means rewriting history **and** rotating the secret — removing it in a follow-up commit accomplishes nothing.

A genuine false positive is annotated at the line with a `gitleaks:allow` comment. Do not silence a finding by adding a `.gitleaksignore` entry or narrowing what gets scanned.

## Conventions

- Commits use conventional-commit prefixes with lowercase subjects (`docs: unwrap hard-wrapped prose in README`). Work lands through pull requests.
- Markdown prose is soft-wrapped — one long line per paragraph — so editing a sentence does not reflow the diff. Existing `SKILL.md` files are hard-wrapped at ~80 columns; match whatever a file already does rather than converting it as a side effect.
- The README's skill table is hand-maintained. Adding a skill means adding its row.
