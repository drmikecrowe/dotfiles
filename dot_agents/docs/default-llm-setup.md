# Default LLM / Claude Code Setup
*As-built reference for cross-runtime agent configuration*

---

## Runtime Architecture

Four runtimes share one skill library. Hook scripts live in `~/.agents/hooks/` and are wired into each runtime's config.

```
~/.agents/
├── hooks/          ← canonical shared hook SCRIPTS
│   ├── bash-ban-raw-tools
│   ├── code-nav-gate
│   ├── code-nav-marker
│   ├── code-nav-reminder
│   ├── precompact-hook
│   ├── handoff-session-resume
│   └── serena-activate.sh
└── skills/         ← shared skills, auto-discovered by ALL runtimes

~/.claude/          ← Claude Code runtime
├── CLAUDE.md       ← universal directives (= ~/AGENTS.md)
├── settings.json   ← hooks, MCP servers, permissions, env vars
├── commands/       ← /commit, /handoff
└── hooks/          ← CC-SPECIFIC hooks only

~/.pi/agent/        ← pi/GSD runtime hooks + extensions
├── settings.json   ← hooks (GSD schema) + extensions list
└── extensions/
    └── agentmemory/
        └── index.ts   ← lifecycle hooks (recall/save)

~/.gsd/agent/       ← GSD session/UI settings (NOT hook config)
└── settings.json
```

**Key principle:** Hook SCRIPTS in `~/.agents/hooks/`. Hook WIRING (JSON) in each runtime's config. Same script, two config references.

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

`~/.claude/settings.json` — already present after plugin install:
```json
"mcpServers": {
  "agentmemory": {
    "type": "http",
    "url": "http://localhost:3111/mcp"
  }
},
"allowedTools": ["mcp__agentmemory__*"]
```

Plugin also adds `enabledPlugins["agentmemory@agentmemory"]: true` and `extraKnownMarketplaces.agentmemory`.

MCP tools available in CC: `mcp__agentmemory__memory_smart_search`, `mcp__agentmemory__memory_save`, etc.

### Step 6: pi/GSD extension (lifecycle hooks)

Source: https://github.com/rohitg00/agentmemory/tree/main/integrations/pi

Install the extension file:
```bash
mkdir -p ~/.pi/agent/extensions/agentmemory
curl -fsSL https://raw.githubusercontent.com/rohitg00/agentmemory/main/integrations/pi/index.ts \
  -o ~/.pi/agent/extensions/agentmemory/index.ts
```

Wire it in `~/.pi/agent/settings.json`:
```json
{
  "hooks": {},
  "extensions": ["~/.pi/agent/extensions/agentmemory"]
}
```

Extension provides:
- `before_agent_start` hook — recalls relevant memories into session context
- `agent_end` hook — saves session decisions/outcomes to memory
- Tools: `memory_health`, `memory_search`, `memory_save`
- Command: `/agentmemory-status`

**Note:** GSD uses `~/.pi/agent/settings.json` as its global hooks config — same file, one extension install covers both runtimes. `~/.gsd/agent/settings.json` is UI/model settings only.

### Step 7: Verify

```bash
systemctl --user status agentmemory.service
agentmemory status
```

Expected in `agentmemory status`: `Provider: ✓ llm`, `Embeddings: ✓ embeddings`

Viewer UI: http://localhost:3113
Import past transcripts: `agentmemory import-jsonl`

---

## Hook Implementation

### H1: bash-ban-raw-tools
**Source:** `~/Programming/AI/claude-code-tips/hooks/bash-ban-raw-tools`
**Dest:** `~/.agents/hooks/bash-ban-raw-tools`
**Behavior:** Blocks `cat/head/tail/find/grep/rg/wc` in Bash tool. Forces Read/Grep/Glob. Escape: `touch /tmp/bash-raw-unlock` (10min TTL). `rtk` commands pass through.
```bash
cp ~/Programming/AI/claude-code-tips/hooks/bash-ban-raw-tools ~/.agents/hooks/
chmod +x ~/.agents/hooks/bash-ban-raw-tools
```

### H2: precompact-hook (witness-at-the-threshold)
**Source:** `~/Programming/AI/precompact-hook`
**Behavior:** PreCompact — pipes last ~40KB of transcript to `claude -p` subagent that generates a recovery brief. Falls back gracefully. Always exits 0.
```bash
# Wire directly — no copy needed:
#   bash /home/mcrowe/Programming/AI/precompact-hook/pre-compact.sh
```

