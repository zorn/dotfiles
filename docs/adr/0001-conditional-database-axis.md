# Conditional Database Axis

The `/diff-review` skill's original three axes — Standards, Spec, Prose — are unconditional quality lenses that run on every review. The Database axis added for [issue #33](https://github.com/zorn/dotfiles/issues/33) breaks that pattern deliberately: it runs only when the diff shows database signals (migrations, `schema do`, `Repo.` calls, raw SQL), and its migration-safety concern defers to project tooling — when the project depends on `excellent_migrations` or the equivalent Ecto Credo checks, the agent skips that concern and lets CI own it. We accepted the extra detection logic because the alternative, an always-on database axis, either wastes a sub-agent on the common no-DB PR or duplicates checks a project's own linter already enforces.

## Consequences & Tradeoffs

The rejected alternative was to treat Database like the other three: always spawn it, and let it self-report "nothing to review" — the way Spec skips when there's no spec. That is simpler in the skill, but it spends a sub-agent on every database-free change and, worse, re-flags migration hazards that `excellent_migrations` already blocks in CI, training the reader to ignore the axis. Gating on diff signals and deferring to a named dependency keeps the axis quiet exactly when another mechanism has the concern covered.

The cost is that the Database axis is no longer orthogonal to the others the way Standards, Spec, and Prose are to each other. It is a domain axis, not a quality dimension, so it can overlap Standards, and its behavior now depends on facts about the project (which dependencies it pulls in) rather than only on the diff. That coupling is the price of not crying wolf.
