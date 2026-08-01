# Global Claude Instructions

## Git commits and pull requests

Do not add promotional, attribution, or co-authorship content to any git artifact — including commit messages, PR titles, PR summaries, or any other version-control record.

This means:
- No `Co-Authored-By:` trailers in commit messages
- No "Generated with [Tool]" footers in PR descriptions
- No AI tool branding, badges, or signatures anywhere in git history

Commits and PRs are attributed solely to the human author running the session.

## Markdown formatting

Do not hard-wrap prose in Markdown you author. Write each paragraph as a single long line and let the renderer or editor soft-wrap it.

This applies to GitHub issues, pull request bodies, comments, and Markdown documents generally. Hard-wrapped paragraphs produce noisy diffs, since editing one sentence reflows every line after it.

Exceptions: match an existing convention when a file or repo is already consistently hard-wrapped, and leave code blocks, tables, and YAML frontmatter alone.
