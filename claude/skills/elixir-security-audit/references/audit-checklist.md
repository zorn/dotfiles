# Manual audit checklist

Scanners miss most access control bugs, most SSRF bugs, and vulnerabilities inside dependencies, because those depend on what the app is supposed to do. The manual review is where they get found.

Each item gives search patterns as a starting point. A grep hit is only a lead: trace the data flow (`triage.md`) before calling anything a candidate.

## Step 1: Map the attack surface and start a coverage ledger

Build a map of every way input enters the app.

- **Router** (`lib/*_web/router.ex`, plus any `forward`ed routers): every `scope` and `pipe_through`, and which pipelines authenticate (`:require_authenticated_user`, `:fetch_current_user`, API token plugs). Compare pipelines carefully. A second "browser" pipeline that's missing `:protect_from_forgery` is a classic bug.
- **LiveViews:** `live_session` blocks and their `on_mount` hooks. Note which LiveViews do their own checks in `mount/3`, and list every `handle_event` and `handle_params`.
- **Channels and sockets:** `socket "/..."` in `endpoint.ex`, `connect/3`, `join/3`, `handle_in`, and `check_origin` settings.
- **APIs and webhooks:** JSON pipelines and how they authenticate. Webhook signature verification (Stripe, GitHub, etc.).
- **GraphQL (Absinthe):** look for `use Absinthe.Schema` and `forward ..., Absinthe.Plug` in the router. A single GraphQL route hides many entry points. Every query, mutation, and subscription field, and every field resolver that loads related records, is its own ledger entry. Note:
  - how `current_user` gets into the Absinthe context (a context plug or `Absinthe.Plug` options)
  - which middleware enforces auth
  - whether `Absinthe.Plug.GraphiQL` is mounted in production
- **Ash:** look for `use Ash.Resource` and `use Ash.Domain`. Every action exposed through AshJsonApi, AshGraphql, AshPhoenix forms, or code interfaces is a ledger entry. Access control lives in each resource's `policies do ... end`, not in controllers. Note:
  - which resources have `authorizers: [Ash.Policy.Authorizer]`
  - the domain's authorization settings
  - whether `ash_admin` is mounted in production
- **Non-HTTP input:** background jobs (Oban args), queue consumers (Broadway, GenStage), GenServers fed by external systems, CLI or mix tasks, and email ingestion. For a library, its public functions are the entry points: what happens when callers pass untrusted data?
- **Admin and dev tools in production:**
  - `live_dashboard`
  - `Oban.Web`
  - `Kaffy`, `ex_admin`, `Backpex`
  - `/dev/mailbox` (`Plug.Swoosh.MailboxPreview`)
  - `ErrorTracker`
  - `Absinthe.Plug.GraphiQL`, `ash_admin`

  Check whether each sits behind auth, or inside `if Mix.env() == :dev` or `if Application.compile_env(..., :dev_routes)`.
- **Dependencies that handle user input:** pagination cursors, file upload libraries, markdown and HTML renderers, image processing, PDF generation, and serialization libraries. Note how app code passes user input into them.

Turn the map into a **coverage ledger** with one line per entry point, marked as reviewed with a verdict. Count these as entry points:

- every route (`get`, `post`, `live`, `forward`, etc.)
- every `handle_event`, every `handle_params`, and every `handle_info` that acts on data from another user or an external system
- every channel `join` and `handle_in`
- every job and consumer
- every GraphQL field with a resolver
- every exposed Ash action

Dev-only routes (behind `Mix.env() == :dev` or `dev_routes`) can share one line that confirms they're excluded from production.

```
GET  /invoices/:id         InvoiceController.show     [:browser, :require_auth]  reviewed: scoped to current_user.org_id, OK
POST /invoices/:id/notes   InvoiceController.add_note [:browser_auth]            reviewed: candidates #3 (no CSRF), #4 (author from params)
live InvoiceLive.Index     handle_event "delete"      live_session :authed       reviewed: candidate #5 (no ownership check)
job  ImportWorker.perform  args["url"]                Oban                       NOT REVIEWED (time)
```

