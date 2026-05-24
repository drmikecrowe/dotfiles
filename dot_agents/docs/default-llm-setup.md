# Default LLM / Claude Code Setup
*As-built reference for cross-runtime agent configuration*

---

## Runtime Architecture

Four runtimes share one skill library. Hook scripts live in `~/.agents/hooks/` and are wired into each runtime's config.

```
~/.agents/
├── bin/            ← wiring tools + shared executables
│   ├── activate-hooks      ← idempotent hook wiring (run after adding handlers)
│   ├── serena-init         ← project bootstrap (symlinked from dorothy commands)
│   ├── context_feed/       ← hook-driven context capture (replaces old summarizer pipeline)
│   └── legacy/             ← retired scripts (extract-thread, summarize-thread, recent-activity)
├── hooks/          ← canonical shared hook SCRIPTS
│   ├── run-hook.sh         ← sole dispatcher registered in all settings.json files
│   ├── lib-log.sh / lib-wrapper.sh  ← shared libraries
│   ├── lib-notebook.sh.legacy ← retired notebook lib (nb_spawn_summarizer, etc.)
│   ├── PreToolUse.d/       ← 20-bash-ban-raw-tools.sh, 30-code-nav-gate.sh
│   ├── PostToolUse.d/      ← 10-agentmemory.sh, 20-code-nav-marker.sh, 30-notebook-unit.sh
│   ├── SessionStart.d/     ← 10-agentmemory.sh, 20-code-nav-reminder.sh, 30-context-feed-inject.sh
│   ├── Stop.d/             ← 10-agentmemory.sh, 20-notify.sh, 20-context-feed-capture.sh
│   ├── PreCompact.d/ PostCompact.d/ UserPromptSubmit.d/ ElicitationResult.d/ Notification.d/
│   └── (full handler inventory: see universal-hooks-architecture.md)
└── skills/         ← shared skills, auto-discovered by ALL runtimes

~/.claude/          ← Claude Code runtime
├── CLAUDE.md       ← universal directives (= ~/AGENTS.md)
├── settings.json   ← hooks, MCP servers, permissions, env vars
├── commands/       ← /commit, /handoff
└── hooks/          ← CC-SPECIFIC hooks only

~/.pi/agent/        ← pi/GSD runtime hooks (settings only — NO extensions here)
└── settings.json   ← hooks (GSD schema) — NO extensions key

~/.gsd/agent/       ← GSD hooks + session/UI/model settings + extensions
├── settings.json   ← hooks (GSD schema) + defaultModel/UI
└── extensions/     ← THE scanned extension dir; auto-discovered at startup, no settings wiring
    └── agentmemory/
        ├── index.ts                ← lifecycle hooks (recall/save)
        ├── extension-manifest.json ← provides tools/commands/hooks (required for discovery)
        ├── security.ts
        ├── package.json
        └── README.md
```

**Key principle:** Hook SCRIPTS in `~/.agents/hooks/`. Hook WIRING (JSON) in each runtime's config. Same script, many config references — both `~/.pi/agent/settings.json` and `~/.gsd/agent/settings.json` carry the full hook block. **Extensions, however, are scanned only from `~/.gsd/agent/extensions/<name>/`** — `~/.pi/agent/` holds no extensions.

---

## Token Optimization Stack

```
User prompt
    │
    ▼
[Layer 1: context-mode]   Output virtualization — sandboxes large outputs
    │                     MCP server + shim hook (~/.agents/shims/context-mode-*)
    │                     Repo: https://github.com/mksglu/context-mode
    ▼
[Layer 2: RTK]            CLI output filtering — via rtk hook claude (PreToolUse Bash)
    ▼
[Layer 3: Caveman]        Prose compression in agent responses ✅
    │                     Plugin: https://github.com/JuliusBrussee/caveman
    ▼
Anthropic API
    ▼
[Code Nav: CBM]           Knowledge graph for exploration ✅
    │                     Repo: https://github.com/DeusData/codebase-memory-mcp
[Code Nav: Serena]        LSP precision for editing ✅
[Memory: agentmemory]     Cross-session memory + decisions ✅
    │                     Server: http://localhost:3111 (systemd: agentmemory.service)
    │                     Repo: https://github.com/rohitg00/agentmemory
```

---

## Tools to Install

