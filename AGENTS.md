# Home Directory

Project instructions for an agent whose working directory is `~`. Global rules do not live here. rulesync generates them for each tool, so this file holds only facts about this directory.

## Where agent config comes from

Edit the source, never a generated copy.

| What | Source | Generated copies (do not edit) |
|---|---|---|
| Rules, skills, commands, hooks, permissions, MCP servers | `~/.rulesync` (private repo `drmikecrowe/rulesync-config`) | `~/.claude/CLAUDE.md`, `~/.claude/skills`, `~/.claude/commands`, `~/.claude/settings.json`, `~/.claude.json` |
| Dotfiles, including this file | `~/.local/share/chezmoi` | the files in `~` |

- After you edit the source, run `cd ~ && rulesync generate`. `rulesync generate --check` reports drift. `~/rulesync.jsonc` links to `~/.rulesync/rulesync.jsonc`.
- A machine that has `~/.rulesync.local/generate.sh` runs that script instead. It layers machine-only settings over the shared source.
- chezmoi does not manage `~/.claude/settings.json`. rulesync generates it.

## Dotfiles

- chezmoi owns most of `~`. Edit the file under `~/.local/share/chezmoi`, then run `chezmoi apply <target>`.
- The chezmoi repo is public, with autoCommit and autoPush off. Never put a secret in it. Commit and push only when asked.

## Work tracking

GitHub Issues through `gh`. There is no local tracker.
