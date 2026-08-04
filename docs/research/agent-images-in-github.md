# Getting agent-produced images to render in GitHub PRs, issues, and comments

Research date: 2026-08-04. Question: how can an autonomous agent with `gh` and a token — no human in a browser — get an image to render inline in a pull request body, issue body, or comment?

## The answer

**Use the undocumented `POST https://uploads.github.com/user-attachments/assets` endpoint.** It accepts a plain bearer token, needs no session cookie, is a single request with no S3 two-step, and returns the same `https://github.com/user-attachments/assets/<uuid>` URL a human gets from drag-and-drop. I verified this end to end with the OAuth token from `gh auth token`: `201 Created`, and the URL renders as an image for authenticated and anonymous viewers alike. It leaves nothing in the repository — no branch, no blob, no tag — and it works identically for an issue, which has no branch to commit to. That last point is what disqualifies most of the alternatives.

The catch, stated plainly: **this endpoint is not documented anywhere by GitHub, and GitHub has said an official one does not exist yet.** It is an internal endpoint that happens to accept a PAT. It could change or start refusing non-cookie auth without notice. A skill built on it should treat a non-201 as a signal to fall back rather than as a fatal error.

**The runner-up, and the fallback I'd pair with it, is an orphan branch referenced through `raw.githubusercontent.com` pinned to a commit SHA.** Every API involved is documented and stable, and it can be done entirely through the REST git-data API without touching the working checkout — no clone, no `git add`, no dirty tree. Pick it over the primary in three situations: when you want theme-aware `<picture>` screenshots (attachment URLs are silently *not* rewritten inside `<picture>`, so they 404 — see below, this is the sharpest gotcha I found); when you need the image to be hotlinkable outside GitHub; or when you are unwilling to depend on an undocumented endpoint at all.

Everything else is worse. Gists technically work but only if you `git push` the binary, and the raw URL you need is not the obvious one. Release assets probably do render, but they demand a published release and tag — real repository pollution — in exchange for nothing better. `data:` URIs are stripped by the sanitizer, not blocked by CSP: the `src` attribute is actually removed, leaving an `<img>` with no source at all. And `actions/upload-artifact` is a dead end by construction, since artifacts are zips behind a one-minute authenticated redirect.

## What the sources say

### There is no first-party upload API, and GitHub has effectively confirmed it

