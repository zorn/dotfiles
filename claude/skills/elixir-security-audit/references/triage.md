# Triage of scanner output

Scanners only read code. They don't know how the app is used, so someone has to decide which results are real. For each result, answer three questions (from the Paraxial.io Sobelow guide):

1. **Is it a true positive or a false positive?**
2. **What is the security impact?**
3. **What is the correct fix?**

Triage everything, but order the work by likely impact, not by Sobelow's confidence bucket:

1. `RCE.*`, `CI.*`, `Misc.BinToTerm`, `Vuln.CookieRCE`, `SQL.*`, and `Traversal.*` first
2. then `XSS.*`, `Config.CSRF*`, `Config.Secrets`, `Config.TLSVerify`, and `Vuln.*`
3. then everything else

## The core method: trace the value

Most findings mean "a dangerous function receives a variable". Find where that variable comes from.

| Source of the value | Usually |
|---|---|
| Hard-coded or compile-time constant, or developer-set config | False positive |
| Request params, path segments, query strings, headers, cookies, LiveView `handle_event`/`handle_params` params, channel payloads, uploaded file names or contents, webhook bodies, job args built from any of these | True positive (attacker-controlled) |
| Database or another store | Find out who writes it. If any user can set it (profile fields, upload names, comments), treat it as attacker-controlled. |
| Another internal service or file | Find out who controls that source |

Write the trace as a chain with `file:line` for every hop, from the entry point (route, LiveView event, channel, job) to the dangerous call (the "sink"). Note anything along the way that breaks the chain: an Ecto `cast` to `:integer`, allowlists, `String.to_existing_atom`, `Path.safe_relative`, authorization plugs.

For GraphQL apps, the entry point is the specific query, mutation, or field, not the `/graphql` route. For Ash apps, it's the action, and its policies are part of the trace.

Then find out who can reach the entry point. Check which router pipeline or `live_session` it sits in. The same bug is Critical behind no login and lower behind an admin-only login.

## Sobelow types: when they're real

| Type | Real when... | Often a false positive when... |
|---|---|---|
| `RCE.CodeModule`, `RCE.EEx`, `RCE.File`, `RCE.Compile` | User input reaches code evaluation, compilation, or a loaded file | Developer-controlled templates or files evaluated at build or boot time |
| `Misc.BinToTerm`, `Vuln.CookieRCE` | Input comes from users (cookies, params, uploads, DB fields users write) | Data the app produced and never exposed. `[:safe]` does **not** prevent RCE; only `Plug.Crypto.non_executable_binary_to_term/2` does. |
| `CI.System`, `CI.OS` (`System.cmd`, `System.shell`, `:os.cmd`; `--details CI.System` only mentions `System.cmd`, but the check also flags `System.shell`, which goes through a shell and is worse) | User input becomes the command, an argument, or shell text | A fixed command with fixed arguments |
| `SQL.Query`, `SQL.Stream` | User input is interpolated (`"... #{x}"`) into the SQL string | Placeholders (`$1`, `?`) with a params list |
| `Traversal.*`, `Misc.FilePath` | A user-controlled path or filename segment | Paths built only from constants or server-generated IDs |
| `XSS.Raw`, `XSS.HTML`, `XSS.SendResp`, `XSS.ContentType` | User-controlled content rendered without escaping, or a user-controlled content type | Static or properly sanitized HTML (check what the sanitizer allows) |
| `Vuln.Redirect` | A user-controlled redirect target (open redirect, useful for phishing) | Redirects to fixed paths |
| `Vuln.HeaderInject` | User input placed in response headers | Fixed header values |
| `DOS.*` (`StringToAtom`, `ListToAtom`, `BinToAtom`, `DecodeAtoms`, `ModuleConcat`, `Consult`) | Unbounded user input becomes atoms or is parsed as Erlang terms | Bounded or internal values. Usually Medium or Low impact (node crash). |
| `Config.CSRF`, `Config.CSRFRoute` | A browser pipeline lacks `:protect_from_forgery`, or a state-changing action is also routed via GET ("action reuse") | API-only pipelines with token auth, not cookies |
| `Config.CSWH` | `check_origin: false` on a socket that uses cookie sessions (LiveView) | Sockets authenticated only by explicit tokens |
| `Config.Secrets` | Real secrets in committed `config/*.exs` | Dev/test-only placeholder values |
| `Config.TLSVerify`, `Config.WeakTLS` | TLS verification disabled on outbound calls carrying credentials or sensitive data | Calls to localhost in dev or test |
| `Crypto.*` | Weak hashes or ciphers protecting passwords, tokens, or signatures | Non-security uses, such as checksums or cache keys |
| `Config.HTTPS`, `Config.HSTS`, `Config.Headers`, `Config.CSP` | Hardening gaps | Usually Low. A missing CSP matters more if XSS exists. **Check what Phoenix already sends:** since Phoenix 1.8, `put_secure_browser_headers` sets `content-security-policy: base-uri 'self'; frame-ancestors 'self';` by default. A `Config.CSP` finding on 1.8+ means "no script restrictions", not "no CSP" (see `put_secure_defaults` in `deps/phoenix/lib/phoenix/controller.ex`). HTTPS may be terminated at the proxy, e.g. Fly or a load balancer, so check deploy config before claiming "no HTTPS". |
| `Vuln.Coherence`, `Vuln.Ecto`, `Vuln.PlugNull` | The version is affected AND the feature is used | Unused feature (still recommend updating) |

