# Built Claude Code Settings

`~/.claude/settings.json` holds an `autoMode` block that describes private work repos, so that block cannot go in this public repo. Claude Code reads `autoMode` only from user settings, managed settings, or the `--settings` flag, so no user-scope file outside this repo can hold it. `bin/link` therefore builds the live file: it merges the tracked `claude/settings.json` with the untracked `~/.claude/settings.private.json` and writes a real file, whereas every other tracked file is a symlink.

## Consequences & Tradeoffs

`bin/link` rebuilds the live file only while it still matches the last build. Otherwise it prints the diff and skips, so a change made in Claude Code's UI is never overwritten and must be copied back by hand. The same guard makes a tool-written `autoMode` block surface as a diff, rather than land in the public repo where gitleaks would not flag it.

Two alternatives were rejected. Managed settings under `/Library/Application Support/ClaudeCode/` could hold `autoMode` beside a symlinked `settings.json`, but they need `sudo`, and a tool-written `autoMode` would go straight into the tracked file. A shell wrapper that passes `--settings` misses every launch that bypasses the shell, such as an IDE or the desktop app.

Symlink breakage is not the reason: in a test with Claude Code 2.1.284, a write followed the link. If Claude Code ever reads `autoMode` from a file this repo does not track, a plain symlink would work. The decision was settled in [issue #4](https://github.com/zorn/dotfiles/issues/4).
