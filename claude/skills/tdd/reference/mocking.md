# When to Fake a Boundary

The default in these projects is **no mocking library at all**. Neither `flick` nor `local_cents` pulls in Mox, Mimic, or Hammox, and their tests are none the worse for it — the database runs for real inside a sandboxed transaction, and everything else is exercised through the context it lives behind.

Start there. Reach for a fake only when the real thing cannot run in a test, and treat needing one as a design signal before treating it as a testing problem.

## What genuinely needs faking

- **Third-party HTTP APIs** — payment, email, anything you would be billed for or rate-limited by.
- **Time and randomness**, where the behavior under test depends on them.
- **The file system**, sometimes — though a temp directory is usually better than a fake.

## What does not

- **The database.** `DataCase` wraps each test in a transaction that rolls back, so the real repo is both faster to reason about and more honest than a fake.
- **Your own contexts and modules.** A test that fakes one of your modules in order to test another is testing the wiring, not the behavior.
- **Anything you control.** If it is yours and it is slow, that is worth fixing rather than hiding.

## How to fake, when you must

Elixir's answer is a **behaviour plus a config-swapped implementation**, not a mocking library. The seam is a module name resolved at runtime:

```elixir
# lib/my_app/mailer.ex
defmodule MyApp.Mailer do
  @callback deliver(MyApp.Email.t()) :: :ok | {:error, term()}

  def impl, do: Application.get_env(:my_app, :mailer, MyApp.Mailer.Live)
end

# config/test.exs
config :my_app, :mailer, MyApp.Mailer.Fake
```

Callers go through `MyApp.Mailer.impl().deliver(email)`, and test config supplies a fake that records what it was handed. Two things make the indirection worth it:

- **The fake is a real module**, so it compiles, can be read on its own, and cannot drift from the behaviour without the compiler saying so.
- **The swap is one line of config**, so no test has to know it happened.

A fake that sends messages to the test process — `send(self(), {:delivered, email})`, asserted with `assert_received` — beats one that counts calls. It checks the observable outcome instead of the interaction.

## Prefer a narrow interface over a mockable one

If faking a boundary is awkward, the interface is usually too wide. One callback per external operation is easier to fake than a single generic caller with a `case` inside it:

```elixir
# GOOD: each operation is independently fakeable
@callback fetch_user(user_id :: String.t()) :: {:ok, map()} | {:error, term()}
@callback fetch_orders(user_id :: String.t()) :: {:ok, [map()]} | {:error, term()}

# BAD: the fake now needs conditional logic to work out what it is being asked for
@callback request(path :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
```

The narrow version means each fake returns one shape, no branching in test setup, and the set of external operations a test exercises is visible from the callbacks its fake implements. That is `codebase-design`'s **depth** argument applied to a seam you have to cross in tests.
