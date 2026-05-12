# Project MCP + Hook Setup for Claude Code / GSD

Reference project: `/home/mcrowe/Programming/MikKelTech/mw-poc/main`

---

## Prerequisites (one-time, already done)

```bash
# context-mode installed globally via npm (standalone mode — NOT the Claude plugin marketplace)
npm install -g context-mode
# Verify
context-mode doctor
```

**No `~/.context-mode/` directory needed.** The standalone npm install stores session data internally. The `~/.context-mode/` dir is only created by the plugin marketplace installer path.

**context-mode is NOT in `enabledPlugins`** — it runs as a standalone MCP server via `.mcp.json`. This is the correct setup for non-plugin installs.

---

## 1. `.mcp.json` (project root)

Add to every new project. Swap `--project` / `cwd` / `GSD_WORKFLOW_PROJECT_ROOT` to the project path.

```json
{
  "mcpServers": {
    "serena": {
      "type": "stdio",
      "command": "serena",
      "args": ["start-mcp-server", "--context", "claude-code", "--project", "/PATH/TO/PROJECT"],
      "env": {}
    },
    "gsd-workflow": {
      "command": "/home/mcrowe/.local/share/mise/installs/node/22.22.2/bin/node",
      "args": [
        "/home/mcrowe/.local/share/mise/installs/node/22.22.2/lib/node_modules/gsd-pi/packages/mcp-server/dist/cli.js"
      ],
      "cwd": "/PATH/TO/PROJECT",
      "env": {
        "GSD_CLI_PATH": "/home/mcrowe/.local/share/mise/installs/node/22/bin/gsd",
        "GSD_WORKFLOW_EXECUTORS_MODULE": "/home/mcrowe/.gsd/agent/extensions/gsd/tools/workflow-tool-executors.js",
        "GSD_WORKFLOW_WRITE_GATE_MODULE": "/home/mcrowe/.gsd/agent/extensions/gsd/bootstrap/write-gate.js",
        "GSD_PERSIST_WRITE_GATE_STATE": "1",
        "GSD_WORKFLOW_PROJECT_ROOT": "/PATH/TO/PROJECT"
      }
    },
    "codebase-memory-mcp": {
      "type": "stdio",
      "command": "/home/mcrowe/.local/bin/codebase-memory-mcp",
      "args": ["--project-root", "/PATH/TO/PROJECT"]
    },
    "headroom": {
      "type": "stdio",
      "command": "/home/mcrowe/.local/share/uv/tools/headroom-ai/bin/headroom",
      "args": ["mcp", "serve"]
    },
    "context-mode": {
      "command": "/home/mcrowe/.local/share/mise/installs/node/22/bin/context-mode"
    }
  }
}
```

---

## 2. `.claude/settings.json` (Claude Code hooks)

