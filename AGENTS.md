# AGENTS.md

Mike Zornek's personal machine configuration, public so individual pieces can be linked to in writing. A reference, not a product — no installer story, no releases, no build, no tests. `CLAUDE.md` is a symlink to this file.

## The symlink model

`bin/link` symlinks each `claude/skills/<name>/` directory into `~/.claude/skills/`.

- **Edits are live.** A skill here is the same inode the agent loads — never "reinstall" after editing, just edit.
- **Adding a skill means re-running `bin/link`.** Adding a file inside an already-linked skill does not.
- It prints `SKIP` rather than clobbering a real file at the destination. Extend it for any new category of dotfile instead of writing a second installer.

## CI

`bin/check` is the single entry point; `ci.yml` installs the tools and runs it. **Add a check by editing `bin/check`** — never by inlining it into a workflow, and never as a separate workflow either. Both make local and CI drift apart.

- **Do not rename the `gitleaks` job.** Its id is the required-status-check context on the `protect-main` ruleset, so renaming silently un-requires it. It runs more than gitleaks now.
- The ruleset lives in repo settings, so nothing here enforces it and it can be switched off without leaving a diff. Verify rather than trust: `gh api repos/zorn/dotfiles/rules/branches/main --jq '.[].type'`.
- Tool pins in `ci.yml` are a version plus a tarball checksum, and **Dependabot cannot see them** — no ecosystem tracks a curl'd release, and the checksum is not what hides them. Bumping is manual; move the checksum with the version, from that release's `<tool>_<version>_checksums.txt`.
- No pre-commit hook, deliberately. `--no-verify` defeats them and they are silently absent until someone installs them. The PR check is the guarantee.

## Deliberate choices that look like mistakes

Each of these has been "cleaned up" by someone who did not know why it was there.

- **`"on":` is quoted in every workflow.** YAML 1.1 parsers — including the `rlsp-yaml` language server behind the editor's YAML support — read a bare `on:` as the boolean `true` and warn. Actions accepts either form; the quotes only keep the editor quiet.
- **`lint-pr.yml` uses `pull_request`, not the `pull_request_target` its action's README suggests.** The only API call is `pulls.get`, covered by the `pull-requests: read` grant, which a fork opening a PR against a public repo already receives. `pull_request_target` would add nothing but a write-capable token to a workflow one careless `actions/checkout` away from running fork code with it.
- **`dependabot.yml` sets `commit-message.prefix` explicitly.** Left alone, Dependabot infers a prefix from recent history; a wrong guess reddens the title check on every bump.

## Pull request titles

`lint-pr.yml` requires a conventional-commit type and a subject that does not start with a capital. Squash-merging makes the PR title the commit message, so this is what actually keeps `main`'s history consistent. It is not in `bin/check` because there is no pull request title to read from a local shell.

`ignoreLabels` (`bot`, `ignore-semantic-pull-request`) skips validation, but `labeled` is not among the trigger types — a label takes effect on the next title edit or push, not on being applied.

## Secrets

Files are tracked one at a time. There is deliberately no "track everything and ignore the bad parts" rule, because that pattern leaks the file you forgot about. Config mixing shareable settings with a secret gets split: the shareable half lives here, the secret in an untracked sibling the tracked file loads at runtime.

Treat a history finding as a live incident. The repo is public and git history is permanent, so a credential that reached GitHub has already been scraped — fixing it means rewriting history **and** rotating the secret. A genuine false positive gets a `gitleaks:allow` comment at the line, never a `.gitleaksignore` entry.

## Writing skills

- **Prefix every skill `zorn-`.** `~/.claude/skills/` is a flat namespace shared with skills installed from elsewhere.
- **The frontmatter `description` is the routing signal** — it must name trigger phrases and concrete steps, not just the topic. `claude/skills/zorn-update-elixir-deps-with-pr/SKILL.md` shows the intended density.
- Body is numbered steps, each ending in a `**Done when:**` line.
- Declare assumptions (a `precommit` mix alias, an authenticated `gh`) in a `## Requirements` section.
- **Reference scripts by installed path** — `~/.claude/skills/<skill>/scripts/…` — since the agent runs them from the user's project directory, not from here.
- Helper scripts should fail loudly on unrecognized input rather than silently producing less.

## Conventions

- Conventional-commit prefixes, lowercase subjects. Work lands through pull requests.
- Prose is soft-wrapped, one long line per paragraph. Existing `SKILL.md` files are hard-wrapped at ~80 columns — match whatever a file already does.
- The README's skill table is hand-maintained; adding a skill means adding its row.