The ledger goes in the report's coverage section. Anything not reviewed is listed there as not reviewed. Nothing should be silently skipped.

**Large apps** (roughly 50+ routes or events): if you can spawn subagents, split the ledger by area, e.g. by router scope, Phoenix context, or LiveView directory. Give each agent its slice, the threat context, and this checklist. Each agent returns candidates in the `triage.md` output format, plus its slice of the ledger. Without subagents, work slice by slice and save the ledger to a scratch file as you go.

## Step 2: Remote code execution (RCE)

The attacker runs their own code on the server. This is almost always Critical.

| Look for | Grep | Notes |
|---|---|---|
| Code evaluation | `Code.eval_string`, `Code.eval_quoted`, `Code.eval_file`, `Code.compile_string`, `Code.require_file`, `EEx.eval_string`, `EEx.eval_file` | Any user influence over the code or file path is RCE |
| Unsafe deserialization | `binary_to_term` (in `lib/` **and** in `deps/` for libraries that receive user input) | `[:safe]` does NOT prevent RCE: anonymous functions in the decoded term can run later, e.g. through `Enum` on a function. Fix: `Plug.Crypto.non_executable_binary_to_term/2`. Check cookies, params, Base64 blobs, pagination cursors, cache entries, and DB columns users can write. |
| Shell and OS commands | `System.shell`, `:os.cmd`, `System.cmd`, `Port.open`, `:erlang.open_port` | `System.shell`/`:os.cmd` with user input is shell injection. `System.cmd` with a list avoids the shell, but a user-controlled executable or arguments can still be dangerous (argument injection such as `--output=`). Check wrappers for ImageMagick, ffmpeg, git, pandoc. |
| Dynamic dispatch | `apply(`, `Kernel.apply`, `Module.concat`, `String.to_existing_atom`/`String.to_atom` feeding `apply` | A user-chosen module and function means calling arbitrary functions such as `System.cmd` |
| Template injection | User content used **as** an EEx/HEEx template, not as assigns | Same as `EEx.eval_*` |
| Erlang distribution | `RELEASE_COOKIE`, `--cookie`, `rel/env.sh.eex`, `rel/vm.args.eex`, ports 4369 (epmd) and dist ports in deploy config | A known or committed cookie plus reachable distribution ports is full RCE |
| Erlang SSH daemon | `:ssh.daemon`, `:ssh` in `extra_applications` | CVE-2025-32433 (pre-auth RCE) on unpatched OTP |
| Forged sessions | Hard-coded or committed `secret_key_base`/signing salts used in prod | Lets an attacker forge session cookies: takeover of any account, including admins |

## Step 3: Access control

A user does or sees something they shouldn't. This is the most common serious bug class in real Phoenix apps, and scanners rarely find it. Severity depends on intake Q5: with open signup, every "logged-in user" bug is exploitable by any attacker.

For every ledger entry, ask: **who is allowed to do this, and where in the code is that enforced?**

- **Unprotected routes:** sensitive controllers or LiveViews outside authenticated pipelines or `live_session`s. Admin routes that check only "logged in", not "is admin".
- **IDOR (insecure direct object reference):** `Repo.get`, `Repo.get!`, or `Repo.get_by` with an id from params and no owner or tenant scoping.
  - Correct patterns look like `Repo.get_by!(Post, id: id, user_id: current_user.id)` or a query with `where: p.org_id == ^scope.org_id`.
  - Check every action: show, edit, update, delete, download, export.
- **Identity taken from the client:** `user_id`, `email`, `author`, `org_id`, or `role` read from params or a hidden form field, then used to decide who is acting or who owns a record. It must come from `conn.assigns.current_user` / `socket.assigns.current_scope`. Example: a review form that looks up the author by `review_params["email"]` lets anyone post as anyone.
- **LiveView events:**
  - Every `handle_event` that modifies or reveals data must authorize on its own.
  - Clients can send **any** event with **any** params, even for buttons the template never rendered.
  - `mount/3` checks don't protect events, and `handle_params/3` reruns on patch navigation.