### H3: handoff-session-resume
**Source:** `~/Programming/AI/claude-code-tips/hooks/handoff-session-resume`
**Dest:** `~/.agents/hooks/handoff-session-resume`
**Behavior:** SessionStart (compact|resume) — inlines `docs/handoff-context.md` as additionalContext.
```bash
cp ~/Programming/AI/claude-code-tips/hooks/handoff-session-resume ~/.agents/hooks/
chmod +x ~/.agents/hooks/handoff-session-resume
```

### H4: code-nav-gate
**Dest:** `~/.agents/hooks/code-nav-gate`
**Behavior:** PreToolUse on `Grep|Glob|Read|Search` — blocks source file reads until CBM or Serena MCP called. Passes non-code files and system paths through.

```bash
#!/bin/bash
set -euo pipefail

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<< "$INPUT")
MARKER=/tmp/nav-mcp-used-$PPID
UNLOCK=/tmp/nav-unlock-$PPID

[ -f "$UNLOCK" ] && exit 0
find /tmp -maxdepth 1 -name 'nav-*' -mtime +1 -delete 2>/dev/null || true

case "$TOOL" in
  Grep|Glob|Read|Search) ;;
  *) exit 0 ;;
esac

FP=$(jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // .tool_input.glob // ""' <<< "$INPUT")

if [[ "$FP" =~ \.(md|json|yaml|yml|toml|lock|txt|env|sh|cfg|conf|ini)$ ]] \
  || [[ "$FP" =~ (\.claude|\.gsd|\.pi|\.serena|CLAUDE\.md|AGENTS\.md|hooks/|/tmp/|/var/|settings) ]]; then
  exit 0
fi

if [ -f "$MARKER" ]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$MARKER" 2>/dev/null || echo 0) ))
  [ "$AGE" -lt 120 ] && exit 0
fi

cat >&2 << EOF
BLOCKED: Raw $TOOL on source file without recent MCP call.

Use CBM for exploration:   search_graph / trace_path / get_code_snippet
Use Serena for precision:  find_symbol / get_symbols_overview / find_referencing_symbols

Override (this session): touch $UNLOCK
EOF
exit 2
```

### H5: code-nav-marker
**Dest:** `~/.agents/hooks/code-nav-marker`
**Behavior:** PostToolUse — touches `/tmp/nav-mcp-used-$PPID` when CBM or Serena fires (unlocks gate for 120s).

```bash
#!/bin/bash
set -euo pipefail
INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<< "$INPUT")
if [[ "$TOOL" == mcp__codebase-memory-mcp__* ]] || [[ "$TOOL" == mcp__serena__* ]]; then
  touch /tmp/nav-mcp-used-$PPID
fi
exit 0
```

### H6: code-nav-reminder
**Dest:** `~/.agents/hooks/code-nav-reminder`
**Behavior:** SessionStart — prints routing guidance.

```bash
#!/bin/bash
cat << 'EOF'
Code Navigation:
  Exploration (what/where/how):   CBM    → search_graph / trace_path / get_code_snippet
  Precision   (known symbol/edit): Serena → find_symbol / get_symbols_overview
  Session memory / decisions:     agentmemory → memory_smart_search
  Non-code files (md/yaml/json):  Read directly — no gate
  Override gate (one session):    touch /tmp/nav-unlock-$PPID
EOF
```

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
```json
"hooks": {
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "~/.agents/hooks/bash-ban-raw-tools" }
      ]
    },
    {
      "matcher": "Grep|Glob|Read|Search",
      "hooks": [
        { "type": "command", "command": "~/.agents/hooks/code-nav-gate" }
      ]
    }
  ],
  "PostToolUse": [
    {
      "hooks": [
        { "type": "command", "command": "~/.agents/hooks/code-nav-marker" }
      ]
    }
  ],
  "PreCompact": [
    {
      "hooks": [
        { "type": "command", "command": "bash /home/mcrowe/Programming/AI/precompact-hook/pre-compact.sh", "timeout": 90 }
      ]
    }
  ],
  "SessionStart": [
    {
      "hooks": [
        { "type": "command", "command": "~/.agents/hooks/serena-activate.sh", "timeout": 10 }
      ]
    },
    {
      "matcher": "compact|resume",
      "hooks": [
        { "type": "command", "command": "~/.agents/hooks/handoff-session-resume" },
        { "type": "command", "command": "~/.agents/hooks/code-nav-reminder" }
      ]
    },
    {
      "matcher": "clear",
      "hooks": [
        { "type": "command", "command": "~/.agents/hooks/code-nav-reminder" }
      ]
    }
  ]
}
```