## Hex advisories and retired packages

Treat each advisory, and each package **retired for security**, the same way:

1. Read the advisory or retirement message: affected versions, and the vulnerable function or feature.
2. **Find how the project uses that dependency.** Grep for its modules and functions. Check whether attacker-controlled input reaches the vulnerable feature.
   - Example: `paginator` before 1.0 decodes cursors with `binary_to_term`. If a controller passes `params["after"]` into `Repo.paginate(..., after: ...)`, any visitor gets RCE.
   - The dangerous call lives inside the dependency, so neither Sobelow nor a grep of `lib/` for `binary_to_term` will find it. Only this step will.
3. If the feature is used and attacker-reachable, it's a candidate finding. Severity follows the real impact for this app.
4. If it isn't used, it's **not a finding**. Don't send it to Eve. Record it once in the report's scorecard row ("N advisories, none reachable, update recommended"), and add one line to the next steps listing the packages to update. Outdated Elixir or OTP versions without a reachable vulnerability are handled the same way. This keeps the findings list about real risks.

Group advisories that share one fix (e.g. several Plug or Cowboy denial-of-service advisories fixed by one upgrade) into one candidate.

## Output per finding

```
- id: <sobelow module or advisory id> @ <file:line>
  verdict: TRUE_POSITIVE | FALSE_POSITIVE | UNSURE | UNUSED_FEATURE (Hex items only)
  trace: <entry point file:line> -> ... -> <sink file:line>
  reachable_by: <anonymous / any signed-up user / user of another tenant / admin / not reachable>
  attack_summary: <1-2 plain sentences>
  attacker_gains: <what they get>
  suggested_severity: Critical | High | Medium | Low
  fix: <one or two sentences>
  reason_if_false_positive: <why, with file:line>
```

TRUE_POSITIVE and UNSURE results become candidate findings for Eve (`eve.md`). FALSE_POSITIVE results go in the "Checked and ruled out" list. UNUSED_FEATURE results go in the scorecard and next steps (see step 4 above), not in findings.

## Subagent prompt template

```
You are triaging security scanner results for the Elixir project at <project path>.

Threat context:
<paste threat context from intake>

Router/attack-surface summary:
<paste the attack-surface map from Phase 4 step 1>

Findings to triage (<Sobelow module or "Hex advisories">):
<list of file:line entries or advisory text, plus `sobelow --details <Module>` output>

Method: read <skill path>/references/triage.md. For each finding, trace the flagged value
from its entry point to the sink, citing file:line for every hop, and find out who can reach the
entry point. Decide TRUE_POSITIVE, FALSE_POSITIVE, or UNSURE. Do not modify files. Do not
send requests to any deployed environment. Never copy secret values; cite file:line instead.
A finding is TRUE_POSITIVE only if you can show attacker-controlled input reaching the sink
through a path an attacker can actually trigger. Return results in the "Output per finding"
format.
```

If you can't spawn subagents, work through the groups yourself, one at a time, using the same method.
