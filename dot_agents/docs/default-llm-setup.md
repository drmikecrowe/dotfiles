# Default LLM / Claude Code Setup
*Target: drive toward claude-code-tips stack across all runtimes*

---

## Runtime Architecture

Four runtimes share one skill library. Hook scripts live once in `~/.agents/hooks/` and are wired into each runtime's separate config format.

```
~/.agents/
├── hooks/          ← canonical shared hook SCRIPTS (← NEW, doesn't exist yet)
│   ├── bash-ban-raw-tools         (from claude-code-tips)
│   ├── code-nav-gate              (NEW: dual CBM+Serena unlock gate)
│   ├── code-nav-marker            (NEW: marks when either CBM or Serena fires)
│   ├── code-nav-reminder          (NEW: SessionStart routing guidance)
│   ├── precompact-hook             (from ~/Programming/AI/precompact-hook)
│   ├── handoff-session-resume     (from claude-code-tips)
│   └── serena-activate.sh         (move from ~/.claude/hooks/)
└── skills/         ← shared skills, auto-discovered by ALL runtimes

~/.claude/          ← Claude Code runtime
├── CLAUDE.md       ← universal directives (= ~/AGENTS.md)
├── settings.json   ← wires ~/.agents/hooks/ scripts (CC JSON schema)
├── commands/       ← /commit, /handoff
└── hooks/          ← CC-SPECIFIC hooks only
    └── gsd-check-update-worker.js

~/.pi/agent/        ← GSD runtime hooks
└── settings.json   ← wires same ~/.agents/hooks/ scripts (GSD JSON schema)

~/.gsd/agent/       ← GSD session/UI settings
└── settings.json

opencode.json       ← OpenCode (project-level only; uses Serena --context opencode)
                       already has read-deny gate on source files
```

**Key principle:** Hook SCRIPTS in `~/.agents/hooks/`. Hook WIRING (JSON) in each runtime's config file. Same script, two config references.

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
[Code Nav: Serena]        LSP precision + exploration ✅
[Memory: agentmemory]     Cross-session memory + decisions ✅
    │                     Server: http://localhost:3111 (systemd: agentmemory.service)
    │                     Repo: https://github.com/rohitg00/agentmemory
```

---

## Tools to Install

### T1: agentmemory (cross-session memory)
Repo: https://github.com/rohitg00/agentmemory
```bash
npm install -g @agentmemory/agentmemory
```
Runs as systemd user service: `~/.config/systemd/user/agentmemory.service`
MCP endpoint: `http://localhost:3111/mcp` (wired in `~/.claude/settings.json`)
Import past transcripts: `agentmemory import-jsonl`
Viewer: http://localhost:3113

### T2: context-mode
Repo: https://github.com/mksglu/context-mode  
MCP server + CLI for output virtualization. Hooks wired via shims (see shims section):
```bash
npm install -g context-mode
~/.agents/shims/generate.sh  # creates/updates shims
```

### T3: Per-stack rule files
From `claude-code-tips/rules/`. Copy to `~/.claude/rules/` — CC auto-loads `rules/*.md` as context for matching file types.
```bash
mkdir -p ~/.claude/rules
cp ~/Programming/AI/claude-code-tips/rules/*.md ~/.claude/rules/
```
Current rules: `flutter.md`, `react.md`, `appwrite.md`. Add project-specific rules here (e.g. `python.md`, `pulumi.md`).  
Pattern: each file enforces a skill gate + numbered self-check before Claude touches that stack.

---

## Hook Implementation Plan

### H1: Create shared hooks directory
```bash
mkdir -p ~/.agents/hooks
```

### H2: bash-ban-raw-tools
**Source:** copy from `~/Programming/AI/claude-code-tips/hooks/bash-ban-raw-tools`
**Dest:** `~/.agents/hooks/bash-ban-raw-tools`
**Behavior:** Blocks `cat/head/tail/find/grep/rg/wc` in Bash tool. Forces Read/Grep/Glob tools. Escape: `touch /tmp/bash-raw-unlock` (10min TTL).
**Note:** `rtk` commands pass through (already handled in script).
```bash
cp ~/Programming/AI/claude-code-tips/hooks/bash-ban-raw-tools ~/.agents/hooks/
chmod +x ~/.agents/hooks/bash-ban-raw-tools
```