- **Channels:** `join("room:" <> id, ...)` must check the user may access `id`. Every `handle_in` must authorize too.
- **GraphQL (Absinthe):**
  - Every mutation and every sensitive query field needs an auth check in its resolver or middleware. A check on the parent query doesn't protect nested fields. For example, `post { author { email } }` can expose fields the `user` query itself would refuse.
  - Dataloader sources and batch functions must apply the same owner or tenant scoping as the resolvers.
  - Subscriptions must authorize in their `config` function.
  - Without `max_complexity`/`analyze_complexity` or depth limits, deeply nested queries can be a DoS (Medium).
  - Introspection and GraphiQL in production are information disclosure (Low), unless they reveal admin-only operations.
- **Ash:**
  - Resources holding user or tenant data with no `Ash.Policy.Authorizer`, or with policies that don't cover every action, including read actions and actions added later.
  - Calls with `authorize?: false`, and calls that never pass `actor:`. Check how the domain's authorization settings treat a missing actor.
  - `accept :*`, or `accept` lists that include role, owner, or tenant attributes, are Ash's form of mass assignment.
  - Attributes and relationships marked `public?: true` that expose sensitive data through AshJsonApi or AshGraphql.
  - Multi-tenancy: confirm the `multitenancy` strategy is set, and that a `tenant` is always supplied.
