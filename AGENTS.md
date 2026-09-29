# AGENTS.md

Mike Zornek's personal machine configuration, public so individual pieces can be linked to in writing.

## The symlink model

`bin/link` mirrors `claude/` into `~/.claude/`: each `claude/skills/<name>/` directory into `~/.claude/skills/`, and `claude/CLAUDE.md`, `claude/keybindings.json` and `claude/statusline-command.sh` to the same names in `~/.claude/`. It builds `~/.claude/settings.json` from `claude/settings.json` rather than linking it. It also links `worktrunk/config.toml` and `worktrunk/hooks/` into `~/.config/worktrunk/`, links `fish/config.fish` into `~/.config/fish/`, links `git/config` and `git/ignore` into `~/.config/git/`, links `zed/settings.json` into `~/.config/zed/`, links `asdf/tool-versions` to `~/.tool-versions` and `zsh/zprofile` and `zsh/zshenv` to `~/.zprofile` and `~/.zshenv`, and sets `core.hooksPath` to `githooks/`.

- **Edits to a linked file are live.** It is the same inode the agent loads — never "reinstall" after editing, just edit.
- **Adding a skill means re-running `bin/link`.** Adding a file inside an already-linked skill does not.
- It prints `SKIP` rather than clobbering a real file at the destination. Add a category by calling `link_path` again, not by writing a second installer. `build_settings` is the one exception, because `settings.json` cannot be a link.
- **Never link `~/.config/worktrunk/` itself — only the files and `hooks/` inside it.** worktrunk writes `approvals.toml` there, and a linked directory would put that machine state in this repo.
- **Link only `fish/config.fish`, never `~/.config/fish/` or its subdirectories.** Fish writes `fish_variables` there and installers write generated functions and completions, so a linked directory would put them in the repo. Add a `link_path` for a `conf.d/` or `functions/` file only when it is hand-written.
- **`~/.config/fish/local.fish` sits outside the repo on purpose.** It is where a shell secret goes; a gitignored file inside the repo is one `git add -f` from public.
- **Link only `git/config` and `git/ignore`, never `~/.config/git/`.** Credential helpers write machine state there. Machine-only or secret git settings go in the untracked `~/.config/git/config.local`, which `git/config` includes.
- **Link only `zed/settings.json`, never `~/.config/zed/`.** Zed keeps its rules database there, and its rules-to-skills migration may write an `AGENTS.md` there. When a custom theme arrives, link `themes/` whole — Zed never writes there.
- **`~/.claude/settings.json` is built, not linked — edit `claude/settings.json`, then re-run `bin/link`.** It merges in the untracked `~/.claude/settings.private.json` ([ADR 0005](docs/adr/0005-built-claude-settings.md)).
- **`autoMode` goes in `settings.private.json`, never `claude/settings.json`.** It describes private work repos, and gitleaks cannot flag it, since it is prose, not a credential.
- **`claude/CLAUDE.md` is the global file, not instructions for this repo.** A session working in `claude/` loads it a second time as directory-scoped context — harmless, since it is already loaded globally, but do not "fix" it by writing repo guidance into it. Repo guidance goes in the root `AGENTS.md`.

## CI

`bin/check` is the single entry point; each `ci.yml` job installs its section's tool, if any, and runs `bin/check <section>`. **Add a check by editing `bin/check`** — never by inlining it into a workflow, and never as a separate workflow either. Both make local and CI drift apart.

- **Each job name in `ci.yml` is a required-status-check context on the `protect-main` ruleset.** Renaming a job silently un-requires it, and a new section's job is not required until the ruleset lists it. Update the ruleset when the change merges.
- The ruleset lives in repo settings, so nothing here enforces it and it can be switched off without leaving a diff. Verify rather than trust: `gh api repos/zorn/dotfiles/rules/branches/main --jq '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context'` should list every job in `ci.yml`.
- Tool pins in `ci.yml` are a version plus a tarball checksum, and **Dependabot cannot see them** — no ecosystem tracks a curl'd release, and the checksum is not what hides them. Bumping is manual; move the checksum with the version, from that release's `<tool>_<version>_checksums.txt`.
- **`shellcheck`, `python3` and `jq` are unpinned on purpose** — unlike gitleaks and actionlint, they come with the runner image rather than being installed by `ci.yml`, so a new skill check needs no workflow change at all.

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

Config mixing shareable settings with a secret gets split: the shareable half lives here, the secret in an untracked sibling the tracked file loads at runtime. A file with no way to load another, like Claude Code's `settings.json`, is merged with its sibling by `bin/link` instead.

Treat a history finding as a live incident. The repo is public and git history is permanent, so a credential that reached GitHub has already been scraped — fixing it means rewriting history **and** rotating the secret. A genuine false positive gets a `gitleaks:allow` comment at the line, never a `.gitleaksignore` entry.