### H3: precompact-hook (witness-at-the-threshold)
**Source:** `~/Programming/AI/precompact-hook`
**Behavior:** PreCompact — pipes last ~40KB of session transcript to `claude -p` subagent that generates a recovery brief (who, what happened, what to do next). Subagent has empty context = full attention. Falls back gracefully. Always exits 0.
```bash
# Already cloned at ~/Programming/AI/precompact-hook
# Wire directly — no copy needed:
#   bash /home/mcrowe/Programming/AI/precompact-hook/pre-compact.sh
```

### H4: handoff-session-resume
**Source:** `~/Programming/AI/claude-code-tips/hooks/handoff-session-resume`
**Dest:** `~/.agents/hooks/handoff-session-resume`
**Behavior:** SessionStart (compact|resume matcher) — inlines `docs/handoff-context.md` as additionalContext. Points at file if >9KB.
```bash
cp ~/Programming/AI/claude-code-tips/hooks/handoff-session-resume ~/.agents/hooks/
chmod +x ~/.agents/hooks/handoff-session-resume
```

### H5: code-nav-gate (NEW — write from scratch)
**Dest:** `~/.agents/hooks/code-nav-gate`
**Replaces:** `cbm-code-discovery-gate` but dual-unlock (CBM OR Serena)
**Behavior:**
- PreToolUse on `Grep|Glob|Read|Search`
- Pass through: non-code files (md, yaml, yml, json, toml, lock, txt, env, sh, config files, .claude/, hooks/, /tmp/)
- Pass through: if `/tmp/nav-mcp-used-$PPID` exists and age < 120s
- Pass through: if `/tmp/nav-unlock-$PPID` exists (manual escape)
- Block with message: "Use CBM (search_graph) for exploration OR Serena (find_symbol/get_symbols_overview) for precision. Override: touch /tmp/nav-unlock-$PPID"
- Cleans stale /tmp/nav-* files daily

**Write this file** (see implementation section below)

### H6: code-nav-marker (NEW — write from scratch)
**Dest:** `~/.agents/hooks/code-nav-marker`
**Replaces:** `cbm-mcp-marker` but watches both MCPs
**Behavior:**
- PostToolUse on ALL tools
- If tool_name matches `mcp__codebase-memory-mcp__*` OR `mcp__serena__*` → touch `/tmp/nav-mcp-used-$PPID`

**Write this file** (see implementation section below)

### H7: code-nav-reminder (NEW — write from scratch)
**Dest:** `~/.agents/hooks/code-nav-reminder`
**Replaces:** `cbm-session-reminder` but routes between both tools
**Behavior:** Prints routing guidance on SessionStart (clear|compact|resume matcher)

**Write this file** (see implementation section below)

---

## Claude Code Settings Changes (`~/.claude/settings.json`)

### Add env vars block:
```json
"env": {
  "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50",
  "BASH_MAX_OUTPUT_LENGTH": "10000",
  "MAX_MCP_OUTPUT_TOKENS": "10000",
  "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-4-6",
  "ENABLE_PROMPT_CACHING_1H": "1"
}
```

### Add/update hooks:
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

**Keep existing:** RTK PreToolUse hook, AOE status hooks, PostCompact serena-activate.

---

## GSD Settings Changes (`~/.pi/agent/settings.json`)

