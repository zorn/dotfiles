# Deepening

How to deepen a cluster of shallow modules safely, given its dependencies. Assumes the vocabulary in [SKILL.md](../SKILL.md) — **module**, **interface**, **seam**, **adapter**.

## Dependency categories

When assessing a candidate for deepening, classify its dependencies. The category determines how the deepened module is tested across its seam.

### 1. In-process

Pure computation, in-memory state, no I/O. Always deepenable — merge the modules and test through the new interface directly. No adapter needed.

### 2. Local-substitutable

Dependencies that run for real in the test suite — Postgres behind `DataCase`'s sandbox, a temp directory for the filesystem. Deepenable when they do, and the deepened module is tested against the real thing. The seam is internal; no port at the module's external interface.

### 3. Remote but owned (Ports & Adapters)

Your own services across a network boundary (microservices, internal APIs). Define a **port** (interface) at the seam. The deep module owns the logic; the transport is injected as an **adapter**. Tests use an in-memory adapter. Production uses an HTTP/gRPC/queue adapter.

Recommendation shape: *"Define a port at the seam, implement an HTTP adapter for production and an in-memory adapter for testing, so the logic sits in one deep module even though it's deployed across a network."*

### 4. True external (Fake)

Third-party services (Stripe, Twilio, etc.) you don't control — the one category `tdd` says is worth faking. The deepened module takes the dependency as an injected port; tests supply a fake adapter, which in Elixir is a real module swapped in by config rather than anything a mocking library builds.

## Seam discipline

The one-adapter and internal-versus-external rules are in [SKILL.md](../SKILL.md), and they bind here too.

## Testing strategy: replace, don't layer

- Old unit tests on shallow modules become waste once tests at the deepened module's interface exist — delete them.
- Write new tests at the deepened module's interface. The **interface is the test surface**.
- Tests assert on observable outcomes through the interface, not internal state.
- Tests should survive internal refactors — they describe behavior, not implementation. If a test has to change when the implementation changes, it's testing past the interface.
