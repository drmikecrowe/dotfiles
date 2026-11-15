# Home Directory

Project instructions for an agent whose working directory is `~`. Global rules do not live here. harnessed ships them to each harness (Claude Code plugin `context.md`, omp `RULES.md`, codex `AGENTS.md`), so this file holds only facts about this directory.

## Where agent config comes from

Edit the source, never a generated copy.

| What | Source | Generated copies (do not edit) |
|---|---|---|
| Base rules (floor, harness-mechanics, prompt-defense, markdown) | `~/Programming/Personal/harnessed/main/catalog/recipes/mikes-universal-setup` | `~/.local/share/harnessed/`, `~/.omp/agent/RULES.md` |
| Personal recipes, stacks, `communication` rule | `~/.config/harnessed/catalog` (git repo) | same as above |
| React rule and hand-kept skills | `~/.agents/rules/react.md`, `~/.agents/skills` (symlinked into the `local` recipe) | same as above |
| Dotfiles, including this file and `~/.claude/settings.json` | `~/.local/share/chezmoi` | the files in `~` |

## Dotfiles

- chezmoi owns most of `~`. Edit the file under `~/.local/share/chezmoi`, then run `chezmoi apply <target>`.
- The chezmoi repo is public, with autoCommit and autoPush off. Never put a secret in it. Commit and push only when asked.

## Work tracking

GitHub Issues through `gh`. There is no local tracker.
