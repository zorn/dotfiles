# Claude Code cloud sessions as a place to implement tickets

Research ticket: [zorn/dotfiles#84](https://github.com/zorn/dotfiles/issues/84). Sources are the Claude Code docs at [code.claude.com/docs](https://code.claude.com/docs/en/claude-code-on-the-web), read as the `.md` versions of each page on 2026-10-19, plus the Hex and Phoenix sources where they own a claim. The local CLI was v2.1.303. This repo is at commit `3779d43`. The docs change often, so re-read a cited section before you act on it.

## Bottom line

A cloud session can run an Elixir ticket, but not with today's skills unchanged. Three gaps decide the answer, and the experiment in #84 should test them first:

1. **User-level config does not reach the session.** `~/.claude/CLAUDE.md`, `~/.claude/skills/`, user settings, and user hooks all stay on the laptop. Plugins do not load in cloud sessions at all, so a plugin is not a way around this.
2. **`gh issue` and `gh pr` fail in the session.** The GitHub proxy rejects GraphQL, and those subcommands use GraphQL. `implement`, `pull-request`, `diff-review`, and the Copilot watch script all call them.
3. **The Elixir toolchain is not preinstalled, and Hex is only partly allowlisted.** Erlang and Elixir must come from a setup script, and `repo.hex.pm` and `builds.hex.pm` need a Custom network allowlist.

None of the three is a blocker. Each has a documented fix or a clear candidate fix. The likely outcome is "use it for narrow work only" until a setup script and cloud-aware skill branches exist. The rest of this note gives the evidence per question in #84.

## 1. Do my skills and instructions come along?

No. The [What carries over from your setup](https://code.claude.com/docs/en/cloud-environments#what-carries-over-from-your-setup) table is explicit:

| Item | In a cloud session |
| :- | :- |
| Repo `CLAUDE.md`, `.claude/rules/`, `.claude/skills/`, `.claude/agents/` | Yes |
| Repo `.claude/settings.json` hooks and permissions | Yes, in a session with one repository |
| `~/.claude/CLAUDE.md` | No |
| `~/.claude/skills/`, `~/.claude/agents/`, `~/.claude/commands/` | No |
| Plugins in user settings, or declared in the repo's `.claude/settings.json` | No |

[Settings in cloud sessions](https://code.claude.com/docs/en/settings#settings-in-cloud-sessions) adds that `~/.claude/settings.json` and `.claude/settings.local.json` are not read. [Setup scripts vs. SessionStart hooks](https://code.claude.com/docs/en/cloud-environments#setup-scripts-vs-sessionstart-hooks) says user-level hooks do not run in the cloud either. So the `hexdocs-subdomain.sh` PreToolUse hook in `claude/settings.json` is absent too.

The issue names three ways to get skills there. The docs add a fourth.

1. **A plugin: ruled out.** Cloud sessions do not install plugins from either user settings or the repo's `enabledPlugins` ([cloud-environments](https://code.claude.com/docs/en/cloud-environments#what-carries-over-from-your-setup), [skills](https://code.claude.com/docs/en/skills#skills-in-cowork-and-cloud-sessions)).
2. **Skills enabled on the claude.ai account: works for some skills only.** Cloud sessions load the skills enabled for the claude.ai account ([skills](https://code.claude.com/docs/en/skills#skills-in-cowork-and-cloud-sessions)). An upload accepts only six frontmatter fields: `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. Any other field fails the upload with a hard error ([skills](https://code.claude.com/docs/en/skills), the frontmatter table under "When you enable a personal skill for your claude.ai account"). In this repo, `adr`, `codebase-design`, `diff-review`, `domain-language`, `prototype`, `pull-request`, `research`, and `tdd` pass that check. `implement`, `grill`, `handoff`, `retro`, `teach`, `to-spec`, `to-tickets`, `wayfinder`, `writing-skills`, and `elixir-deps-update` use `disable-model-invocation` or `argument-hint`, so they fail. `implement` is the one that matters.
3. **A setup script that writes `~/.claude/` in the VM: documented for `CLAUDE.md`, unverified for skills.** The docs show a setup script writing `~/.claude/CLAUDE.md`, which then loads as user instructions ([Add personal preferences](https://code.claude.com/docs/en/cloud-environments#add-personal-preferences-without-committing-to-the-repo)). The docs do not say whether a `~/.claude/skills/` directory written the same way loads. The skills page says only that cloud sessions do not read `~/.claude/skills/` "on your machine". **Unverified:** that a VM-local `~/.claude/skills/` loads. Also **unverified:** that the setup script can `git clone` this public repo. The GitHub proxy scopes API requests and archive downloads to the session's attached repositories, and returns 403 for an archive of an unattached repository "even a public one" ([GitHub proxy](https://code.claude.com/docs/en/cloud-environments#github-proxy)). It does not say how a plain `git clone` of an unattached repository behaves. `raw.githubusercontent.com` is in the Trusted list and serves committed files from public repositories, so a file-by-file fetch is a documented fallback.
4. **Commit skills into each project's `.claude/skills/`: works, at a maintenance cost.** This is the documented path ([skills](https://code.claude.com/docs/en/skills#skills-in-cowork-and-cloud-sessions)). It copies the skills into every repository, and the copies drift from this repo.

Recommendation for the experiment: try option 3 first, because it keeps one source of truth and `bin/link` already does the linking. `bin/link` also links fish, Zed, git, and worktrunk files, which a VM does not need. A cloud run may want a narrower mode that links only `claude/`. If option 3 fails for skills, use the claude.ai account for the eight skills that pass the upload check, and decide separately how `implement` gets there.

### Attribution needs a repo setting

`claude/settings.json` sets `attribution` to empty `commit` and `pr` strings and `sessionUrl: false`. A cloud session does not read it. Without it, commits get a `Co-Authored-By` trailer, PRs get a "Generated with Claude Code" line ([attribution](https://code.claude.com/docs/en/settings-reference#attribution)), and cloud commits also get a `Claude-Session:` trailer plus a session link in the PR body ([Link output back to the session](https://code.claude.com/docs/en/cloud-environments#link-output-back-to-the-session)). All of these break the global rule against attribution in git artifacts. The fix is to commit the same `attribution` block to each project's `.claude/settings.json`, which the docs list as "Any file" scope. A setup-script-written `~/.claude/settings.json` might also work, but that is **unverified**, for the same reason as skills.

## 2. Can a project's toolchain be rebuilt in a setup script?

Probably, with precompiled builds. Whether the install fits the five-minute cache window is **unverified**. The facts:

- **The VM** is Ubuntu 24.04 on x86_64 with 4 vCPUs, 16 GB of RAM, and 30 GB of disk ([What's available](https://code.claude.com/docs/en/cloud-environments#whats-available-in-cloud-sessions), [Resource limits](https://code.claude.com/docs/en/cloud-environments#resource-limits)).
- **Preinstalled** are PostgreSQL 16, Redis 7.0, Docker, Node 20 to 22, Python, Ruby 3.1 to 3.3, and `gh`, `jq`, `git` ([Installed tools](https://code.claude.com/docs/en/cloud-environments#installed-tools)). Erlang and Elixir are not in the list. Postgres is installed but not running; a session starts it with `service postgresql start` ([Start services](https://code.claude.com/docs/en/cloud-environments#start-services)).
- **The setup script** runs as root before Claude Code launches. It must exit zero, and it is cached as a filesystem snapshot only when it finishes in roughly five minutes. The cache rebuilds when the script or the allowed hosts change, and after about seven days. Running processes are not cached, so Postgres must start per session ([Setup scripts](https://code.claude.com/docs/en/cloud-environments#setup-scripts), [Environment caching](https://code.claude.com/docs/en/cloud-environments#environment-caching)).

For Erlang and Elixir, use Hex's prebuilt builds rather than compiling with asdf. A source build of OTP through asdf and kerl is the step most likely to break the five-minute window (an inference, not measured). Hex's bob publishes OTP builds for `amd64/ubuntu-24.04` at `https://builds.hex.pm/builds/otp/${ARCH}/${OS_VER}/${REF}.tar.gz` ([hexpm/bob README](https://github.com/hexpm/bob/blob/main/README.md)). On 2026-10-19, the [build list](https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/builds.txt) has `OTP-29.1.1`, and the [Elixir build list](https://builds.hex.pm/builds/elixir/builds.txt) has `v1.20.4-otp-29`. Those match `asdf/tool-versions` in this repo (`erlang 29.1.1`, `elixir 1.20.4-otp-29`). A project's own `.tool-versions` decides the real versions.

The network allowlist needs two additions. The Trusted list includes `hex.pm` and `www.hex.pm` but no wildcard, so subdomains are not covered ([Default allowed domains](https://code.claude.com/docs/en/cloud-environments#default-allowed-domains)). Hex fetches packages from `https://repo.hex.pm` ([hexpm/hex `lib/hex/repo.ex`](https://github.com/hexpm/hex/blob/main/lib/hex/repo.ex)), and `mix local.hex` installs from `builds.hex.pm` ([elixir-lang/elixir `local.hex.ex`](https://github.com/elixir-lang/elixir/blob/main/lib/mix/lib/mix/tasks/local.hex.ex)). So the environment needs **Custom** access with the default list kept and `repo.hex.pm` and `builds.hex.pm` added ([Allow specific domains](https://code.claude.com/docs/en/cloud-environments#allow-specific-domains)).

Phoenix asset tools also download binaries. The `esbuild` package fetches from `registry.npmjs.org`, which is allowlisted ([phoenixframework/esbuild](https://github.com/phoenixframework/esbuild/blob/main/lib/esbuild.ex)). The `tailwind` package fetches from `github.com/tailwindlabs/tailwindcss/releases/download/...` ([phoenixframework/tailwind](https://github.com/phoenixframework/tailwind/blob/main/lib/tailwind.ex)). `github.com` and `release-assets.githubusercontent.com` are in the Trusted list. **Unverified:** whether the GitHub proxy's repository scope blocks a release download from an unattached repository, as it does for archives. The experiment should run `mix assets.setup` to find out.

Per-session work belongs in a SessionStart hook committed to the project, guarded by `CLAUDE_CODE_REMOTE=true` so it does nothing locally ([Install dependencies with a SessionStart hook](https://code.claude.com/docs/en/cloud-environments#install-dependencies-with-a-sessionstart-hook)). For a Phoenix app, that hook starts Postgres, runs `mix deps.get`, and creates the test database. The worktrunk hooks in `worktrunk/hooks/` do not apply here: a cloud session has one checkout per VM, so it needs no per-worktree port or database names. **Unverified:** what credentials the preinstalled Postgres accepts. A Phoenix app defaults to user `postgres` with password `postgres`, and the hook may need to set that password first.

## 3. What about secrets and services?

The issue's premise is out of date. It says Team plans do not support credentials stored outside the sandbox. The docs now offer **network secrets** on Pro, Max, Team, and Enterprise. On a Team plan without an organization admin role, the form takes one host per secret and no wildcard ([Add network secrets](https://code.claude.com/docs/en/cloud-environments#add-network-secrets)).

A network secret works only when the key travels in an HTTP request to a listed host. The agent proxy attaches it after the request leaves the VM, so the key never appears in the session ([Which requests get the secret](https://code.claude.com/docs/en/cloud-environments#which-requests-get-the-credential)). These needs do not fit that model:

- **A secret the app reads as a value**, such as a `SECRET_KEY_BASE`, a signing key, or a key a test passes to a library. It must go in an environment variable, and anyone who uses the environment can read those ([Set environment variables](https://code.claude.com/docs/en/cloud-environments#set-environment-variables)).
- **A secret used during the setup script.** The setup script runs before Claude Code connects to the agent proxy, so it never gets a network secret ([Requests that never get the secret](https://code.claude.com/docs/en/cloud-environments#requests-that-never-get-the-credential)). A private Hex organization key needed by `mix deps.get` in the setup script is one example.
- **Interactive login**, such as AWS SSO. It is not supported ([What carries over](https://code.claude.com/docs/en/cloud-environments#what-carries-over-from-your-setup)).
- **A service on a private network.** Requests leave from Anthropic's network, so the API must accept connections from the internet ([Requirements](https://code.claude.com/docs/en/cloud-environments#requirements)).

Most Phoenix test suites need none of these, because dev and test secrets are committed defaults. The experiment should list any that a chosen project does need.

## 4. Does the review loop still work?

Not as written, but the watch script is close. `implement` step 6 runs `watch-pr-feedback.sh` under `Monitor`. The GitHub proxy rejects every GraphQL request. The docs name `gh pr` and `gh issue` as subcommands that get the 403, even with a `GH_TOKEN` set ([GitHub proxy](https://code.claude.com/docs/en/cloud-environments#github-proxy), [Work with GitHub issues and pull requests](https://code.claude.com/docs/en/cloud-environments#work-with-github-issues-and-pull-requests)). In the script, only `gh pr checks` (line 107) is a confirmed problem. It calls `gh repo view` (line 47) only when no repository argument is passed, so passing one avoids that call. **Unverified:** whether `gh repo view` fails; the docs do not name it, though it also uses GraphQL. The three `gh api repos/...` REST calls that collect feedback (lines 117–125) would work. So a REST replacement for `gh pr checks`, such as `gh api repos/$REPO/commits/<sha>/check-runs`, would make the script cloud-ready. The same block hits `gh issue view` in `implement` step 1, `pull-request`, and `diff-review`, and `gh pr create` in `pull-request`. The session has built-in GitHub tools that read issues and open PRs instead.

`Monitor` itself is not listed as unavailable in cloud sessions, unlike some tools ([tools reference](https://code.claude.com/docs/en/tools-reference#monitor-tool)). A watch lasts at most 30 minutes, the same as locally. Background commands in a cloud session also have a 30-minute default limit ([Time limit for background commands](https://code.claude.com/docs/en/tools-reference#time-limit-for-background-commands)).

Auto-fix is the cloud-native alternative. It needs the Claude GitHub App on the repository. It subscribes to GitHub events for the PR, so it reacts to review comments and failed checks without polling. It pushes clear fixes, asks about ambiguous ones, and replies in review threads under the user's GitHub account with a Claude Code label ([Auto-fix pull requests](https://code.claude.com/docs/en/claude-code-on-the-web#auto-fix-pull-requests)). It cannot see a merge conflict, because GitHub sends no webhook for one.

Recommendation: auto-fix is the candidate to own the loop in a cloud session, and the experiment decides. Auto-fix needs no GraphQL and no polling. The fallback is the `Monitor` script with a REST replacement for `gh pr checks`, which keeps the current review discipline. Two parts of the user's rules need checking in the experiment. First, `implement` says "evaluate every comment before acting", and auto-fix decides on its own when a fix is "clear". Second, the global rule says to leave threads open. The docs say auto-fix may reply "as part of resolving them", and **it is unverified** whether that means it marks threads resolved.

## 5. Where does a human step in?

The checkpoints still work, through the conversation. A cloud session can ask a question, and the user answers from claude.ai or the Claude app's Code tab. The session waits for the answer until its environment expires ([Start a cloud session from your terminal](https://code.claude.com/docs/en/claude-code-on-the-web#from-terminal-to-cloud), [mobile](https://code.claude.com/docs/en/mobile#start-and-monitor-cloud-sessions)). So the `tdd` seam confirmation and the `diff-review` decision list work as typed replies. The diff view also takes inline comments that go to Claude with the next message ([Review changes](https://code.claude.com/docs/en/claude-code-on-the-web#review-changes)). **Unverified:** whether `AskUserQuestion` renders as multiple choice in the web and mobile UI or arrives as text.

An idle VM pauses after a few minutes and can later be reclaimed. Reopening restores the conversation, but not background work such as subagents, shell commands, or monitors ([Environment expired](https://code.claude.com/docs/en/claude-code-on-the-web#environment-expired)). A long pause at a checkpoint therefore loses a running `Monitor` watch.

Teleport is a one-way handoff. `claude --teleport <session-id>` fetches the session's pushed branch and loads its conversation into the terminal. It needs a clean working tree, a checkout of the same repository, and the same claude.ai account. After that, the local copy is separate, and work there does not reach the cloud session ([Continue a cloud session in your terminal](https://code.claude.com/docs/en/claude-code-on-the-web#from-cloud-to-terminal)). Teleport is the better handoff for the `diff-review` step when the findings need hands-on judgment, because the decision list is easier to work through locally. It costs the cloud session's isolation: the local checkout then needs its own worktree, port, and databases.

## 6. What does it cost?

There is no separate VM charge. Cloud sessions count toward the plan's usage limits and share them with all other Claude and Claude Code usage, so parallel cloud sessions draw down the same limits as local work, in proportion to how many run ([claude-code-on-the-web](https://code.claude.com/docs/en/claude-code-on-the-web), [Limitations](https://code.claude.com/docs/en/claude-code-on-the-web#limitations)). The docs give no per-session cost figure. The issue's claim is confirmed.

## What the experiment should record

These are the claims this note could not confirm from a source, in the order the experiment will meet them:

1. Whether the setup script can `git clone` the public dotfiles repo when it is not attached to the session.
2. Whether `~/.claude/skills/` and `~/.claude/settings.json` written by the setup script load in the session.
3. How long the Erlang, Elixir, and Hex install takes, and whether it stays under five minutes.
4. Whether `mix assets.setup` can download the Tailwind binary from GitHub releases.
5. What the preinstalled Postgres needs before `mix test` connects.
6. Whether auto-fix resolves review threads, and how it treats a Copilot comment it disagrees with.
7. How `AskUserQuestion` appears on web and mobile.
