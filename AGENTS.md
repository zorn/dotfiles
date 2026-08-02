# AGENTS.md

Mike Zornek's personal machine configuration, public so individual pieces can be linked to in writing.

## The symlink model

`bin/link` mirrors `claude/` into `~/.claude/`: each `claude/skills/<name>/` directory into `~/.claude/skills/`, and `claude/CLAUDE.md` to `~/.claude/CLAUDE.md`.

- **Edits are live.** A file here is the same inode the agent loads — never "reinstall" after editing, just edit.
- **Adding a skill means re-running `bin/link`.** Adding a file inside an already-linked skill does not.
- It prints `SKIP` rather than clobbering a real file at the destination. Add a category by calling `link_path` again, not by writing a second installer.
- **`claude/CLAUDE.md` is the global file, not instructions for this repo.** A session working in `claude/` loads it a second time as directory-scoped context — harmless, since it is already loaded globally, but do not "fix" it by writing repo guidance into it. Repo guidance goes in the root `AGENTS.md`.

## CI

`bin/check` is the single entry point; `ci.yml` installs the tools and runs it. **Add a check by editing `bin/check`** — never by inlining it into a workflow, and never as a separate workflow either. Both make local and CI drift apart.

- **Do not rename the `gitleaks` job.** Its id is the required-status-check context on the `protect-main` ruleset, so renaming silently un-requires it. It runs more than gitleaks now.
- The ruleset lives in repo settings, so nothing here enforces it and it can be switched off without leaving a diff. Verify rather than trust: `gh api repos/zorn/dotfiles/rules/branches/main --jq '.[].type'`.
- Tool pins in `ci.yml` are a version plus a tarball checksum, and **Dependabot cannot see them** — no ecosystem tracks a curl'd release, and the checksum is not what hides them. Bumping is manual; move the checksum with the version, from that release's `<tool>_<version>_checksums.txt`.
- **`shellcheck` and `python3` are unpinned on purpose** — unlike gitleaks and actionlint, they come with the runner image rather than being installed by `ci.yml`, so a new skill check needs no workflow change at all.

## Skill validation

`bin/check-skills` validates `claude/skills/*` against the [Agent Skills spec](https://agentskills.io/specification); its docstring carries the reasoning. What is not obvious from reading it:

- **Adding a rule means adding a case to `CASES`.** `bin/check` runs `--self-test` before the real pass, because a validator that cannot fail reports every skill as fine — the same silent pass it exists to prevent.
- **Its frontmatter parser is a deliberate YAML subset, not PyYAML**, and rejects some valid YAML on purpose. Double-quoting the value is the escape hatch; do not widen the parser to accept a one-off.
- **An unrecognised frontmatter field is allowed** — clients define their own, and Claude Code does. Only a near-miss of a spec field is reported, because that is a typo rather than an extension.

## Deliberate choices that could look like mistakes

- **`"on":` is quoted in every workflow.** YAML 1.1 parsers — including the `rlsp-yaml` language server behind the editor's YAML support — read a bare `on:` as the boolean `true` and warn. Actions accepts either form; the quotes only keep the editor quiet.
- **`dependabot.yml` sets `commit-message.prefix` explicitly.** Left alone, Dependabot infers a prefix from recent history; a wrong guess reddens the title check on every bump.
- **Skills use `reference/`, where the spec's example tree says `references/`.** The spec permits any additional directories and no tool reads either name, so `bin/check-skills` does not check directory names and renaming would only churn the prose that points at them.
- **`claude/CLAUDE.md` has no `AGENTS.md` alongside it, unlike the repo root.** The root pair exists so a collaborator using some other agent finds a tool-neutral filename. Nothing in `~/.claude/` is tool-neutral, so there is nobody for the second name to serve.

## Pull request titles

`lint-pr.yml` requires a conventional-commit type and a subject that does not start with a capital. Squash-merging makes the PR title the commit message, so this is what actually keeps `main`'s history consistent. It is not in `bin/check` because there is no pull request title to read from a local shell.

## Secrets

Config mixing shareable settings with a secret gets split: the shareable half lives here, the secret in an untracked sibling the tracked file loads at runtime.

Treat a history finding as a live incident. The repo is public and git history is permanent, so a credential that reached GitHub has already been scraped — fixing it means rewriting history **and** rotating the secret. A genuine false positive gets a `gitleaks:allow` comment at the line, never a `.gitleaksignore` entry.
