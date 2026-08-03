# Good and Bad Tests

Examples are Elixir/ExUnit, following the conventions these projects already use: one `describe` block per `function/arity`, test names prefixed `success:` or `failure:`, and assertions written as pattern matches so the shape is part of the assertion.

## Good Tests

**Integration-style**: test through the real context function, not a fake of some internal part.

```elixir
describe "create_ballot/1" do
  test "success: creates an unpublished ballot that is retrievable from the repo" do
    {:ok, %Ballot{id: id}} =
      RankedVoting.create_ballot(%{
        question_title: "What is your favorite color?",
        possible_answers: "Red, Green, Blue",
        url_slug: "favorite-color"
      })

    assert %Ballot{question_title: "What is your favorite color?", published_at: nil} =
             RankedVoting.get_ballot!(id)
  end
end
```

Characteristics:

- Tests behavior callers care about
- Goes through the context's public functions only
- Survives internal refactors — schema changes, query rewrites, new private helpers
- Describes WHAT, not HOW
- One logical assertion per test

The pattern match in `assert %Ballot{…} = …` is deliberate: it asserts the fields under test and ignores the rest, so an unrelated new field does not break the test.

## Bad Tests

**Implementation-detail tests**: coupled to internal structure.

```elixir
# BAD: asserts on a private helper rather than the behavior
test "create_ballot normalizes the slug" do
  assert "favorite-color" == RankedVoting.normalize_slug("Favorite Color")
end
```

Red flags:

- Reaching for a private function, or making one public just to test it
- Asserting on how many times something was called
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying through a side channel instead of the interface

```elixir
# BAD: bypasses the context to check the database directly
test "create_ballot writes a row" do
  {:ok, _} = RankedVoting.create_ballot(@valid_attrs)
  assert [%{question_title: "What is your favorite color?"}] = Repo.all(Ballot)
end

# GOOD: verifies through the same interface a caller would use
test "success: a created ballot is retrievable" do
  {:ok, %Ballot{id: id}} = RankedVoting.create_ballot(@valid_attrs)
  assert %Ballot{question_title: "What is your favorite color?"} = RankedVoting.get_ballot!(id)
end
```

Reaching for `Repo` directly in a context test is the clearest form of this: it tests that a row exists rather than that the capability works, so a rename of the table breaks the test while a broken read path does not.

**Tautological tests**: the expected value restates the implementation, so the test passes by construction.

```elixir
# BAD: expected value is computed the way the code computes it
test "total_cents sums the expenses" do
  expenses = [%Expense{amount_cents: 1000}, %Expense{amount_cents: 500}]
  expected = Enum.reduce(expenses, 0, & &1.amount_cents + &2)
  assert expected == Tracking.total_cents(expenses)
end

# GOOD: expected value is an independent, known literal
test "success: total_cents sums the expenses" do
  expenses = [%Expense{amount_cents: 1000}, %Expense{amount_cents: 500}]
  assert 1500 == Tracking.total_cents(expenses)
end
```

## Finding the highest seam

"Test at the highest seam" means the highest one **this project already has**, which is not the same in every repo. Look before choosing, and never add a dependency to reach a nicer seam — a project that has not adopted a testing library has not asked for one.

Roughly, highest first:

1. **`PhoenixTest`**, when `mix.exs` already depends on it. `visit/2`, `click_button/2`, `fill_in/3`, and `assert_has/3` drive the real router, the LiveView lifecycle, and the rendered markup, so one test covers the path a user actually takes and survives almost any refactor beneath it. `local_cents` wraps this in a `FeatureCase`.
2. **`ConnCase` with `Phoenix.LiveViewTest`** — `live/2`, `render_click/2`, `has_element?/2`. The standard Phoenix seam, present in every Phoenix project. `flick` tests its web layer here.
3. **Context functions with `DataCase`** — the seam most business logic belongs at, and the one to prefer when the behavior under test is not about the page.
4. **Plain functions with `ExUnit.Case, async: true`** — for anything pure. Cheapest to write and to read; use it whenever the behavior does not need the repo.

A behavior is usually testable at more than one of these. Pick the highest rung that can observe it, then stop — a context test that could have been a plain function test pays for a database it never needed.

- **`async: true` unless something genuinely shared prevents it** — and when it does, say why in a comment above the `use` line, since the next reader will otherwise assume it was an oversight.
- **Fixtures over inline setup** for anything built more than once; put them in `test/support/fixtures/` and name them `<Thing>Fixture`.
- **`doctest` the modules whose docs carry examples.** A doctest that drifts fails the build, which is the cheapest documentation test there is.
- **Table-driven cases** — where one function is exercised across many input combinations, a parameterized table reads better than a dozen near-identical tests and makes a missing case visible as a missing row.
