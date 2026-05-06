---
name: dorothy-command
description: Create a new executable Dorothy command script in ~/.config/dorothy/commands/. Use when the user asks to create a Dorothy command, add a new command to their Dorothy config, or scaffold a shell utility for their Dorothy setup. Generates a complete, self-contained bash script following Dorothy conventions and writes it directly to the commands folder.
---

# Dorothy Command Creator

Commands dir: `~/.config/dorothy/commands/`

## Gather from user (ask only what's missing)

1. **Name** — the command filename (e.g. `sync-notes`, `setup-util-foo`)
2. **Purpose** — one sentence
3. **Arguments/flags** — any options the command takes
4. **Dependencies** — external tools required (jq, git, curl, etc.)
5. **Logic** — what the command actually does

## Script conventions (observed from existing commands)

- Shebang: `#!/usr/bin/env bash`
- Always `set -euo pipefail`
- Header comment: command name + purpose (1–2 lines max)
- Dep checks: `command -v <tool> >/dev/null || { echo "ERROR: <tool> required"; exit 1; }`
- Args: `getopts` for flags; positional args via `$1`, `$2` etc.
- `usage()` function for any command with flags
- Progress output: `echo "==> ..."` style
- Git repo check when needed: `git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "ERROR: not in a git repo" >&2; exit 1; }`
- Idempotent by default: check state before acting
- `log()`/`fail()` helpers for longer commands:
  ```bash
  log()  { echo "[$(date -Iseconds)] $*"; }
  fail() { echo "ERROR: $*" >&2; exit 1; }
  ```

## Template

`scripts/template.sh` is the starting point. Trim unused sections (skip `usage()` if no flags, skip `log()`/`fail()` for short scripts).

## Delivery

1. Write the complete script to `~/.config/dorothy/commands/<name>`
2. `chmod +x` it
3. Smoke-test with `--help` or a dry-run if possible
4. Report the path and any caveats

No README, no extra files. One script, done.
