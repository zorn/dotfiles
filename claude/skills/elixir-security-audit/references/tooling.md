# Tooling: Hex, Sobelow, CI

Commands and outputs here were checked against Hex 2.5.4 and Sobelow 0.18.1. If a newer version behaves differently, trust what you observe and note the difference in the report.

## Getting mix to run

Real projects often don't run cleanly on the first try. Handle these cases in order:

1. **Version manager refuses to run.** asdf or mise may print "No version is set for command mix" when `.tool-versions` pins versions that aren't installed. Options:
   - Ask the user to install the pinned versions (`asdf install` / `mise install`). This is best if you'll run tests later.
   - For scanning only, use an installed version temporarily, without editing files:
     - asdf: `ASDF_ELIXIR_VERSION=<installed> ASDF_ERLANG_VERSION=<installed> mix ...`. List installed versions with `asdf list elixir` and `asdf list erlang`. Elixir builds like `1.20.1-otp-28` need a matching OTP major.
     - mise: `MISE_ELIXIR_VERSION=... MISE_ERLANG_VERSION=... mix ...`

     Tell the user you're doing this, and why.
2. **Dependencies not fetched.** `mix hex.audit` fails with "the dependency is not available, run mix deps.get". Ask, then run `mix deps.get`. This downloads packages but doesn't compile them.
3. **Dependencies don't compile.** This is common for old projects on a newer OTP. `mix sobelow` will fail, because running a dependency's mix task compiles all dependencies first. Use the standalone Sobelow escript instead. It reads source files without compiling the project.
   - Ask first, because it installs into the user's `~/.mix/escripts`.
   - Install it by running `mix escript.install hex sobelow` from **outside** the project directory.
   - Then run `~/.mix/escripts/sobelow ...` from the project root.

   `mix hex.audit` and `mix hex.outdated` don't need compilation.

## Hex

### Check the version

```sh
mix hex.info
```

The output includes a line like `Hex:    2.5.4`. It may also say "A new Hex version is available".

- **The Hex version you see is the one on this machine,** not the team's or CI's. For the scorecard, judge from CI config, or tell the user each developer should check with `mix hex.info`.
- **Below 2.5.0:** recommend `mix local.hex --force`, a user-level install. Ask first. Explain in one sentence: Hex 2.5.0 added warnings about dependencies with known security advisories, and makes `mix hex.audit` fail on them. Older versions only report retired packages.
- **2.6.0 and later** can also produce SARIF for GitHub code scanning: `mix hex.audit --format sarif --output hex.sarif`.

### Scan

```sh
mix hex.audit       # exit 1 if any dependency is retired or has an advisory
mix hex.outdated    # exit 1 if anything is outdated; this is not an error
```

`mix hex.audit` prints two sections:

```
Retired:
  paginator 0.6.0 - (security) Remote Code Execution Vulnerability

Advisories:
  postgrex 0.17.5 - EEF-CVE-2026-32687 (HIGH)
    aka: CVE-2026-32687, GHSA-r73h-97w8-m54h
    SQL injection via channel name in Postgrex.Notifications.listen/3 and unlisten/3
    https://osv.dev/vulnerability/EEF-CVE-2026-32687
```

- **Both sections go to triage.** A package **retired for `(security)` reasons** can be as dangerous as an advisory, or worse. The example above is an unauthenticated RCE in a real test app. Packages retired for other reasons (`(deprecated)`, `(renamed)`, `(other)`) are maintenance items.
- The advisory severity in parentheses is the generic rating. The real severity depends on whether this app uses the affected function (see `triage.md`).
- `hex.outdated` is context. Being outdated alone is not a vulnerability.
- If the project already has `mix_audit` as a dependency, also run `mix deps.audit`, and merge its results with `hex.audit`. They overlap; deduplicate by CVE/GHSA ID.
- If Hex can't be upgraded yet and `mix_audit` isn't present, it's an alternative. It needs to be added as a dependency, so ask first.

### Elixir, Erlang/OTP, and base image

Note the Elixir/OTP versions in `.tool-versions` and the Docker base image. Some Erlang/OTP vulnerabilities are critical. One example is CVE-2025-32433, an unauthenticated RCE in the Erlang SSH daemon. It matters only if the app starts an SSH server: look for `:ssh` in `extra_applications` and `:ssh.daemon` calls. Flag clearly outdated OTP as a maintenance item.

## Sobelow

### Is it installed?

Check whether Sobelow is already available, in this order. Use the first one found:

1. `{:sobelow, ...}` in `mix.exs`, run with `mix sobelow`
2. `sobelow` on `PATH`
3. `~/.mix/escripts/sobelow`
4. a path the user gives you

The escript takes the same flags as `mix sobelow`. Run it from the project root. Note the version with `--version`. If it's well behind the latest on hex.pm, mention it in the report.