Includes all four context-mode hooks (pretooluse, posttooluse, precompact, sessionstart) plus serena, agent-startup, and deploy-block.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "python3 .claude/hooks/block-deploy.py" }]
      },
      {
        "matcher": "Read",
        "hooks": [{ "type": "command", "command": "serena-hooks remind --client=claude-code" }]
      },
      {
        "matcher": "mcp__serena__*",
        "hooks": [{ "type": "command", "command": "serena-hooks auto-approve --client=claude-code" }]
      },
      {
        "matcher": "Read|Bash|Grep|Glob|WebFetch|Agent",
        "hooks": [{ "type": "command", "command": "/home/mcrowe/.local/share/mise/installs/node/22.22.2/lib/node_modules/context-mode/hooks/pretooluse.mjs" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|Read|Write|Edit|NotebookEdit|Glob|Grep|TodoWrite|Agent",
        "hooks": [{ "type": "command", "command": "/home/mcrowe/.local/share/mise/installs/node/22.22.2/lib/node_modules/context-mode/hooks/posttooluse.mjs" }]
      }
    ],
    "PreCompact": [
      {
        "hooks": [{ "type": "command", "command": "/home/mcrowe/.local/share/mise/installs/node/22.22.2/lib/node_modules/context-mode/hooks/precompact.mjs" }]
      }
    ],
    "SessionStart": [
      {
        "hooks": [{ "type": "command", "command": "/home/mcrowe/.local/share/mise/installs/node/22.22.2/lib/node_modules/context-mode/hooks/sessionstart.mjs" }]
      },
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "serena-hooks activate --client=claude-code" }]
      },
      {
        "hooks": [{
          "type": "command",
          "command": "HOOK_EVENT_NAME=SessionStart ~/.agents/scripts/agent-startup.sh",
          "statusMessage": "Loading agent directives..."
        }]
      }
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/serena-activate.sh",
            "statusMessage": "Re-activating Serena post-compaction...",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "HOOK_EVENT_NAME=PostCompact ~/.agents/scripts/agent-startup.sh",
            "statusMessage": "Re-loading agent directives post-compaction..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "serena-hooks cleanup --client=claude-code" }]
      }
    ]
  }
}
```

---

## 3. `.claude/hooks/block-deploy.py`

Copy from reference:
```bash
cp /home/mcrowe/Programming/MikKelTech/mw-poc/main/.claude/hooks/block-deploy.py .claude/hooks/block-deploy.py
```

Blocks: bare `pulumi` calls, `mise run deploy/*` tasks, direct AWS CLI mutations. Exit 2 = blocked.

---

## 4. `~/.gsd/agent/settings.json` (GSD global hooks — already configured)

GSD uses a **different hook schema** than Claude Code (flat `command`, `match.tool` array, no nested `hooks` array). Context-mode hooks are wired globally so they fire across all GSD projects without per-project config.

**Note:** `~/.pi/agent/settings.json` is the old install — hooks there no longer fire. The active global file is `~/.gsd/agent/settings.json`.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": "node ~/.local/share/mise/installs/node/22/lib/node_modules/context-mode/hooks/sessionstart.mjs",
        "timeout": 10000
      }
    ],
    "PostToolUse": [
      {
        "command": "node ~/.local/share/mise/installs/node/22/lib/node_modules/context-mode/hooks/posttooluse.mjs",
        "timeout": 10000
      }
    ],
    "PreCompact": [
      {
        "command": "node ~/.local/share/mise/installs/node/22/lib/node_modules/context-mode/hooks/precompact.mjs",
        "timeout": 30000
      },
      {
        "command": "bash /home/mcrowe/Programming/AI/precompact-hook/pre-compact.sh",
        "timeout": 90000
      }
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

**Schema differences vs Claude Code:**

| | GSD | Claude Code |
|---|---|---|
| Tool filter | `match: { tool: [...] }` | `matcher: "Regex"` |
| Command wrapper | flat `{ command, timeout, blocking }` | nested `hooks: [{ type, command }]` |
| File location (global) | `~/.gsd/agent/settings.json` | `~/.claude/settings.json` |

Hook scripts themselves are identical — same paths referenced in both files.

### `.gsd/settings.json` (per-project GSD hooks — optional)

For project-specific policy (deploy blocks, routing gates). Requires `touch .gsd/hooks.trusted` to activate. Uses same GSD schema as global file above.

---

## context-mode hook roles

| Hook | File | What it does |
|---|---|---|
| PreToolUse | `pretooluse.mjs` | Injects routing instructions — nudges model to use `ctx_*` tools instead of raw Read/Bash/WebFetch |
| PostToolUse | `posttooluse.mjs` | Captures file edits, git ops, tasks, errors into SQLite for session continuity |
| PreCompact | `precompact.mjs` | Snapshots session state to SQLite before compaction so model can resume via BM25 search |
| SessionStart | `sessionstart.mjs` | Injects active session context and routing enforcement at session open |

**The plugin doctor will warn** about `context-mode not in enabledPlugins` — this is expected for standalone npm installs. All four hooks work regardless.

---

## Checklist for new project

- [ ] `.mcp.json` — swap 3 path references to project root
- [ ] `.claude/settings.json` — copy as-is (all 4 context-mode hooks included)
- [ ] `.claude/hooks/block-deploy.py` — copy from reference project
- [ ] `.gsd/agents/settings.json` — copy as-is
- [ ] Restart Claude Code to connect MCP servers
- [ ] Verify with `context-mode doctor` (ignore `enabledPlugins` WARN — expected)