Same hook scripts, GSD JSON schema (flat `command` + `match.tool` filter + `blocking` field):

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
  }
}
```

**Note on tool name casing:** GSD example uses lowercase `"bash"` but Read/Grep/Glob may be title-case. Test with one hook first — if Read tool calls don't trigger the gate, try `["read", "grep", "glob", "search"]` instead.

---

## Global Config Fixes

### Fix `~/.gsd/PREFERENCES.md` models
Current models are GLM (test config). Replace:
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
Or verify `~/.agents/skills/handoff/SKILL.md` covers this — check if it has the same JSON output schema as the command.

### Add skill symlinks to `~/.claude/skills/`
Missing symlinks (check first, create if absent):
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

## Project Bootstrap Changes

### `.mcp.json` template (required for both CC and GSD):

**Note:** `~/.claude/settings.json` mcpServers is Claude Code only — GSD has no global MCP config.
Serena and CBM must be in every project's `.mcp.json` for GSD sessions and code-nav-gate to work.

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
    }
  }
}
```
Note: agentmemory MCP is global (wired in `~/.claude/settings.json`) — no per-project entry needed.

**GSD local-only overrides** (paths/secrets, not committed): `.gsd/mcp.json` — same format, merged with `.mcp.json`, first definition wins.

### Updated project checklist (add to bootstrap):
```
[ ] .mcp.json includes serena (required — GSD has no global MCP fallback)
[ ] .mcp.json includes gsd-workflow
[ ] agentmemory MCP is global — no per-project entry needed
[ ] code-nav-gate + code-nav-marker already wired globally — no per-project hook changes needed
```

---

## AGENTS.md / CLAUDE.md Addition

Add to both `~/AGENTS.md` and `~/.claude/CLAUDE.md` (and project CLAUDE.md template):

```markdown
## Code Navigation Routing

Gate enforced by hook — raw Read/Grep on source files blocked until MCP call made.

| Task | Tool | Commands |
|------|------|----------|
| Exploration + precision | **Serena** | `search_graph`, `find_symbol`, `get_symbols_overview`, `replace_symbol_body` |
| Session memory / decisions | **agentmemory** | `memory_smart_search` |
| Non-code files (md, yaml, json, config) | **Read directly** | no gate |

Escape gate (one session): `touch /tmp/nav-unlock-$PPID`
```

---

## Implementation Sequence

Execute in this order — each phase is independently usable:

| Phase | What | Files changed |
|-------|------|--------------|
| **P1** | Create `~/.agents/hooks/`, copy bash-ban-raw-tools + handoff hooks from claude-code-tips, move serena-activate.sh from `~/.claude/hooks/` | mkdir, 3 copies, 1 move |
| **P2** | Write 3 new hooks: code-nav-gate, code-nav-marker, code-nav-reminder | 3 new files |
| **P3** | Wire hooks into `~/.claude/settings.json` + add env vars | 1 edit |
| **P4** | Wire hooks into `~/.pi/agent/settings.json` | 1 edit |
| **P5** | Fix global configs: gsd PREFERENCES.md, skill symlinks, /handoff command, copy rules/ to ~/.claude/rules/ | 4–6 ops |
| **P6** | Install agentmemory (`npm install -g @agentmemory/agentmemory`), enable systemd unit | npm + systemd |
| **P7** | Install context-mode (`npm install -g context-mode`), run `~/.agents/shims/generate.sh` | npm + shims |
| **P8** | Wire agentmemory MCP in `~/.claude/settings.json`, update code-nav hooks | settings + 3 hooks |
| **P9** | Update AGENTS.md + CLAUDE.md with code navigation routing table | 2 edits |

**P1–P4** deliver handoff hooks + navigation gate immediately.  
**P5** is housekeeping.  
**P6–P9** complete the CBM + context-mode integration.

---

## Hook Script Templates