### T1: CBM (codebase-memory-mcp)
Repo: https://github.com/DeusData/codebase-memory-mcp
```bash
npm install -g codebase-memory-mcp
```
Per-project setup (add to `.mcp.json` after installing):
```json
{
  "mcpServers": {
    "codebase-memory-mcp": {
      "type": "stdio",
      "command": "codebase-memory-mcp",
      "args": ["--project-root", "/absolute/path/to/project"]
    }
  }
}
```
Then run once per project: `mcp__codebase-memory-mcp__index_repository`

### T1b: agentmemory (cross-session memory) — FULL SETUP BELOW

### T2: context-mode
Repo: https://github.com/mksglu/context-mode
MCP server + CLI for output virtualization. Hooks wired via shims:
```bash
npm install -g context-mode
~/.agents/shims/generate.sh
```

### T3: Per-stack rule files
From `claude-code-tips/rules/`. Copy to `~/.claude/rules/` — CC auto-loads `rules/*.md` for matching file types.
```bash
mkdir -p ~/.claude/rules
cp ~/Programming/AI/claude-code-tips/rules/*.md ~/.claude/rules/
```
Current rules: `flutter.md`, `react.md`, `appwrite.md`.

---

## agentmemory — Complete As-Built Setup

Provides cross-session memory via MCP (`mcp__agentmemory__*` tools) and pi/GSD lifecycle hooks (auto-recall on session start, auto-save on session end).

### Step 1: Install

```bash
npm install -g @agentmemory/agentmemory
```

Binary resolves to:
`/home/mcrowe/.local/share/mise/installs/node/22/bin/agentmemory`

### Step 2: Init config dir

```bash
agentmemory init
```

Creates `~/.agentmemory/.env` with defaults. Then uncomment `III_REST_PORT`:

**`~/.agentmemory/.env`** — ensure this line is active (not commented):
```
III_REST_PORT=3111
```

### Step 3: varlock .env.schema for GEMINI_API_KEY

Create `~/.agentmemory/.env.schema` (varlock reads this alongside `.env`):

```
# @plugin(@varlock/1password-plugin@0.3.2)
# @initOp(allowAppAuth=true)
# @defaultSensitive=false
# ---

# @required @sensitive
GEMINI_API_KEY=op(op://Private/GEMINI_API_KEY/credential)

GEMINI_MODEL=gemini-2.5-flash
```

LLM provider detection order: `OPENAI_API_KEY → MINIMAX → ANTHROPIC → GEMINI → OPENROUTER → noop`.
GEMINI_API_KEY is last-resort but sufficient for embeddings + memory.

### Step 4: systemd user service

**`~/.config/systemd/user/agentmemory.service`**:

```ini
[Unit]
Description=agentmemory server
After=network.target

[Service]
Type=simple
ExecStart=/home/mcrowe/.local/share/mise/installs/npm-varlock/latest/bin/varlock run -p %h/.agentmemory -- /home/mcrowe/.local/share/mise/installs/node/22/bin/agentmemory
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

`varlock run -p %h/.agentmemory` injects `.env` + `.env.schema` (with 1Password resolution) into the child process. `%h` = `$HOME` in unit files.

Enable and start:
```bash
systemctl --user daemon-reload
systemctl --user enable --now agentmemory.service
```

### Step 5: Claude Code MCP wiring

Wire agentmemory in the **project `.mcp.json`**, alongside `serena` and `codebase-memory-mcp`:
```json
"agentmemory": {
  "type": "http",
  "url": "http://localhost:3111/mcp"
}
```

**Why `.mcp.json`, not `~/.claude/settings.json`:** the `mcpServers` block in `settings.json` does not load in Claude Code (verified: a session with agentmemory wired there exposed zero `mcp__agentmemory__*` tools, while the `.mcp.json`-wired servers connected fine). `.mcp.json` is the proven path. The tradeoff is per-project: every repo needs the entry. If you want it truly global without editing each `.mcp.json`, use `claude mcp add --scope user agentmemory --transport http http://localhost:3111/mcp` (writes `~/.claude.json`) — that is the actual user-scope mechanism, not the `settings.json` `mcpServers` key.

If you keep `allowedTools` in `~/.claude/settings.json`, add `mcp__agentmemory__*` there.

MCP tools available in CC: `mcp__agentmemory__memory_smart_search`, `mcp__agentmemory__memory_save`, etc.

### Step 6: pi/GSD extension (lifecycle hooks)

Source: https://github.com/rohitg00/agentmemory/tree/main/integrations/pi

