---
name: serena-init
description: >
  Initialize Serena MCP semantic code tools for a project. Run via /serena-init
  when setting up a new project or worktree for Serena. Creates .serena/project.yml
  with language detection, registers the project in Serena config, adds Serena docs
  to CLAUDE.md, and ensures the SessionStart activation hook exists. Idempotent —
  safe to rerun. TRIGGER when user runs /serena-init, says "init serena",
  "setup serena", "configure serena for this project".
---

# Serena Init

Initialize Serena MCP for the current project. Performs 6 steps in order. Each step is idempotent — skip if already done.

## Step 1: Check Serena MCP prerequisite

Read `~/.claude/settings.json`. Verify `mcpServers.serena` exists. If missing, tell user to add Serena MCP config and stop.

## Step 2: Detect project languages

Scan the project root for language indicators. Check in this priority order:

| Pattern | Language |
|---------|----------|
| `*.py`, `pyproject.toml`, `setup.py` | python |
| `*.ts`, `*.tsx`, `tsconfig.json` | typescript |
| `*.js`, `*.jsx`, `package.json` | javascript |
| `*.go`, `go.mod` | go |
| `*.rs`, `Cargo.toml` | rust |
| `Makefile`, `*.sh`, `mise.toml` | bash |
| `*.java`, `pom.xml`, `build.gradle` | java |

Use `ls` to check. Collect all matching languages. Default to `python` if none detected. First detected language is the default.

## Step 3: Create `.serena/project.yml`

**If `.serena/project.yml` already exists**: report path, do NOT overwrite. Ask user if they want to regenerate.

**If not**: create `.serena/` directory and write `project.yml`:

```yaml
project_name: <directory-name>
languages:
- <default-language>
- <other-detected-languages>
encoding: utf-8
ignore_all_files_in_gitignore: true
read_only: false
excluded_tools:
- list_memories
- read_memory
- write_memory
- edit_memory
- rename_memory
- delete_memory
```

`project_name` = basename of project root directory. **If the name collides with an existing registered project** (same `project_name` in another `.serena/project.yml` under `~/.serena/serena_config.yml`), append a disambiguator: use the parent directory name, e.g. `main` → `isolated-env-main`. Check for collisions by reading `~/.serena/serena_config.yml`, extracting registered paths, and comparing `project_name` values from their `.serena/project.yml` files.

Languages list from step 2.

## Step 4: Register project in Serena config

Read `~/.serena/serena_config.yml`. Check `projects:` list. If current project root path not present, append it. Use Edit to add after the last entry.

## Step 5: Add Serena section to CLAUDE.md

If `CLAUDE.md` exists in project root and does NOT contain `## Serena MCP`, append this section:

```
## Serena MCP — Semantic Code Tools

Serena runs as a shared background service (port 8765). At session start, the hook auto-activates the project.

Prioritize Serena's symbolic tools over raw file reads for code exploration:
- `get_symbols_overview` — symbol map of a file/directory
- `find_symbol` — locate class/function/method by name path
- `find_referencing_symbols` — find all callers
- `replace_symbol_body` / `insert_after_symbol` — surgical edits

**Workflow:** `get_symbols_overview` → `find_symbol` → targeted edit.
```

## Step 6: Verify SessionStart hook

Read `~/.claude/settings.json`. Check `hooks.SessionStart` array for an entry containing `serena-activate`. If missing, use the `update-config` skill to add:

```json
{
  "hooks": [
    {
      "type": "command",
      "command": "~/.claude/hooks/serena-activate.sh",
      "timeout": 10,
      "statusMessage": "Activating Serena project..."
    }
  ]
}
```

Also verify `~/.claude/hooks/serena-activate.sh` exists. If missing, report to user — this script must be created manually or installed.

## Completion

Report what was done vs what already existed:
- Created/skipped `.serena/project.yml`
- Registered/skipped in `serena_config.yml`
- Added/skipped CLAUDE.md section
- Hook present/missing

Tell user to restart the Claude Code session (or run `mcp__serena__activate_project` manually) for activation to take effect.
