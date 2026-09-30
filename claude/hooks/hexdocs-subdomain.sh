#!/usr/bin/env bash
#
# PreToolUse hook for WebFetch: rewrite https://hexdocs.pm/<package>/... to
# https://<package>.hexdocs.pm/... before the request goes out.
#
# hexdocs.pm 301s the path form to the subdomain, and the path form is what
# training data holds, so every doc lookup would otherwise cost a wasted fetch.

set -euo pipefail

input="$(cat)"
url="$(printf '%s' "$input" | jq -r '.tool_input.url // empty')"

# Only Hex package-name characters, so the root search page (/?q=...) is not
# mistaken for a package.
if [[ "$url" =~ ^https?://hexdocs\.pm/([a-z0-9_]+)(/.*)?$ ]]; then
  # A hostname cannot hold an underscore, so hexdocs swaps in a hyphen.
  package="${BASH_REMATCH[1]//_/-}"
  rest="${BASH_REMATCH[2]:-/}"
  new_url="https://$package.hexdocs.pm$rest"

  # updatedInput replaces the whole tool input, so the prompt is carried over.
  # No permissionDecision: the rewritten URL goes through the normal rules.
  printf '%s' "$input" | jq --arg url "$new_url" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse",
      updatedInput: (.tool_input | .url = $url)}}'
fi