### MCP servers (global — all CC sessions):
```json
"mcpServers": {
  "agentmemory": {
    "type": "http",
    "url": "http://localhost:3111/mcp"
  }
}
```

---

## GSD/pi Settings (`~/.pi/agent/settings.json`)

Same hook scripts, GSD JSON schema:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "match": { "tool": "bash" },
        "command": "~/.agents/hooks/bash-ban-raw-tools",
        "blocking": true,
        "timeout": 10000
      },
      {
        "match": { "tool": ["Read", "Grep", "Glob", "Search"] },
        "command": "~/.agents/hooks/code-nav-gate",
        "blocking": true,
        "timeout": 10000
      }
    ],
    "PostToolUse": [
      { "command": "~/.agents/hooks/code-nav-marker", "timeout": 5000 }
    ],
    "SessionStart": [
      { "command": "~/.agents/scripts/agent-startup.sh", "timeout": 10000 },
      { "command": "~/.agents/hooks/serena-activate.sh", "timeout": 10000 },
      { "command": "~/.agents/hooks/code-nav-reminder", "timeout": 5000 }
    ],
    "PostCompact": [
      { "command": "~/.agents/hooks/serena-activate.sh", "timeout": 10000 }
    ],
    "PreCompact": [
      { "command": "bash /home/mcrowe/Programming/AI/precompact-hook/pre-compact.sh", "timeout": 90000 }
    ],
    "PreMilestone": [
      {
        "command": "~/.config/hooks/clean-baseline-check.sh",
        "timeout": 10000,
        "blocking": true
      }
    ]
  },
  "extensions": ["~/.pi/agent/extensions/agentmemory"]
}
```

**Note:** Global hooks in `~/.pi/agent/settings.json` are always trusted — no `.pi/hooks.trusted` marker needed.

---

## Global Config Fixes

### Fix `~/.gsd/PREFERENCES.md` models
```yaml
models:
  research: claude-sonnet-4-6
  planning: claude-opus-4-7
  execution: claude-sonnet-4-6
  execution_simple: claude-haiku-4-5-20251001
  completion: claude-sonnet-4-6
  subagent: claude-sonnet-4-6
```

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

## Project Bootstrap

### `.mcp.json` template:

```json
{
  "mcpServers": {
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

agentmemory MCP is global (CC `settings.json`) — no per-project entry needed.

**GSD local-only overrides**: `.gsd/mcp.json` — same format, merged with `.mcp.json`, first definition wins.

### Project checklist:
```
[ ] .mcp.json includes serena (required — GSD has no global MCP fallback)
[ ] .mcp.json includes gsd-workflow
[ ] .mcp.json includes codebase-memory-mcp
[ ] After gsd init: run mcp__codebase-memory-mcp__index_repository
[ ] agentmemory MCP is global — no per-project entry needed
[ ] code-nav-gate + code-nav-marker already wired globally — no per-project hook changes needed
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
│   ├── hooks/                         # shared hook scripts
│   │   ├── bash-ban-raw-tools
│   │   ├── code-nav-gate
│   │   ├── code-nav-marker
│   │   ├── code-nav-reminder
│   │   ├── handoff-session-resume
│   │   └── serena-activate.sh
│   └── skills/                        # 53+ skills, shared by all runtimes
├── .pi/agent/
│   ├── settings.json                  # GSD/pi hooks + extensions
│   └── extensions/
│       └── agentmemory/
│           └── index.ts               # lifecycle recall/save hooks
├── .gsd/agent/
│   └── settings.json                  # GSD UI/model settings only
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
├── .mcp.json                          # serena + gsd-workflow + codebase-memory-mcp
├── .gsd/                              # workflow state
└── .serena/                           # Serena LSP config
```