The community feature request [Comment API for uploading images/attachments for use in comments](https://github.com/orgs/community/discussions/28219) was opened 2022-08-03 and is still marked Unanswered with no GitHub staff reply. In the [More secure private attachments GA discussion](https://github.com/orgs/community/discussions/54551), GitHub staff wrote that "In the future, we hope to introduce an API endpoint specific to assets" — an acknowledgement that as of that thread there was none. Nothing in the [REST API reference](https://docs.github.com/en/rest) describes an attachment upload, and `gh` has no attachment or upload command: the command tree under `pkg/cmd` in [cli/cli](https://github.com/cli/cli) contains `release` (which uploads *release* assets) but nothing for comment attachments, and a code search of the repository for `user-attachments` and `upload/policies` returns nothing.

The best public write-up of the undocumented endpoint is [Island94, "How to programmatically upload attachments to GitHub Issues, Pull Requests, and Comments, finally, for now"](https://island94.org/2026/08/programmatically-upload-attachments-to-github-issues-pull-requests-comments) (August 2026), which describes it as "the unofficial, undocumented endpoint." That is a secondary source, but I independently reproduced everything it claims, so the mechanics below are first-hand rather than taken on trust.

Community tools corroborate the landscape from several directions. [Addono/gh-attach](https://github.com/Addono/gh-attach/) offers four strategies and describes the trade-off in its own README: browser-session cookie extraction as the default, "Release Assets (official API, works with tokens)", and a repository-branch strategy that "commits attachments to an orphan branch. Works with any token." [tonkotsuboy/github-upload-image-to-pr](https://github.com/tonkotsuboy/github-upload-image-to-pr), an agent skill for exactly this problem, concluded that "GitHub does **not** provide a public REST API endpoint for uploading image attachments" and drives a real browser via Chrome DevTools MCP or Playwright instead. That a purpose-built agent skill resorted to browser automation is worth knowing — but the browser is not actually required.

The most useful primary source for the endpoint is [Intercom's `attach-github-assets` skill](https://raw.githubusercontent.com/intercom/2x-skills/main/plugins/pr-tools/skills/attach-github-assets/scripts/upload.sh), which ships the upload as an MIT-licensed shell script — it adds `X-GitHub-Api-Version: 2022-11-28`, requires HTTP 201, and enforces its own MIME allowlist of png/jpg/gif/webp/svg/mov/mp4/webm. Its accompanying notes add a detail worth carrying over: **videos must be posted as a bare URL**, because wrapping one in `![]()` breaks GitHub's inline player. The right posture toward the endpoint is captured in [Shakacode's adoption issue](https://github.com/shakacode/agent-workflows/issues/271), which takes it only as an opt-in seam because "The endpoint is undocumented and can change or start refusing tokens without notice, so the fail-closed path must remain fully intact." That is exactly the recommendation here.

### What real automation actually does

This is the strongest available evidence, and it splits cleanly. **Every commercial visual-regression vendor posts links, not images** — which means their source cannot settle the question, and it is a mistake to read their behavior as proof that inline embedding is impossible. Argos builds its whole PR comment in [`comment.ts`](https://raw.githubusercontent.com/argos-ci/argos/main/apps/backend/src/git-platform/comment.ts) with no `![` or `<img>` anywhere, because its screenshots are S3 presigned URLs with `expiresIn: 3600` — a one-hour URL is useless in a durable comment. reg-suit's [`create-comment.ts`](https://raw.githubusercontent.com/reg-viz/reg-suit/master/packages/reg-notify-github-with-api-plugin/src/create-comment.ts) emits a count table and a single "Check [this report]" hyperlink into a published S3/GCS/gh-pages bundle. Chromatic and Percy contain no comment-creation code at all and communicate purely through status checks. The one SaaS exception, Happo, embeds a status *badge* rather than a screenshot.

The tools that genuinely embed screenshots inline all reach for the same mechanism: **commit the image, reference the raw URL.** three.js is the most battle-tested, and it converged on precisely the SHA-pinning conclusion I reached empirically — [`report-e2e.yml`](https://raw.githubusercontent.com/mrdoob/three.js/dev/.github/workflows/report-e2e.yml) builds `https://raw.githubusercontent.com/${owner}/${repo}/${IMAGES_SHA}/${run.id}`, and its own inline comment explains why: "The comment links images by commit sha, which keeps working until GitHub garbage-collects the unreachable commit." That is independent confirmation of both the technique and its documented-nowhere limit. Roborazzi's `CompareScreenshotComment.yml` force-pushes to an orphan branch named `companion_<head-branch>` and embeds `?raw=true` blob URLs; DroidKaigi's conference app ships a near-identical copy. kubestellar/console does the same thing without the git CLI, calling `repos.createOrUpdateFileContents` and taking `data.commit.sha` from the response. The generic [`saadmk11/comment-webpage-screenshot`](https://github.com/saadmk11/comment-webpage-screenshot) action states the premise in its README: "As GitHub Does not allow us to upload images to a comment using the API we need to rely on other services to host the screenshots."

Two variants avoid polluting the working repo: ratatui-image publishes to a *separate* repo's gh-pages with `peaceiris/actions-gh-pages` using `external_repository` and `force_orphan`, and AppImage's `publish-pr-screenshot.yml` uploads to a permanent `ci-screenshots` release tag. Note the second contradicts my own finding that release assets do not render — see the open questions.

Finally, `actions/upload-artifact` is confirmed impossible rather than merely awkward. The [artifacts REST API](https://docs.github.com/en/rest/actions/artifacts) requires `archive_format` to be `zip`, returns a 302, and states "This URL expires after 1 minute." A zip behind a one-minute authenticated redirect cannot be an `<img src>`, and camo will not fetch it. This is why every working example above runs a two-workflow `workflow_run` split: the untrusted PR job uploads artifacts, and a privileged job re-hosts the PNGs somewhere public.

### Attachment URLs are access-controlled and rewritten at render time

The [More secure private attachments changelog (2023-05-09)](https://github.blog/changelog/2023-05-09-more-secure-private-attachments/) states that "future attachments associated with private repositories can only be viewed after logging in," and that email notifications from private repositories no longer display the images inline. Staff in the GA discussion confirmed the generated tokens expire after roughly five minutes, which matches exactly what I observed (`X-Amz-Expires=300` inside the JWT payload).

The practical consequence is subtle and worth being precise about. The `github.com/user-attachments/assets/<uuid>` URL you store in the Markdown is **not itself fetchable** — it returns 404 to a plain `curl`. GitHub rewrites it at render time into a `private-user-images.githubusercontent.com/...?jwt=...` URL signed for about five minutes. Every page load mints a fresh one, so viewers always see the image; it just means the stored URL is not a hotlink you can use elsewhere.

### The Markdown sanitizer: what survives

[`github/markup`'s README](https://github.com/github/markup) disclaims owning the sanitizer — "only the first step is covered by this gem — the rest happens on GitHub.com. In particular, `markup` itself does no sanitization of the resulting HTML" — while noting that the HTML is "sanitized, aggressively removing things that could harm you and your kin—such as `script` tags, inline-styles, and `class` or `id` attributes." The nearest published allowlist is html-pipeline's [`SanitizationFilter`](https://github.com/gjtorikian/html-pipeline/blob/v2.12.3/lib/html/pipeline/sanitization_filter.rb), which permits `img` with `src` and `longdesc` plus a global list including `align`, `width`, `height`, `alt`, `title`, and restricts image protocols to `['http', 'https', :relative]`. The [sanitize gem README](https://github.com/rgrove/sanitize/blob/main/README.md) states the governing rule: "If an attribute is listed here and contains a protocol other than those specified (or if it contains no protocol at all), it will be removed."

GitHub's production sanitizer is not literally that file, though — testing found `vspace`, `border`, and `loading` stripped despite being permitted by html-pipeline. Treat html-pipeline as historically indicative and the observed behavior as authoritative. Separately, the GFM [`tagfilter` extension](https://github.github.com/gfm/#disallowed-raw-html-extension-) escapes nine tags before sanitization runs, none of which matter here.

Raw `<img>` is allowed. Surviving attributes relevant to screenshots are `src`, `alt`, `title`, `width`, `height`, and `align`. **`style` is stripped** — GitHub replaces the author's value with its own (`max-width: 100%; height: auto; aspect-ratio: ...`), so `width` and `height` are the only sizing lever and there is no CSS escape hatch. `srcset` is stripped from `<img>` entirely, and on `<source>` it is kept but treated as a single-URL slot: a `1x, 2x` candidate list silently keeps the first URL and discards the rest.

`<picture>` with `prefers-color-scheme` is documented and works, announced [beta 2022-05-19](https://github.blog/changelog/2022-05-19-specify-theme-context-for-images-in-markdown-beta/) and [GA 2022-08-15](https://github.blog/changelog/2022-08-15-specify-theme-context-for-images-in-markdown-ga/). The canonical syntax lives in the [Quickstart for writing on GitHub](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/quickstart-for-writing-on-github), not in the basic-syntax page, which now carries only the stub sentence "The `<picture>` HTML element is supported." `<details>`/`<summary>` is documented in [Organizing information with collapsed sections](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/organizing-information-with-collapsed-sections), which states outright "You can add an image or a code block, too." Images in table cells are permitted by the [GFM tables spec](https://github.github.com/gfm/#tables-extension-), which says cells contain "arbitrary text, in which [inlines] are parsed" — images are inlines.

### Camo applies to third-party hosts only

[About anonymized URLs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-anonymized-urls) says only that "To host your images, GitHub uses the open-source project Camo," which reads as though everything is proxied. It is not: **every GitHub-owned host passes through untouched**. I confirmed `raw.githubusercontent.com`, `gist.githubusercontent.com`, `github.com/.../releases/download/...`, `github.com/.../blob/...?raw=1`, and `objects.githubusercontent.com` all keep their literal `src`, while `example.com` and — notably — `zorn.github.io` are rewritten to `camo.githubusercontent.com`. GitHub Pages counts as third-party for this purpose.

That matters because camo's staleness problem is real but simply does not apply to any mechanism recommended here. For third-party origins, camo passes the origin's `Cache-Control` straight through, so it will serve stale for as long as the origin says to. The documented remedy is to set `no-cache` at the origin, with `curl -X PURGE https://camo.githubusercontent.com/<hash>` as a last resort that the docs warn "forces every GitHub user to re-request the image, so you should use it very sparingly." A cleaner lever falls out of the URL format — the camo path is `<digest>/<hex-encoded-origin-url>`, so appending `?v=2` to the origin mints a completely different camo URL with its own cache entry. The docs also state that an origin "being served from a private network or from a server that requires authentication" simply cannot be proxied.

### Private repositories will not render for outsiders

[GitHub's images documentation](https://github.com/github/docs/blob/main/content/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax.md) states that relative image links "will work for images in a private repository **only if the viewer has at least read access**." The [REST contents API docs](https://docs.github.com/en/rest/repos/contents) add that "For private repositories, these links are temporary and expire after five minutes." So a private-repo `raw.githubusercontent.com` URL is not a viable host for anyone outside the repo — which is correct behavior rather than a defect, and the user-attachments mechanism inherits the same property.

### `?raw=1` versus `raw.githubusercontent.com`

The docs recommend `?raw=true` and never mention `?raw=1`; both behave identically. The blob form costs two redirect hops before landing on `raw.githubusercontent.com`, which is where it resolves anyway. Use `raw.githubusercontent.com` directly as an `<img src>`; reach for the `?raw=true` blob form only when you specifically want a docs-sanctioned *relative* link that survives forks.

## What I actually tested

All testing used `gh auth token` (an OAuth `gho_` token with `gist`, `project`, `read:org`, `repo`, `workflow` scopes) against `zorn/dotfiles`. Rendering was verified through `POST /markdown` with `mode: gfm` and a repo `context`, which runs GitHub's production pipeline — the output carries the same fingerprints as real issue HTML (camo rewriting, `<themed-picture>`, `<markdown-accessiblity-table>`). I also verified one case through a real gist comment's `body_html` to confirm the `/markdown` endpoint is not a special case.

### The user-attachments endpoint — works

```
curl -X POST "https://uploads.github.com/user-attachments/assets?name=before.png&content_type=image/png&repository_id=$(gh api repos/zorn/dotfiles --jq .id)" \
  -H "Authorization: Bearer $(gh auth token)" -H "Accept: application/json" \
  --data-binary "@before.png"
```

Returned `201` with `{"url":"https://github.com/user-attachments/assets/23ecc747-9c18-4597-b9e6-b3ce0f0834bf"}`. Probing its constraints:

- Omitting `repository_id` → `404 Not Found`. It is required.
- Omitting the token → `400`, "You have sent an invalid request."
- Passing the `repository_id` of a public repo I lack write access to (`cli/cli`) → `404`. **Write access to the named repo is required**, so an agent cannot use someone else's repo as a dumping ground.
- Mismatched type → `422` with `{"resource":"UserAsset","field":"content_type","message":"content_type is not included in the list of allowed content types"}` and a second error, "name has a file extension that does not match the content type: .exe != application/x-msdownload". There is a MIME allowlist and the extension must agree with it.

Fetching the returned URL with plain `curl -L` and no token gave `404`. Rendering it through `/markdown` rewrote it to `https://private-user-images.githubusercontent.com/52168/631384549-<uuid>.png?jwt=<jwt>`, and **that signed URL fetched with no authentication at all**, returning `200 image/png`, byte-identical to the original. Crucially, an **anonymous** `POST` to `api.github.com/markdown` also produced a valid signed URL — so a logged-out reader of a public PR sees the image. The JWT payload decodes to a five-minute window (`X-Amz-Expires=300`), refreshed on every render.

**The `<picture>` failure.** This is the finding I would not have predicted. Rendering the same attachment URL four ways:

| Markdown form | Result |
| --- | --- |
| `<img src="…user-attachments…">` | rewritten to signed URL |
| `![x](…user-attachments…)` | rewritten to signed URL |
| `<img>` inside `<details>` | rewritten to signed URL |
| inside `<picture>` (both `<source srcset>` and inner `<img src>`) | **left as the raw `github.com/user-attachments/...` URL, which 404s** |

So theme-aware `<picture>` screenshots and user-attachments are mutually exclusive. The attachment rewriter skips the element entirely. A gist comment context also failed to rewrite, though that is irrelevant for PR and issue use.

### Orphan branch via the REST git-data API — works, no local clone

I built an orphan commit without touching the working tree at all: `POST /repos/zorn/dotfiles/git/blobs` with base64 content, then `POST .../git/trees` with **no `base_tree`**, then `POST .../git/commits` with **`"parents": []`**, then `POST .../git/refs` for `refs/heads/scratch-asset-test`. All four succeeded. This is the cleanest property of the approach for an agent — nothing is staged, nothing is checked out, no branch is switched.

All four URL forms served `200 image/png` at 190 bytes:

- `raw.githubusercontent.com/zorn/dotfiles/scratch-asset-test/screenshots/test-before.png` — 0 redirects
- `raw.githubusercontent.com/zorn/dotfiles/<commit-sha>/screenshots/test-before.png` — 0 redirects
- `github.com/zorn/dotfiles/blob/<sha>/...?raw=1` — 2 redirects
- `github.com/zorn/dotfiles/raw/<sha>/...` — 1 redirect

Headers: `content-type: image/png`, `cache-control: max-age=300`, and no camo rewriting in Markdown.

**The permanence test.** I deleted the ref, then re-fetched. The first checks were misleading — both URLs returned `200` with `source-age` in the hundreds, i.e. served from Fastly's shield cache. Ten minutes later, past the `max-age=300` window, the picture resolved cleanly:

- branch-name URL → **404**
- commit-SHA URL → **200 `image/png`**, `source-age: 0` (a genuine origin fetch)
- the `github.com/.../blob/<sha>/...` web page → **200**

So a SHA-pinned raw URL survives deletion of the branch that introduced it, because the dangling commit is still served. A branch-name URL does not. Note the honest limit on this: it holds for unreachable objects that have not been garbage-collected, and GitHub does not document GC timing. Do not delete the branch and rely on this — keep the orphan branch alive and pin to the SHA as belt-and-braces.

### Gists — work, but only via `git push`, and not via the obvious URL

Creating a gist through `POST /gists` with the PNG bytes decoded as latin-1 produced a file that GitHub reported as `type: image/png` — but the raw fetch returned `content-type: application/octet-stream` with `x-content-type-options: nosniff`, at 254 bytes rather than 190. The JSON API round-trips file content as UTF-8 and **corrupts binary**. Base64-in-a-gist is no better: it serves as `text/plain`, and there is no way to make Markdown decode it.

Pushing the real binary over git into the gist repo did work. The blob-SHA-pinned `raw_url` from the API served `200 image/png`, byte-identical, over a `content-security-policy: default-src 'none'; ... sandbox`, and was **not** camo-proxied. But the convenient unpinned path `gist.githubusercontent.com/<user>/<id>/raw/<filename>` returned **404** for the binary file — you must use the `raw_url` the API hands back, which embeds the blob SHA. That makes gists usable in principle and fiddly in practice, and it needs a git push rather than a clean API call.

### Release assets — they probably do render, but the cost is wrong

I initially ruled these out and was too quick about it. Uploading works via the documented `POST https://uploads.github.com/repos/{o}/{r}/releases/{id}/assets` (note the `uploads.` host — `api.github.com` 404s for this), returning `201` with `content_type: image/png`. A draft release's asset 404s unauthenticated, so publishing a real release and tag is mandatory.

The serving behavior looks hostile at first glance: `browser_download_url` 302s to `release-assets.githubusercontent.com` with a roughly one-hour signed URL, and the final response carries `content-disposition: attachment` and `content-type: application/octet-stream`. But I checked a *real production example* — AppImage's `ci-screenshots` release, which its `publish-pr-screenshot.yml` embeds into PR comments — and the final `200` response carries **no `x-content-type-options: nosniff`** (that header is only on the intermediate 302), while the payload is a valid `PNG image data, 800 x 600`. Since `<img>` ignores `Content-Disposition` and browsers sniff image responses when the type is generic and sniffing is not forbidden, this very likely renders. The one-hour expiry is not a problem either, because GitHub does not camo `github.com` URLs, so each viewer follows the 302 fresh and gets their own signed URL.

I did not confirm this visually in a browser, so treat "renders" as strongly indicated rather than proven. The reason to avoid release assets is not that they fail — it is that they require creating a tag and a published release, which is real repository pollution and generates watcher notifications, in exchange for nothing the two recommended mechanisms don't already give you.

### `data:` URIs — dead

```
input:  <img src="data:image/png;base64,iVBOR…" width="100">
output: <a target="_blank" rel="noopener noreferrer" href=""><img width="100" style="max-width: 100%;"></a>
```

The `src` attribute is **removed entirely**, in both the raw `<img>` and `![](…)` forms. It renders as a broken image, not as alt text. This is the sanitizer's protocol allowlist, not CSP — GitHub.com's own CSP header does include `data:` in `img-src`.

### The composition that works

Verified rendering correctly through `/markdown`, with attachment URLs rewritten to signed URLs in both cells:

```markdown
| Before | After |
| --- | --- |
| <img src="https://github.com/user-attachments/assets/<uuid-1>" width="420" alt="Before: settings panel"> | <img src="https://github.com/user-attachments/assets/<uuid-2>" width="420" alt="After: settings panel"> |
```

`<details>` wrapping works and images render inside it, provided there are blank lines around the Markdown so it parses as Markdown rather than raw HTML. Use `<picture>` only with `raw.githubusercontent.com` URLs, which I confirmed pass through `<picture>` untouched and remain directly fetchable.

Two conventions worth stealing from the implementations that have run this in production. Intercom's skill documents that **videos must be posted as a bare URL on its own line** — wrapping one in `![]()` breaks GitHub's inline player. And three.js caps embeds at `MAX_EMBEDDED = 10`, listing the remainder by filename, which is a sensible ceiling for a PR description that a human has to scroll.

If you take the orphan-branch path, the conventions that multiple independent projects converged on are: pin the raw URL to the commit SHA rather than the branch name (three.js, qwen-code, and kubestellar all landed there separately, because branch URLs break on force-push or prune), and put a unique run or timestamp segment in the path so a re-run cannot collide with a cached earlier image.

## Trade-offs

| Mechanism | Renders inline | URL stable | Survives squash-merge | Pollutes `main` | Works for an issue | Permissions | Documented |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `uploads.github.com/user-attachments/assets` | Yes | Yes (rewritten per render) | Yes — independent of git | No | Yes | Token with **write** on the named repo | **No** |
| Orphan branch + `raw.githubusercontent.com` @ SHA | Yes | Yes while objects live | Yes — never merged | No, but adds a branch and blobs | Yes | `contents: write` | Yes |
| Image committed on the PR branch | Yes | Branch URL dies on branch delete; SHA URL survives | Blobs land in `main` | **Yes** | No — no branch exists | `contents: write` | Yes |
| Separate **public** assets repo | Yes | Yes | N/A | No | Yes | `contents: write` on that repo | Yes |
| Separate **private** assets repo | **No** for anyone outside it | Signed, ~5 min | N/A | No | Yes | — | Yes |
| Gist (binary via `git push`) | Yes, via API `raw_url` only | Yes | N/A | No | Yes | `gist` scope + git push | Partly |
| Gist (binary via JSON API) | **No** — corrupted, `octet-stream` | — | — | — | — | — | — |
| Release asset | Likely yes (sniffed; no `nosniff`) | Re-signed per fetch | N/A | **Yes** — needs a tag and release | Yes | `contents: write` | Yes |
| Third-party host (S3, R2) | Yes, via camo | Yes | N/A | No | Yes | External credentials | Yes |
| `actions/upload-artifact` | **No** — zip behind a 1-min redirect | — | — | — | — | — | Yes |
| `data:` URI | **No** — `src` stripped | — | — | — | — | — | Yes (by omission) |
| GitHub Pages | Yes, via camo | Yes | N/A | Adds a branch or workflow | Yes | `contents: write` | Yes |

## Open questions and things I could not verify

**Does the user-attachments endpoint work with a fine-grained PAT, a GitHub App installation token, or the Actions `GITHUB_TOKEN`?** I only tested the classic-scoped OAuth token that `gh auth token` returns, and a separate source survey reached the same wall — no primary source either way. Since the endpoint is undocumented there is no scope table to consult, and the `repository_id` check suggests it authorizes against repo write access rather than a named scope, but that is inference from a 404 rather than knowledge. If the skill is ever meant to run inside Actions, this is the first thing to test there. For a local `gh`-driven agent, which is the case in question, it is moot.

**How long do dangling commits remain fetchable?** The SHA-pinned raw URL still served a deleted branch's commit ten minutes after deletion. GitHub does not document unreachable-object GC timing, and I could not test over a longer horizon. Treat "keep the orphan branch alive" as the safe rule.

**Can a user-attachment be deleted or listed?** I found no endpoint for either, and the asset I uploaded during testing is still resolvable. An agent using this mechanism creates permanent, unenumerable objects it cannot clean up. For screenshots this is probably fine; it is worth knowing before pointing the mechanism at anything sensitive.

**Private-repo behavior for user-attachments.** The changelog documents that private-repo attachments require login, and the mechanism is clearly the same signed-JWT rewrite. I did not test against an actual private repo, so I am reasoning from documentation plus the observed public-repo behavior rather than direct evidence.

**Whether the `<picture>` non-rewrite is a bug or intentional.** I could find no documentation acknowledging it either way. It could be fixed at any time, which would be a silent improvement — or the reverse could happen to `<img>`.

**Whether release assets truly render in a browser.** I established that the bytes are a valid PNG and that the final response sets no `nosniff`, which together make sniffing-based rendering very likely, but I verified headers rather than pixels. Confirming properly would mean publishing a real release on a repo I was asked not to pollute. This does not change the recommendation.

**Whether `?raw=true` or `raw.githubusercontent.com` is better for private repos.** gh-attach's branch strategy deliberately uses the `github.com/{owner}/{repo}/raw/refs/heads/{branch}/{path}` form with the in-source comment "Use GitHub's authenticated raw URL so attachments resolve for private repositories," which implies the two forms differ in how they authorize a logged-in viewer. I tested only against a public repo, where they behave identically, so I cannot confirm that distinction.

**Anonymous resolution of a bare attachment URL.** My testing and the survey found slightly different things, and both are true. The bare `github.com/user-attachments/assets/<uuid>` URL 404s anonymously while the asset is *unreferenced*; assets already cited in public content return `200 image/png` anonymously. Independently, the render-time rewrite to a signed URL always works, including for anonymous viewers. The practical upshot is unchanged — it renders — but you cannot treat the URL as a general-purpose image host before it has been posted.

## Test artifacts: created and cleaned up

Created and **deleted**: a public gist (`d016975d933c7accc34e88e41bcad819`), an orphan branch `scratch-asset-test` on `zorn/dotfiles`, and a draft release with a PNG asset on `zorn/dotfiles`. Verified afterwards that the repo lists only `main`, has zero releases and no new tags, and that the gist 404s. The repository working tree was never touched — no clone, no commit, no checkout.

Created and **not deletable**: four `user-attachments` assets, since GitHub exposes no delete endpoint. They are unlisted UUIDs scoped to `zorn/dotfiles` and contain only solid-color test PNGs under 200 bytes. Three came from the main testing pass and one from a parallel verification of the same endpoint.

No pull request was opened, nothing was pushed to `main`, and no issues were created.
