# Research: Agent Skills validators versus `bin/check-skills`

Primary sources only: repositories, package registries, and the source code each tool runs. Where a claim rests on running a tool rather than reading a document, it says so. Read on 2026-10-27, against `bin/check-skills` with the nesting and fence fixes from [#109](https://github.com/zorn/dotfiles/pull/109).

## Bottom line

**Keep `bin/check-skills`. No tool replaces it, and the official ones would reject this repo's skills.** The spec's reference validator, `skills-ref`, and both vendors' `quick_validate.py` scripts refuse any frontmatter field outside the six the spec defines. That fails 11 of the 19 skills here, because they use Claude Code's `disable-model-invocation` and `argument-hint`. Claude Code's own `claude plugin validate` accepts a bare skills directory, but in a probe it caught only a missing description and passed nine other broken skills. None of the tools compiles `scripts/*.py` or checks spelling. Only [skillscheck](https://github.com/Swival/skillscheck/blob/0.9.7/skillscheck/checks/quality.py#L510-L554) notices a link that leaves the skill directory, and only as an informational note for Markdown under `references/`, `scripts/` and `assets/`, not in `SKILL.md` itself. This repo uses `reference/`, so that check covers none of its files.

The one tool worth a look is [agnix](https://github.com/agent-sh/agnix), a maintained Rust linter that covers the spec rules plus Claude Code's own skill fields. It is a third-party, pre-1.0 tool that ships constantly, so it fits as an occasional manual audit, not as a CI gate.

---

## 1. `skills-ref`, the spec's reference validator

The spec names it as the way to validate: "Use the skills-ref reference library to validate your skills: `skills-ref validate ./my-skill`" ([spec, Validation](https://agentskills.io/specification#validation)).

**Status.** Its README still opens with "This library is intended for demonstration purposes only. It is not meant to be used in production," and still installs from a source checkout with `pip install -e .` ([README](https://github.com/agentskills/agentskills/blob/main/skills-ref/README.md)). The last commit touching `skills-ref/` that changed code or docs was 2026-02-15, a README callout change; the 2026-08-03 commit only consolidated agent guidance files ([commit history](https://github.com/agentskills/agentskills/commits/main/skills-ref)). The repo's `pyproject.toml` says version 0.1.0 and depends on `click` and `strictyaml` ([pyproject.toml](https://github.com/agentskills/agentskills/blob/main/skills-ref/pyproject.toml)).

**Packaging has changed since the `bin/check-skills` docstring was first written.** A `skills-ref` 0.1.1 now exists on PyPI, uploaded 2026-01-10, with Keith Lazuka of Anthropic as the author in its metadata ([PyPI JSON](https://pypi.org/pypi/skills-ref/json)). The repo README does not mention it. The docstring's original "not on PyPI" claim was out of date, so the docstring now rests on the unknown-field rejection below and the "demonstration only" warning, which still holds. The npm package of the same name is an unrelated port by another author, last changed 2025-12-27 ([npm](https://www.npmjs.com/package/skills-ref)).

**What it checks** ([validator.py](https://github.com/agentskills/agentskills/blob/main/skills-ref/src/skills_ref/validator.py)): `SKILL.md` exists; frontmatter parses (strictyaml) and is a mapping; `name` is present, 64 characters or fewer, lowercase, letters, digits and hyphens only, no edge or doubled hyphen, and matches the directory name; `description` is present and 1024 characters or fewer; `compatibility` is a string of 500 characters or fewer. It rejects any top-level field outside `name`, `description`, `license`, `allowed-tools`, `metadata`, `compatibility`. It coerces `metadata` values to strings rather than reporting a non-string ([parser.py](https://github.com/agentskills/agentskills/blob/main/skills-ref/src/skills_ref/parser.py)). I read the published 0.1.1 wheel and it has the same allowed-field set.

**The unknown-field rule is the deal breaker.** The spec itself never says other fields are forbidden; it lists six fields and says `metadata` is where "clients can use this to store additional properties" ([spec, metadata field](https://agentskills.io/specification#metadata-field)). Claude Code documents 20 frontmatter fields, including `disable-model-invocation` and `argument-hint` ([Claude Code skills docs](https://code.claude.com/docs/en/skills)). In this repo, 11 of 19 skills use one of those two, so `skills-ref validate` would fail all 11.

## 2. Anthropic's `skill-creator` `quick_validate.py`

Lives at [skills/skill-creator/scripts/quick_validate.py](https://github.com/anthropics/skills/blob/main/skills/skill-creator/scripts/quick_validate.py), last changed 2026-02-06 ([history](https://github.com/anthropics/skills/commits/main/skills/skill-creator/scripts/quick_validate.py)). It is a script inside a skill, not a package; it needs PyYAML.

**What it checks:** the same allowed-field set as `skills-ref`, with the same rejection of anything else; `name` matches `^[a-z0-9-]+$`, no edge or doubled hyphen, 64 characters or fewer; `description` 1024 characters or fewer and free of `<` and `>`; `compatibility` 500 characters or fewer. It does **not** check that `name` matches the directory, and it stops at the first error.

OpenAI ships a near-copy at [openai/skills `.system/skill-creator/scripts/quick_validate.py`](https://github.com/openai/skills/blob/main/skills/.system/skill-creator/scripts/quick_validate.py), last changed 2025-12-19. Its allowed set omits `compatibility` entirely, so it rejects a spec-valid field. Neither vendor publishes a standalone validator package beyond these scripts.

## 3. Claude Code's `claude plugin validate`

**It does accept a bare skills directory.** Since v2.1.233, given a directory named `skills` with no manifest, it validates the files inside ([plugin commands reference, Validate a directory](https://code.claude.com/docs/en/plugins/cli-reference#plugin-validate)). It has `--strict` and `--json` for CI ([same](https://code.claude.com/docs/en/plugins/cli-reference#plugin-validate)). It does not follow symlinked entries inside the directory ([same](https://code.claude.com/docs/en/plugins/cli-reference#plugin-validate)), which is fine here, since `claude/skills/*` are real directories.

**It checks almost nothing about a skill's frontmatter.** Its documented checks are about plugin manifests: field types, path containment and existence, MCP entries, reserved plugin names ([plugin manifest reference](https://code.claude.com/docs/en/plugins-reference)). Observed on Claude Code 2.1.312: I built a scratch `skills/` tree with ten skills, nine of them broken in a way `bin/check-skills` catches (name not matching directory, uppercase name, 1100-character description, `licence` and `compatability` typos, nested `metadata`, 600-character `compatibility`, a broken relative link, a `../` link, a `scripts/` file that does not compile). `claude plugin validate skills --strict --json` reported exactly one finding, a warning for the skill with no description. `claude plugin validate claude/skills --strict` on this repo passes.

That matches how the runtime behaves: Claude Code "ignores a field it doesn't recognize without reporting an error," does not require `name` to match the directory, and loads a skill with no fields set if its YAML fails to parse ([Claude Code skills docs](https://code.claude.com/docs/en/skills)). The silent failure the docstring describes is real, and this command does not surface it.

## 4. Community linters

A search turns up a dozen or more SKILL.md linters on npm, PyPI and GitHub, most with single-digit stars and created in 2026 ([GitHub search](https://github.com/search?q=skill.md+validator&type=repositories)). The four with real activity or adoption:

| Tool | Install | Activity | Notes |
|---|---|---|---|
| [agnix](https://github.com/agent-sh/agnix) | npm, Homebrew, PyPI, Cargo, GitHub Action | v0.59.3 on 2026-10-24, 458 stars | Rust; 702 rules across a dozen agent tools |
| [skill-check](https://github.com/thedaviddias/skill-check) | npm, Homebrew, curl script | v1.2.0 on 2026-02-21, last push 2026-05-18 | Quality score, `--fix`, bundled security scan |
| [skillmd](https://github.com/skillmds/skillmd) | npm, GitHub Action | `core-v1.0.1` on 2026-10-26 | Lint engine behind a skills registry |
| [skillscheck](https://github.com/Swival/skillscheck) | `uvx skillscheck` | 0.9.7 on 2026-08-20, 7 stars | Python; needs PyYAML, click, tiktoken ([pyproject.toml](https://github.com/Swival/skillscheck/blob/main/pyproject.toml)) |

**agnix is the one I read in depth, because it is the only one both maintained and broad.** Its rule catalog ([knowledge-base/rules.json](https://github.com/agent-sh/agnix/blob/main/knowledge-base/rules.json), version 1.1.0, updated 2026-10-17) and validator source ([rules/skill/mod.rs](https://github.com/agent-sh/agnix/blob/main/crates/agnix-core/src/rules/skill/mod.rs)) cover:

- The spec rules: name format and edge/double hyphens (AS-004 to AS-006), name matches directory (AS-017), description 1 to 1024 characters (AS-008), compatibility length (AS-011), `metadata` must be a string-to-string map (in AS-001/AS-016), parse errors (AS-016), body over 500 lines (AS-012), reference chains too deep (AS-013).
- Broken relative Markdown links (REF-002) ([rules.json](https://github.com/agent-sh/agnix/blob/main/knowledge-base/rules.json)).
- Claude Code's own fields: an unknown field measured against Claude Code's documented list (CC-SK-017), and value checks for `model`, `context`, `effort`, `shell`, `paths`, `hooks`, and the `disable-model-invocation` and `user-invocable` types (CC-SK-001 to CC-SK-020) ([rules.json](https://github.com/agent-sh/agnix/blob/main/knowledge-base/rules.json)).
- Taste rules `bin/check-skills` does not attempt, such as a description lacking a when-to-use trigger (AS-020) or not in the third person (CC-SK-032).

**The target changes what it checks.** With `--target claude-code`, agnix follows Claude Code's looser rules. On agnix 0.59.3, a probe skill whose name did not match its directory, a 1112-character description, and a numeric `metadata` value all passed under that target. The generic target flagged the description length and the metadata (observed). The table below gives both.

It treats any file named `SKILL.md` as a skill, whatever its directory ([detection.rs](https://github.com/agent-sh/agnix/blob/main/crates/agnix-core/src/file_types/detection.rs)), so `agnix claude/skills` finds this repo's skills.

**Observed on agnix 0.59.3:** `npx agnix --target claude-code claude/skills` reports 0 errors and 0 warnings on this repo, so it has nothing to port into `CASES` today. A scratch skill with deliberate faults confirms that the clean result is real. agnix flagged an uppercase `name`, an invalid `effort: extreme`, and a description with no when-to-use trigger. The other agnix claims in this note come from its source and rule catalog, not from a run.

## 5. Point by point

| `bin/check-skills` check | `skills-ref` | `quick_validate.py` | `claude plugin validate` | agnix (generic / `--target claude-code`) |
|---|---|---|---|---|
| Name format | Yes | Yes | No (observed) | Yes |
| Name matches directory | Yes | No | No (observed) | Generic yes (AS-017); Claude Code no (observed) |
| Description length | Yes | Yes | Only missing (observed) | Generic yes (observed); Claude Code no (observed) |
| Field-name typos | Rejects every non-spec field | Rejects every non-spec field | No (observed) | Unknown against Claude Code's list |
| Compatibility length | Yes | Anthropic yes; OpenAI rejects the field | No (observed) | Yes (observed, both targets) |
| `metadata` is a string map | Coerces, no error | No | No (observed) | Generic yes (observed); Claude Code no (observed) |
| A ` #` that silently truncates a value as a comment | No, full YAML parser | No, PyYAML | No | No, serde_yaml |
| Relative link resolves | No | No | No (observed) | Yes (REF-002) |
| Link stays inside the skill directory | No | No | No (observed) | Not found in its rules |
| `scripts/*.py` compiles | No | No | No (observed) | No |
| British spellings | No | No | No | No |
| Install for CI | PyPI, two deps | Copy script, PyYAML | Claude Code binary | npm, pip, brew, cargo, Action |

Two rows matter most. Every other tool parses frontmatter with a full YAML library, so none flags the ` #` comment that truncates a description, which is the reason the docstring gives for its narrow parser. And the containment check exists because each skill is linked into `~/.claude/skills` on its own. skillscheck reports an escaping link only as information, and only outside `SKILL.md`, so none of these tools fails the build on one.

## Recommendation

**Keep `bin/check-skills` as the CI gate, and adopt nothing into CI.**

- `skills-ref` and the `quick_validate.py` scripts would fail 11 of 19 skills on fields Claude Code documents, and still miss links, scripts and spelling.
- `claude plugin validate` adds nothing a `bin/check-skills` pass does not already cover. It also needs Claude Code installed on the runner.
- agnix adds the most coverage, mostly Claude Code value checks such as a misspelled `effort` level. Pinning it in CI means either a curl'd pin and checksum that Dependabot cannot see, like the other tools in `ci.yml`, or a new npm or pip manifest added only for it. Either way it is a pre-1.0 tool that releases every few days.
- Other tools add narrower checks. skillscheck, for example, [reports a link to a heading that does not exist](https://github.com/Swival/skillscheck/blob/0.9.7/skillscheck/checks/quality.py#L368-L410), which `bin/check-skills` does not check.

An occasional manual `npx agnix --target claude-code claude/skills` gets that coverage without the upkeep. Port any finding worth keeping into `CASES`. That target skips the name, description-length and metadata checks, but `bin/check-skills` already covers those. The first such run, on 2026-10-27, came back clean.
