# No Correctness Axis

`/diff-review` has no axis for code that is wrong in general — nil handling, an off-by-one, a race — even though the gap is real: Spec catches wrong-against-the-spec, and nothing else in the skill catches a plain bug. When the Tests axis was added for [issue #36](https://github.com/zorn/dotfiles/issues/36), a Correctness axis beside it was the obvious next step, and we chose instead to leave correctness to the native `/code-review` skill, which already owns it with effort levels, `--fix`, and `--comment`, and which the `/implement` flow already prompts after the PR.

## Consequences & Tradeoffs

The rejected alternative was a correctness sub-agent running in parallel with the other axes. It would produce a second bug list overlapping `/code-review`'s, and the two would drift as each is tuned separately. The cost of leaving it out is that a reader of a `/diff-review` report could assume correctness was checked; the report footer names `/code-review` as the correctness step so the omission is stated rather than assumed.