- **Mass assignment:** `cast(attrs, [...])` (grep `\bcast(` so you don't match `broadcast(`) that includes `:role`, `:is_admin`, `:admin`, `:org_id`, `:user_id`, `:owner_id`, `:confirmed_at`, `:balance`, or plan/billing fields, in changesets that public forms or APIs use.
- **Auth flows** (especially if `phx.gen.auth` code was modified):
  - Reset and confirmation tokens: single use, expiring, hashed.
  - Email change confirmation.
  - Session renewal on login.
  - Magic link reuse.
  - OAuth account linking by unverified email.
- **API tokens:** scoped to an owner? Revocable? Compared with `Plug.Crypto.secure_compare`?
- **Admin and dev tools** from Step 1 that are exposed without auth.
- **Multi-tenancy:** every tenant-data query must be scoped by tenant. Look for one missing scope in list and search endpoints, exports, and background jobs.

## Step 4: Server-side request forgery (SSRF)

The attacker makes the server send requests to places it shouldn't: cloud metadata (credential theft), internal admin services, or private networks.

| Look for | Grep |
|---|---|
| HTTP clients with a user-influenced URL | `Req.get`, `Req.post`, `Req.request`, `Req.new`, `Tesla.`, `HTTPoison.`, `Finch.build`, `Mint.HTTP.connect`, `:httpc.request`, `:hackney.request` |
| URL-taking features | Webhooks, "import from URL", avatar or image URL, link previews, RSS, OAuth/OIDC discovery URLs, HTML-to-PDF rendering of user HTML (`ChromicPDF`, wkhtmltopdf) |

Key points:

- Req's `base_url` and Tesla's `BaseUrl` are **not** security boundaries. An absolute URL passed as the request URL overrides them.
- Req follows redirects by default, so validating only the first URL isn't enough.
- Allowlists must check the **resolved IP**, not the hostname string. Watch for `127.0.0.0/8`, `10/8`, `172.16/12`, `192.168/16`, `169.254.169.254`, `::1`, `fd00::/8` (Fly.io private networking uses `fdaa:` addresses and `.internal` hostnames), and Kubernetes service DNS.
- Impact depends on hosting (intake Q4). SSRF that returns responses from a cloud metadata service can leak credentials (Critical). Blind SSRF with no response returned is usually lower.

## Step 5: Remote file inclusion and path traversal

The attacker reads or writes files they shouldn't, or makes the server load their file.

| Look for | Grep |
|---|---|
| File access | `File.read`, `File.write`, `File.rm`, `File.stream!`, `File.cp`, `File.open`, `Path.join`, `Path.expand` |
| Serving files | `send_file`, `send_download`, `Plug.Static` with unusual `from:` |
| Uploads | `consume_uploaded_entries`, `Plug.Upload`, `client_name`/`filename` used in a path |
| Archives | `:zip.unzip`, `:zip.extract`, `:erl_tar.extract` ("zip slip": entries named `../../...`) |
| Loading code or templates from a path | `Code.require_file`, `Code.compile_file`, `EEx.eval_file`, `:file.consult`, `render` with a user-chosen template name |

Key points:

- Fix: generate file names server-side (UUIDs), or validate with `Path.safe_relative` and join to a fixed base directory.
- Reading `config/runtime.exs`, `.env`, or `/proc/self/environ` usually exposes secrets, so arbitrary file read is usually High or Critical.
- Writing into code, template, or release directories can become RCE.

## Step 6: Everything else (after the above)

- **SQL injection:**
  - `Ecto.Adapters.SQL.query`, `Repo.query`, `Repo.query!`, or `SQL.stream` with `"#{...}"`.
  - `fragment` built in macros with `unquote`.
  - Dynamic `order_by`/`select` fields from params without an allowlist.
  - Severity: the attacker can usually read the **whole database** (including password hashes and other users' data), so unauthenticated SQL injection is Critical.
- **XSS:**
  - `raw(`, `Phoenix.HTML.raw`, `{:safe, ...}`, `html(conn, ...)` with user data.
  - Markdown (`Earmark`, `MDEx`) passed to `raw` without sanitizing (`HtmlSanitizeEx`).
  - User-controlled `put_resp_content_type`.
  - Uploaded SVG or HTML served from the app's own domain.
- **CSRF:**
  - Browser pipelines without `:protect_from_forgery`.
  - State-changing actions reachable via GET ("action reuse"), e.g. both `get` and `post` routed to the same `edit_bio` action.
- **Cross-site WebSocket hijacking:** `check_origin: false` on sockets that use session cookies.
- **Secrets:** API keys and credentials committed in `config/*.exs`, `.env`, `docker-compose.yml`, or fixtures. Cite the location only, never the value. Search in a way that prints locations only, never line contents: `grep -rniE 'secret_key_base|api_key|password|token|secret' config/ .env* docker-compose.yml 2>/dev/null | grep -vE 'System\.(get_env|fetch_env)' | cut -d: -f1,2` lists each hard-coded candidate as `file:line`. A mask that hides only quoted strings is not enough, because `.env` and `docker-compose.yml` values are usually unquoted. Values read from `System.get_env`/`System.fetch_env!` are fine, unless a literal fallback such as `System.get_env("KEY", "...")` holds a real secret. Hard-coded values only matter if they're used in production (`config/prod.exs`, `config/runtime.exs`, or `config.exs` without a later override).
- **Database connection security:** in production, a remote database without `ssl: true` (or with certificate verification turned off) in the Repo config in `config/runtime.exs` sends credentials and data unencrypted. Low if the database is on a private network, such as Fly's internal network or a VPC. Medium if it crosses the internet.
- **Atom exhaustion:** `String.to_atom` on user input, `Jason.decode(..., keys: :atoms)`. This can crash the node. Usually Medium.
- **Brute force:** no rate limiting on login, password reset, or MFA (`Hammer`, `PlugAttack`, etc.). Usually Medium.
- **Data exposure:** pages or APIs returning more than intended, e.g. other users' emails on a public profile page, or `secret` records reachable by ID even though list views hide them.
- **Headers and HTTPS:** `put_secure_browser_headers`, CSP, `force_ssl`/HSTS. Usually Low, unless they enable another finding.

## Recording a candidate

For every candidate, record:

- the entry point and pipeline
- the attacker's starting privilege
- the full trace with `file:line`
- why existing protections don't stop it
- what the attacker gains
- a suggested severity

Update the coverage ledger, then send the candidate to Eve (`eve.md`).
