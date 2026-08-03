# Global Claude Instructions

## Git commits and pull requests

Do not add promotional, attribution, or co-authorship content to any git artifact — including commit messages, PR titles, PR summaries, or any other version-control record.

This means:
- No `Co-Authored-By:` trailers in commit messages
- No "Generated with [Tool]" footers in PR descriptions
- No AI tool branding, badges, or signatures anywhere in git history

Commits and PRs are attributed solely to the human author running the session.

## Write to be scanned

Length changes how a reader engages. A long pull request summary does not get read more carefully than a short one — its size pushes the reader into skimming for the part that concerns them. Keep prose tight so that what you wrote is what gets read.

Lead with the outcome. The first sentence should answer what happened or what you found, with the supporting detail after it for whoever wants it. Keep caveats short and spend the bulk of the response on the actual answer. When explaining something, give the high-level version unless depth was asked for.

Being readable and being concise are different things, and readable matters more. Shorten by being selective about what you include — leave out the detail that would not change what the reader does next — rather than by compressing prose into fragments, abbreviations, or stacked bullets that strip out the reasoning. Match the shape to the question: a direct question deserves a direct answer in prose. Reserve lists for genuinely discrete items and tables for short enumerable facts, and let the surrounding prose carry the explanation.

## Markdown formatting

Do not hard-wrap prose in Markdown you author. Write each paragraph as a single long line and let the renderer or editor soft-wrap it.

This applies to GitHub issues, pull request bodies, comments, and Markdown documents generally. Hard-wrapped paragraphs produce noisy diffs, since editing one sentence reflows every line after it.

Exceptions: match an existing convention when a file or repo is already consistently hard-wrapped, and leave code blocks, tables, and YAML frontmatter alone.

## US English

Write US spellings — behavior, normalize, defense, analyze. This covers prose, code comments, commit messages, and documentation alike.

It is a consistency rule rather than a correctness one, so it applies to text that arrives from elsewhere too. A file adopted from a British-spelling source gets normalized when it is edited, rather than left to mix registers line by line.

Leave quoted material alone, and leave identifiers alone. A field name, API parameter, or dependency that spells it the British way keeps its own spelling — changing that breaks the reference rather than tidying it.