Install the extension. It is a **multi-file directory**, not a single file — at minimum `extension-manifest.json` (required for discovery) and `index.ts`, plus `security.ts`, `package.json`, `README.md`. Drop it under the **`~/.gsd/agent/extensions/`** tree — that is the only directory the runtime scans:
```bash
mkdir -p ~/.gsd/agent/extensions/agentmemory
base=https://raw.githubusercontent.com/rohitg00/agentmemory/main/integrations/pi
for f in extension-manifest.json index.ts security.ts package.json README.md; do
  curl -fsSL "$base/$f" -o ~/.gsd/agent/extensions/agentmemory/"$f"
done
```

**No settings wiring needed.** The runtime auto-discovers extensions by scanning `~/.gsd/agent/extensions/*/` at startup (`discoverAllManifests()` in the extension registry reads each `extension-manifest.json` and auto-enables it). Dropping the directory there is sufficient. Do **not** add an `extensions` key to any `settings.json` — there is no `extensions` array in the pi config schema, and those files carry the full hook block (clobbering with `{ "hooks": {}, ... }` would unwire every hook). **`~/.pi/agent/extensions/` is NOT scanned** — placing the extension there leaves it dead (every other working extension lives in `~/.gsd/agent/extensions/`).

Extension provides:
- `before_agent_start` hook — recalls relevant memories into session context
- `agent_end` hook — saves session decisions/outcomes to memory
- Tools: `memory_health`, `memory_search`, `memory_save`
- Command: `/agentmemory-status`

**Note:** Both `~/.pi/agent/settings.json` and `~/.gsd/agent/settings.json` carry the full hook block (same dispatcher, GSD schema). agentmemory's session recall/save is handled by the pi extension at `~/.gsd/agent/extensions/agentmemory/index.ts`, not by these hooks.

### Step 7: Verify

```bash
systemctl --user status agentmemory.service
agentmemory status
```

Expected in `agentmemory status`: `Provider: ✓ llm`, `Embeddings: ✓ embeddings`

Viewer UI: http://localhost:3113
Import past transcripts: `agentmemory import-jsonl`

---

## Hook System

All handlers live in `~/.agents/hooks/<Event>.d/NN-name.sh`. The sole entry point in every `settings.json` is `run-hook.sh <EventName>`. Adding a handler = drop a script in the right `.d/` dir, then run `python3 ~/.agents/bin/activate-hooks` (idempotent).

See `~/.agents/docs/universal-hooks-architecture.md` for full architecture, handler inventory, gate system details, and continuity notebook flow.

---

## Claude Code Settings (`~/.claude/settings.json`)

### Env vars block:
```json
"env": {
  "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50",
  "BASH_MAX_OUTPUT_LENGTH": "10000",
  "MAX_MCP_OUTPUT_TOKENS": "10000",
  "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-4-6",
  "ENABLE_PROMPT_CACHING_1H": "1"
}
```

### Hooks:

All events wire through the single dispatcher. `bin/activate-hooks` generates this automatically.

```json
"hooks": {
  "PreToolUse":       [{ "matcher": "Grep|Glob|Read|Search", "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh PreToolUse", "timeout": 30 }] }],
  "PostToolUse":      [{ "matcher": "Bash|Read|Write|Edit|Glob|Grep|Agent", "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh PostToolUse", "timeout": 30 }] }],
  "SessionStart":     [{ "matcher": "startup|clear", "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh SessionStart", "timeout": 30 }] }],
  "Stop":             [{ "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh Stop", "timeout": 30 }] }],
  "PreCompact":       [{ "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh PreCompact", "timeout": 30 }] }],
  "PostCompact":      [{ "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh PostCompact", "timeout": 30 }] }],
  "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh UserPromptSubmit", "timeout": 30 }] }],
  "Notification":     [{ "matcher": "permission_prompt|elicitation_dialog", "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh Notification", "timeout": 30 }] }],
  "ElicitationResult":[{ "hooks": [{ "type": "command", "command": "/home/mcrowe/.agents/hooks/run-hook.sh ElicitationResult", "timeout": 30 }] }]
}
```

### MCP servers:
The `mcpServers` block in `settings.json` does **not** load in Claude Code — wire MCP servers in the project `.mcp.json` (see Project Bootstrap below), or `~/.claude.json` via `claude mcp add --scope user` for global. agentmemory goes in `.mcp.json` like the rest.

---

## GSD Settings (`~/.gsd/agent/settings.json`)

Same dispatcher, GSD JSON schema (no `type` key, ms timeouts, `blocking` flag).