### code-nav-gate
```bash
#!/bin/bash
# PreToolUse: block Grep/Glob/Read/Search on source code
# until CBM (codebase-memory-mcp) or Serena MCP has been called.
# Dual-unlock: either MCP sets /tmp/nav-mcp-used-$PPID.
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

# Extract path/pattern depending on tool
FP=$(jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // .tool_input.glob // ""' <<< "$INPUT")

# Pass through non-code files and system paths
if [[ "$FP" =~ \.(md|json|yaml|yml|toml|lock|txt|env|sh|cfg|conf|ini)$ ]] \
  || [[ "$FP" =~ (\.claude|\.gsd|\.pi|\.serena|CLAUDE\.md|AGENTS\.md|hooks/|/tmp/|/var/|settings) ]]; then
  exit 0
fi

# Check 120s unlock window from last MCP call
if [ -f "$MARKER" ]; then
  AGE=$(( $(date +%s) - $(stat -c %Y "$MARKER" 2>/dev/null || echo 0) ))
  [ "$AGE" -lt 120 ] && exit 0
fi

cat >&2 << EOF
BLOCKED: Raw $TOOL on source file without recent MCP call.

Use CBM for exploration:   search_graph / trace_path / get_code_snippet
Use Serena for precision:  find_symbol / get_symbols_overview / find_referencing_symbols

Then Read/Grep the specific file you need to edit.
Override (this session): touch $UNLOCK
EOF
exit 2
```

### code-nav-marker
```bash
#!/bin/bash
# PostToolUse: mark when CBM or Serena MCP fires (unlocks code-nav-gate for 120s).
set -euo pipefail
INPUT=$(cat)
TOOL=$(jq -r '.tool_name // empty' <<< "$INPUT")
if [[ "$TOOL" == mcp__codebase-memory-mcp__* ]] || [[ "$TOOL" == mcp__serena__* ]]; then
  touch /tmp/nav-mcp-used-$PPID
fi
exit 0
```

### code-nav-reminder
```bash
#!/bin/bash
# SessionStart: print code navigation routing guidance.
cat << 'EOF'
Code Navigation Protocol:
  Exploration (what/where/how):  CBM → search_graph / trace_path / get_code_snippet
  Precision (known symbol, edit): Serena → find_symbol / get_symbols_overview
  Non-code files (md/yaml/json):  Read directly — no gate
  Override gate (one session):    touch /tmp/nav-unlock-$PPID
EOF
```

---

## File Reference Map (Final State)

```
~/
├── AGENTS.md                          # Universal directives — master copy
├── .claude/
│   ├── CLAUDE.md                      # = ~/AGENTS.md (auto-loaded by CC)
│   ├── settings.json                  # CC config: env vars, hooks, permissions
│   ├── commands/
│   │   ├── commit.md
│   │   └── handoff.md                 # ← add
│   ├── hooks/                         # CC-SPECIFIC only
│   │   └── gsd-check-update-worker.js
│   ├── rules/                         # per-stack self-check gates (← add)
│   │   ├── flutter.md                 # from claude-code-tips/rules/
│   │   ├── react.md
│   │   ├── appwrite.md
│   │   └── <stack>.md                 # add project-specific (python, pulumi, etc.)
│   └── skills/                        # symlinks to ~/.agents/skills/ + local skills
├── .agents/
│   ├── hooks/                         # ← CREATE: shared hook scripts
│   │   ├── bash-ban-raw-tools
│   │   ├── code-nav-gate
│   │   ├── code-nav-marker
│   │   ├── code-nav-reminder
│   │   ├── precompact-hook
│   │   ├── handoff-session-resume
│   │   └── serena-activate.sh         # ← move from ~/.claude/hooks/
│   └── skills/                        # 53+ skills, shared by all runtimes
├── .pi/agent/
│   └── settings.json                  # GSD hooks → references ~/.agents/hooks/
├── .gsd/agent/
│   └── settings.json                  # GSD UI settings
└── .config/hooks/
    └── clean-baseline-check.sh        # Milestone gate

<project>/
├── CLAUDE.md + AGENTS.md              # Project rules + code nav routing table
├── .claude/settings.json              # Project CC hooks
├── .pi/settings.json                  # Project GSD hooks
├── .pi/hooks.trusted                  # Must exist
├── .mcp.json                          # serena + gsd-workflow (agentmemory is global)
├── .gsd/                              # Workflow state
├── .agents/hooks/                     # Project-specific hook additions
├── .agents/skills/                    # Project-specific skills
└── .serena/                           # Serena LSP config
```