If none of these exist, ask the user to choose one:

- **Add it to `mix.exs`. Recommended, and needed for CI.** Use the latest version from hex.pm (0.18 when this skill was written):
  ```elixir
  {:sobelow, "~> 0.18", only: [:dev, :test], runtime: false}
  ```
  then `mix deps.get`.
- **Global install, nothing added to the project:** `mix escript.install hex sobelow`. Run it as `sobelow` (from `~/.mix/escripts`) in the project root.

### Is it being used?

Look for evidence of triage:

- a `.sobelow-skips` file
- a `.sobelow-conf` file, especially with `ignore:` entries
- `# sobelow_skip [...]` comments: `grep -rn "sobelow_skip" lib/ apps/`
- `-i`/`--ignore` or `--skip` flags in CI files or `mix.exs` aliases

**If none of these exist, report Sobelow as "not effectively in use", even if it is installed.** Sobelow intentionally over-reports. An untriaged project almost always has findings, so having no skips means nobody has gone through the results. The exception: if Sobelow runs in CI with `--exit` and reports zero findings, it is in use. Check by running it.

### Run it

If Sobelow is a project dependency, try `mix sobelow --version` first. Fall back to the standalone escript only if that fails to build. If the dependency is well behind the latest version on hex.pm, still use it, and recommend updating in next steps.

Run from the project root, and write output outside the project. Sobelow shows previously skipped findings unless you pass `--skip`, so leave `--skip` off for the audit:

```sh
mix sobelow --private --format json --out /path/outside/project/sobelow.json
# or, if mix sobelow fails to build: sobelow --private --format json --out ...
```

- `--private` skips Sobelow's update check.
- **No Phoenix router** (library, Plug-only app, worker): add `--no-router`. Sobelow still runs its non-web checks, such as RCE, command injection, SQL, and traversal.
- **Unusual router path:** add `--router path/to/router.ex`.
- **Umbrella apps:** run it in each `apps/*` child, with `--root apps/<name>` or by changing directory into each one.
- **Previous skips:** if skips existed, also run with `--skip` to see which findings were marked skipped. Still triage those, at lower priority. Earlier triage can be wrong.
- `mix sobelow --details CI.System` (or any other type) explains a finding type in plain language. It's useful for the user and for triage agents.

JSON shape:

```json
{"findings": {"high_confidence": [...], "medium_confidence": [...], "low_confidence": [...]},
 "sobelow_version": "0.18.1", "total_findings": 8}
```

- Each finding has `type`, `file`, and `line`. The `type` value combines the module and a description, e.g. `"CI.System: Command Injection via `System` function"`. The part before the colon is the module name used by `--details`, `-i`, and `# sobelow_skip`.
- **The confidence buckets are not severity.** "High confidence" only means Sobelow is sure the pattern exists. In testing, a missing CSP header was "high confidence" while an exploitable SQL injection was "low confidence". Severity comes from triage.

### Recording false positives (Phase 7, only after fixes)

- **Preferred:** a `# sobelow_skip ["Module.Name"]` comment directly above the function, with a short reason. This is reviewable and local.
  ```elixir
  # sobelow_skip ["Traversal.FileModule"]
  # Reason: path is built from a compile-time constant, not user input.
  def load_template(name) do
  ```
- **Bulk:** once every remaining finding is a confirmed false positive, `mix sobelow --mark-skip-all` writes `.sobelow-skips`. It marks **everything currently displayed**, so never run it while true positives remain. `mix sobelow --clear-skip` undoes it.
- Skips only take effect when Sobelow runs with `--skip`.

## CI/CD

Look in:

- `.github/workflows/`
- `.gitlab-ci.yml`
- `.circleci/`
- `bitbucket-pipelines.yml`
- `Jenkinsfile`
- `.buildkite/`
- `mix.exs` aliases, such as a `ci`, `check`, or `precommit` alias

Report:

- Is there CI at all?
- Does it run `mix hex.audit`, or `mix deps.audit`?
- Does it run Sobelow? With `--exit`, so findings fail the build? With `--skip`, so triaged false positives don't?
- Is CI's Hex at least 2.5.0? `mix local.hex --force` in CI installs the latest.

Suggested steps, to offer in Phase 7 (GitHub Actions example):

```yaml
      - name: Install latest Hex (>= 2.5.0 scans for advisories)
        run: mix local.hex --force
      - name: Check dependencies for advisories and retired packages
        run: mix hex.audit
      - name: Sobelow security scan
        run: mix sobelow --private --skip --exit low
```

- `--exit low` fails the build on any finding that hasn't been skipped. `--exit medium` or `--exit high` only fails on findings at or above that Sobelow confidence level, which makes a gentler start.
- Only add a failing Sobelow step **after** existing findings are triaged and skipped. Otherwise CI turns red immediately and people learn to ignore it.
