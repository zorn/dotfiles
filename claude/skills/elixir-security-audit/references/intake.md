# Intake

Goal: understand what the app is, who can reach it, and what the user worries about. The answers decide how severe each finding is. For example, an access control bug matters much more when anyone on the internet can create an account.

## Step 1: Inspect before asking

Gather evidence so most questions only need a confirmation.

| Topic | Where to look |
|---|---|
| What the app is | `README*`, `mix.exs` (app name, deps), router, Ecto schemas |
| Public internet? | `config/runtime.exs` (`PHX_HOST`, `url: [host: ...]`), `force_ssl`, `check_origin`, deploy configs |
| How it's deployed | `fly.toml` (Fly.io), `Dockerfile`, `render.yaml`, `elixir_buildpack.config` (Gigalixir/Heroku), `.ebextensions`/`copilot/`/`cdk`/`*.tf` (AWS or Terraform), `app.yaml`/`cloudbuild.yaml` (GCP), `k8s/`, `helm/`, `rel/`, deploy jobs in CI |
| Open signup? | Router routes such as `/users/register`, `/sign_up`, `/signup`, `registration`; `phx.gen.auth` modules (`UserRegistrationController`, `UserLive.Registration`); OAuth (`ueberauth`, `assent`); invite-only flows (`invite`, `invitation`) |

For a non-web project (library, CLI, worker), adapt the questions: who supplies its input, and where does it run?

## Step 2: Ask

Ask in one round, together with the other Phase 1 questions from `SKILL.md`. If an ask-the-user tool is available, use it. Otherwise, send one message with numbered questions and ask the user to reply with numbered answers. Keep wording simple and include the one-line "why".

When the code gives no evidence for a question, say "(couldn't tell from the code)" instead of guessing.

1. **Briefly, what is this application, in your own words?**
   - Why: it tells you what is valuable. Payment data, medical records, and admin powers raise the stakes.
   - Let the user describe it themselves; don't offer your guess as the answer. If they say "not sure" or skip it, use your own reading of the code and tell them so.
2. **What is the biggest security risk you're concerned about?**
   - Why: it lets you look hardest at what they care about most.
   - Offer choices:
     - "someone seeing another customer's data"
     - "someone taking over an account"
     - "someone taking over the server"
     - "losing or leaking the database"
     - "not sure, check everything"
   - "Not sure" is a perfectly good answer.
3. **Is this application deployed on the public internet?**
   - Why: anything reachable from the internet gets probed by automated attackers within hours of going live.
   - Put your guess first, marked "(looks like this from the code)".
4. **How is it deployed?** (Fly.io, AWS, GCP, Gigalixir, Render, Kubernetes, own servers, etc.)
   - Why: cloud platforms have internal endpoints, like cloud metadata services and private networks, that turn some bugs into stolen credentials.
   - Put your guess first, marked "(looks like this from the code)".
5. **Can anyone create an account, or do new accounts require a prior business relationship?**
   - Why: if anyone can sign up, then "logged-in user" means "any attacker". A bug only logged-in users can reach is then nearly as serious as one anyone can reach.
   - Put your guess first, marked "(looks like this from the code)".

If the user doesn't answer something, assume the riskier option and say so in the report: public internet, open signup, and for unknown hosting, a cloud provider with a reachable metadata endpoint.

## Step 3: Record the threat context

Write this down once and reuse it in triage, in Eve's review, and in the report:

```
Threat context
- App: <one line>
- Most valuable assets: <data/actions>
- User's main concern: <answer>
- Internet-facing: yes/no (confirmed / assumed)
- Hosting: <platform>  -> internal SSRF targets: <e.g. 169.254.169.254 (AWS/GCP/Azure metadata), Fly .internal / fdaa: addresses, k8s service DNS>
- Account creation: open signup / invite or contract only / no accounts
- Lowest-privilege attacker: <e.g. "anonymous internet user", "any self-registered user", "employee of a paying customer">
```
