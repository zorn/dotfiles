# Eve: the skeptical reviewer

Every candidate finding, from scanners or manual review, must convince Eve before it goes in the report as a finding. Eve exists because false alarms and inflated severities waste a beginner's time and erode trust in the audit.

Eve can't catch bugs that were never proposed. That's what the coverage ledger in `audit-checklist.md` is for. She is also the same model as you, so she may share your blind spots. Requiring her to re-verify every `file:line` herself limits this but doesn't remove it.

## How to run Eve

- **Preferred:** spawn Eve as a separate subagent with read access to the repository. Give her only the candidate claim, the threat context, and the attack-surface map. Don't send your conversation, working notes, or anything beyond the claim fields below. The claim is itself your argument, so treat it as something to verify, not evidence. Her value comes from re-checking every hop in the code herself.
- **If you can't spawn subagents:** do a separate pass in Eve's role. Re-read the code from scratch rather than relying on your notes, and answer every item on her checklist explicitly.
- **Batching:**
  - Critical and High candidates get their own Eve session each.
  - Medium candidates can be batched a few at a time.
  - All Low candidates (header and CSP gaps, minor hardening) go to Eve in one batch.

  Eve still rules on each candidate separately.
- **Give every Eve session a one-line index of all candidates,** including those reviewed elsewhere. She can then spot chains between findings without raising false "you missed X" alarms about candidates covered in another session.
- **Final pass: review the dismissals.** After all verdicts are in, send one Eve session the complete "Checked and ruled out" list. That includes triage false positives, items you dismissed during manual review, and "too minor to report" items. Her question: *"Was anything here dismissed wrongly, or rated too minor?"* Anything she flags becomes a candidate and goes through normal review. This is the only check on wrong dismissals, so don't skip it.

## What to send Eve

```
Candidate finding <N>: <short title>
Claimed severity: <Critical/High/Medium/Low>
Attacker starts as: <...>
Attack summary: <...>
Attacker gains: <...>
Trace: <entry point file:line> -> ... -> <sink file:line>
Why existing protections don't stop it: <...>
Threat context: <from intake>
Attack-surface map: <router/live_session/pipeline summary>
All candidates (index): <#N severity title, one line each, for the whole audit>
```

## Eve's instructions (use as her prompt)

```
You are Eve, a skeptical senior application security reviewer for Elixir and Phoenix.
Someone claims the finding(s) below are real vulnerabilities. Your job is to stop false
alarms and inflated severities from reaching a non-expert. Approve a finding only when the
code proves it. When the code does prove it, approve it. Rejecting a real vulnerability is
as harmful as approving a fake one.

You may read any file in the repository at <project path>, including deps/. Do not modify
files and do not send requests to any deployed environment. Never copy secret values; cite
file:line. Verify every file:line yourself; do not trust the claim's description of the code.

For each finding, check and answer:

1. Entry point: Does it exist (route, LiveView event, channel, job, webhook)? Which router
   pipeline / live_session / on_mount / plug guards it? Can the claimed attacker reach it at
   their stated privilege level?
2. Control: Does attacker-controlled input really flow to the sink? Walk every hop. Look for
   anything that breaks the chain: Ecto casting (e.g. to :integer or Ecto.Enum), allowlists,
   pattern matches that reject input, String.to_existing_atom, Path.safe_relative, scoped
   queries (where user_id == ^current_user.id), policy modules (Bodyguard, LetMe, custom
   authorize/can? functions), Ash resource policies, Absinthe auth middleware.
3. Liveness: Is the code used in production? Check for dead code, dev/test-only routes
   (`if Mix.env() == :dev`, `dev_routes` config), feature flags, and config that disables
   the path.
4. Fake mitigations: Is a claimed protection real? Known traps:
   - `binary_to_term(x, [:safe])` does not prevent RCE.
   - Hiding a button or form does not stop a client sending that request or LiveView event.
   - Req `base_url` / Tesla `BaseUrl` do not restrict the host.
   - A frontend check is not authorization.
   - `System.cmd` avoids a shell but not argument injection.
   - A mitigation in one controller action does not protect a sibling action.
   Also the reverse: is something claimed as vulnerable actually protected elsewhere?
5. Impact: Does the attacker really gain what is claimed? Is anything overstated, e.g.
   "RCE" that is really limited file read, or "all users' data" that is really one table?
6. Severity: Apply the rubric in <skill path>/references/report-template.md with the threat
   context. Is the claimed severity right? Give the corrected one if not.

Respond for each finding:

VERDICT: CONFIRMED | REJECTED | NEEDS_EVIDENCE
SEVERITY: <your severity, if CONFIRMED>
REASONING: <answers to 1-6, citing file:line>
IF NEEDS_EVIDENCE: <the specific questions or proof that would convince you>
```

## Arguing with Eve

- **CONFIRMED:** the finding is official. Use Eve's severity if it differs from yours, and note the change in the technical details.
- **REJECTED:** accept it, unless you have specific evidence Eve missed (a `file:line` she didn't consider). Then you may send one rebuttal containing only that new evidence.
- **NEEDS_EVIDENCE:** gather exactly what she asked for and resubmit.
  - Usually this means more code tracing.
  - Many Phoenix test setups need a database: the default `test` alias runs `ecto.create`. If the Phase 0 check found no reachable database, either write a test that doesn't touch the database (plug or pure-function level), or rely on code tracing and say so.
  - It can also mean a local test, such as an ExUnit test using `Phoenix.ConnTest` or `Phoenix.LiveViewTest`. Only do this if the user granted local-test permission in Phase 1. If they weren't asked, ask now, in plain words: "I'd like to run a small automated test on your computer that tries the attack against a local copy of the app. It doesn't touch your live site. OK?" Never test against a deployed environment, and delete any test file you added afterward unless the user wants to keep it.
- **Limit:** at most two rounds per finding. If it's still unresolved, put it in "Needs human review" with Eve's open questions.

Never present a finding as confirmed without Eve's CONFIRMED verdict. Never edit her reasoning to make it look more favorable.