`PreMilestone` is **GSD-only** — never register it in Claude Code settings. `bin/activate-hooks` enforces this via separate `CLAUDE_EVENTS` / `GSD_EVENTS` lists.

```json
{
  "hooks": {
    "PreToolUse":       [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh PreToolUse",       "timeout": 30000 }],
    "PostToolUse":      [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh PostToolUse",      "timeout": 30000 }],
    "UserPromptSubmit": [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh UserPromptSubmit", "timeout": 30000 }],
    "Notification":     [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh Notification",     "timeout": 30000 }],
    "SessionStart":     [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh SessionStart",     "timeout": 30000 }],
    "Stop":             [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh Stop",             "timeout": 30000 }],
    "PreCompact":       [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh PreCompact",       "timeout": 30000, "blocking": false }],
    "PostCompact":      [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh PostCompact",      "timeout": 30000 }],
    "PreMilestone":     [{ "command": "/home/mcrowe/.agents/hooks/run-hook.sh PreMilestone",     "timeout": 10000, "blocking": false }]
  }
}
```

**Note:** `UserPromptSubmit` and `Notification` **are** GSD/pi events (per gsd-pi `docs/user-docs/hooks.md`) and are wired above. `PreMilestone` **cannot block** under GSD/pi ("Can block: No" in the spec), so `blocking: false` is honest — the clean-baseline check is advisory, not a veto. `PreCompact` is `blocking: false` so a notebook-fold failure can never wedge compaction. agentmemory's own lifecycle is still handled by the pi extension at `~/.gsd/agent/extensions/agentmemory/index.ts`, separate from these hooks.

---

## Global Config Fixes

### Default model per runtime
Set via `defaultModel` in each runtime's `settings.json` — **not** in `~/.gsd/PREFERENCES.md` (which has no `models:` key):
- `~/.gsd/agent/settings.json` → `"defaultModel": "claude-opus-4-7"`
- `~/.pi/agent/settings.json` → `"defaultModel": "claude-sonnet-4-6"`

Claude Code subagents use the `CLAUDE_CODE_SUBAGENT_MODEL` env var in `~/.claude/settings.json` (see Env vars block above).

### Add /handoff command
```bash
cp ~/Programming/AI/claude-code-tips/commands/handoff.md ~/.claude/commands/
```

### Skill symlinks in `~/.claude/skills/`
```bash
cd ~/.claude/skills
ln -sf ../../.agents/skills/handoff handoff
ln -sf ../../.agents/skills/review review
ln -sf ../../.agents/skills/security-review security-review
ln -sf ../../.agents/skills/verify-before-complete verify-before-complete
ln -sf ../../.agents/skills/tdd tdd
ln -sf ../../.agents/skills/serena-init serena-init
```

---

## Project CLAUDE.md / AGENTS.md Addition

Every project CLAUDE.md (and AGENTS.md if it exists) should include the Code Navigation Routing table so the agent knows which tool to reach for first:

```markdown
## Code Navigation Routing

| Task | Tool | Commands |
|------|------|----------|
| Exploration — what/where/how, unfamiliar code | **CBM** | `search_graph`, `trace_path`, `get_code_snippet` |
| Precision — known symbol, editing, type info | **Serena** | `find_symbol`, `get_symbols_overview`, `replace_symbol_body` |
| Session memory / decisions | **agentmemory** | `memory_smart_search` |
| Non-code files (md, yaml, json, config) | **Read directly** | no gate |

Escape gate (one session): `touch /tmp/nav-unlock-$PPID`
```

`serena-init` checks for this table and adds it if missing. Run `~/.agents/bin/serena-init` in any new project.

---

## Project Bootstrap

### `.mcp.json` template:

```json
{
  "mcpServers": {
    "agentmemory": {
      "type": "http",
      "url": "http://localhost:3111/mcp"
    },
    "gsd-workflow": {
      "type": "stdio",
      "command": "/absolute/path/to/node",
      "args": ["/absolute/path/to/gsd-pi/mcp-server/dist/cli.js"],
      "env": {
        "GSD_CLI_PATH": "/absolute/path/to/gsd",
        "GSD_WORKFLOW_PROJECT_ROOT": "/absolute/path/to/project"
      }
    },
    "serena": {
      "type": "stdio",
      "command": "/absolute/path/to/serena",
      "args": ["start-mcp-server", "--context", "claude-code", "--project", "/absolute/path/to/project"]
    },
    "codebase-memory-mcp": {
      "type": "stdio",
      "command": "codebase-memory-mcp",
      "args": ["--project-root", "/absolute/path/to/project"]
    }
  }
}
```

