# Getting an image into a PR body

Disclosed reference for [`pull-request`](../SKILL.md). Findings and test evidence: `docs/research/agent-images-in-github.md` in this repo.

## What `--attach` does

`gh pr create` and `gh pr edit` upload each attached file to GitHub's user-attachments store and rewrite the matching local reference in the body to the `https://github.com/user-attachments/assets/<uuid>` URL — the same URL a human gets by dragging a file into the comment box. An attached file the body never references is appended at the end instead.

It **requires write access** to the repo, and **an uploaded asset cannot be listed or deleted**, since GitHub exposes no endpoint for either. So attach once, with the body settled, rather than while drafting. One command takes up to 50 files. Images and GIFs are limited to 10 MB, and video to 10 MB on Free plans and 100 MB on paid ones.

The URL is not fetchable on its own — GitHub rewrites it at render time into a short-lived signed URL. That rewrite happens for logged-out readers too, so the image renders for anyone who can see the PR. It does mean the URL is not a hotlink you can use anywhere else.

## The two forms that silently fail

**`<picture>` breaks with attachment URLs.** GitHub's rewriter skips the element, leaving the raw `github.com/user-attachments/...` URL in place, which 404s. Theme-aware light/dark screenshots therefore need the orphan branch below, whose `raw.githubusercontent.com` URLs pass through `<picture>` untouched.

**`data:` URIs are stripped.** The sanitizer removes the `src` attribute outright, leaving an image element with no source — a broken image rather than alt text. There is no inlining an image into a body.

Two more limits worth carrying. GitHub sets `max-width: 100%` on every image and strips any `style` you supply, so plain `![](url)` already fills the container and `width`/`height` on a raw `<img>` are the only way to make one *smaller* — reach for them when a thumbnail is genuinely wanted, not by default. And a body with more than about ten embedded images is one the reviewer scrolls past rather than reads; list the rest by filename.

## Theme-aware screenshots: an orphan branch

This is the one case `--attach` cannot serve: a `<picture>` pair of light and dark screenshots. Every API involved here is documented, and none of it touches the working checkout — no clone, no staging, no branch switch. Create a blob, a tree with no `base_tree`, a commit with no parents, and a ref:

```
gh api repos/<owner>/<repo>/git/blobs -f content="$(base64 < shot.png | tr -d '\n')" -f encoding=base64 --jq .sha
gh api repos/<owner>/<repo>/git/trees -f 'tree[][path]=screenshots/<unique>/shot.png' -f 'tree[][mode]=100644' -f 'tree[][type]=blob' -f 'tree[][sha]=<blob-sha>' --jq .sha
gh api repos/<owner>/<repo>/git/commits -f message="screenshots for #<pr>" -f tree=<tree-sha> --jq .sha
gh api repos/<owner>/<repo>/git/refs -f ref=refs/heads/screenshots -f sha=<commit-sha>
```

Omitting `parents` is what makes it a root commit — verified, the response comes back with `"parents": []` — so the tree carries the image alone and shares no history with `main`. Reference it as `https://raw.githubusercontent.com/<owner>/<repo>/<commit-sha>/screenshots/<unique>/shot.png`. **Pin to the commit SHA, not the branch name** — a branch URL breaks on force-push or prune, where a SHA URL survives even the branch being deleted, because the dangling commit is still served. GitHub documents no garbage-collection timing for unreachable objects, so keep the branch alive rather than relying on that. Put a unique segment in the path so a re-run cannot collide with a cached earlier image.

The branch never merges, so nothing lands in `main`. On a **private** repo neither mechanism renders for anyone without read access, which is correct behavior rather than a defect.

## What not to reach for

`actions/upload-artifact` produces a zip behind a one-minute authenticated redirect and can never be an image source. Release assets probably render but demand a published release and tag — real repository pollution for nothing better. Gists work only if the binary goes in over `git push`, and only through the blob-SHA `raw_url` the API hands back; the JSON API corrupts binary content. Committing the image on the PR branch works and lands the file in `main` permanently, which is the cost the orphan branch exists to avoid.
