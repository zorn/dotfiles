# Built Claude Code Settings

`~/.claude/settings.json` holds an `autoMode` block that describes private work repos, so that block cannot go in this public repo. Claude Code reads `autoMode` only from user settings, managed settings, or the `--settings` flag, so no file it reads can hold the private half separately. `bin/link` therefore builds the live file. It merges the tracked `claude/settings.json` with the untracked `~/.claude/settings.private.json` and writes a real file, where every other tracked file is a symlink.

## Consequences & Tradeoffs

A change made in Claude Code's UI lands only in the live file, not in the repo. `bin/link` keeps a copy of its last build. When the live file still matches that copy, it rebuilds freely. When the live file differs, it prints the diff and skips, so a UI change is never overwritten, but you have to copy it back by hand. The same guard catches a tool that writes a new `autoMode` block: the block surfaces as a diff in an untracked file instead of landing in the public repo, where gitleaks would not flag it.

Two alternatives were rejected. Managed settings under `/Library/Application Support/ClaudeCode/` would hold `autoMode` beside a symlinked `settings.json`, but they need `sudo`, and a tool-written `autoMode` would go straight into the tracked file. A shell wrapper that passes `--settings` misses every launch that bypasses the shell, such as an IDE or the desktop app.

Symlink breakage is not the reason for this design. [anthropics/claude-code#40857](https://github.com/anthropics/claude-code/issues/40857) reports that a Claude Code write replaces a symlinked settings file. In a test with 2.1.284, Claude Code followed the link at `~/.claude/settings.json` and rewrote the file behind it. If `autoMode` ever gains a scope that sits outside this repo, a plain symlink would work. The decision was settled while grilling [issue #4](https://github.com/zorn/dotfiles/issues/4).