agentmemory MCP goes in `.mcp.json` too (shown above) — the `settings.json` `mcpServers` block does not load in Claude Code. For a truly global entry without per-project wiring, use `claude mcp add --scope user` (writes `~/.claude.json`) instead.

**`gsd-workflow` is GSD-only — add it *only if the project has a `.gsd/` folder*.** For a plain repo with no `.gsd/`, omit the `gsd-workflow` server entirely; `serena` + `codebase-memory-mcp` are the only required entries. The template above shows all three for a GSD-managed project — drop `gsd-workflow` when `.gsd/` is absent.

**GSD local-only overrides**: `.gsd/mcp.json` — same format, merged with `.mcp.json`, first definition wins. Only present/meaningful when `.gsd/` exists.

### Project checklist:

Always (every project):
```
[ ] .mcp.json includes serena (required — GSD has no global MCP fallback)
[ ] .mcp.json includes codebase-memory-mcp
[ ] .mcp.json includes agentmemory (http://localhost:3111/mcp) — settings.json mcpServers does not load
[ ] After install: run mcp__codebase-memory-mcp__index_repository
[ ] code-nav-gate + code-nav-marker already wired globally — no per-project hook changes needed
```

Only if `.gsd/` exists (GSD-managed project):
```
[ ] .mcp.json includes gsd-workflow (skip entirely when no .gsd/)
[ ] .gsd/mcp.json local-only overrides applied if needed
```

---

## File Reference Map

```
~/
├── AGENTS.md                          # Universal directives — master copy
├── .claude/
│   ├── CLAUDE.md                      # = ~/AGENTS.md (auto-loaded by CC)
│   ├── settings.json                  # CC config: env vars, hooks, MCP, permissions
│   ├── commands/
│   │   ├── commit.md
│   │   └── handoff.md
│   ├── hooks/                         # CC-SPECIFIC only
│   │   └── gsd-check-update-worker.js
│   ├── rules/                         # per-stack self-check gates
│   │   ├── flutter.md
│   │   ├── react.md
│   │   └── appwrite.md
│   └── skills/                        # symlinks to ~/.agents/skills/ + local skills
├── .agents/
│   ├── bin/                           # wiring tools + shared executables
│   │   ├── activate-hooks             # idempotent hook wiring into all settings.json files
│   │   ├── serena-init                # project bootstrap (symlinked from dorothy commands)
│   │   └── context_feed/              # hook-driven context capture (Python)
│   ├── hooks/                         # shared hook scripts
│   │   ├── run-hook.sh                # sole dispatcher — wired into ALL agent settings.json
│   │   ├── lib-log.sh / lib-wrapper.sh
│   │   ├── PreToolUse.d/              # 20-bash-ban-raw-tools.sh, 30-code-nav-gate.sh
│   │   ├── PostToolUse.d/             # 10-agentmemory.sh, 20-code-nav-marker.sh
│   │   ├── SessionStart.d/            # 10-agentmemory.sh, 30-context-feed-inject.sh
│   │   └── Stop.d/ PreCompact.d/ PostCompact.d/ UserPromptSubmit.d/ …
│   └── skills/                        # 53+ skills, shared by all runtimes
├── .pi/agent/
│   └── settings.json                  # GSD/pi hooks (no extensions — none scanned here)
├── .gsd/agent/
│   ├── settings.json                  # GSD hooks (GSD schema) + UI/model settings
│   └── extensions/                    # THE scanned extension dir; auto-discovered at startup
│       └── agentmemory/
│           ├── index.ts               # lifecycle recall/save hooks
│           ├── extension-manifest.json
│           ├── security.ts
│           ├── package.json
│           └── README.md
├── .agentmemory/
│   ├── .env                           # III_REST_PORT=3111 (uncommented)
│   └── .env.schema                    # varlock: GEMINI_API_KEY from 1Password
└── .config/
    ├── hooks/
    │   └── clean-baseline-check.sh    # milestone gate
    └── systemd/user/
        └── agentmemory.service        # varlock run ... agentmemory

<project>/
├── CLAUDE.md + AGENTS.md
├── .mcp.json                          # agentmemory + serena + gsd-workflow + codebase-memory-mcp
├── .gsd/                              # workflow state
└── .serena/                           # Serena LSP config
```
