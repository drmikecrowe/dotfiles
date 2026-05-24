# Universal Hooks Architecture

> **Extraction note:** This system is designed to be extracted into its own standalone repository. All components are self-contained, runtime-agnostic by default, and require no coupling to `~/.agents` internals. When extracted, `bin/activate-hooks` becomes the installer and `hooks/` becomes the portable library.

## Purpose

The **Universal Hooks system** is a cross-agent hook dispatch framework that wires a single codebase of behaviors, gates, and observability into multiple AI agent runtimes. Currently supports Claude Code and GSD/pi; new runtimes are added by appending one entry to `bin/activate-hooks`.

The goal: one place to define how AI agents behave on this machine, regardless of which runtime is active. The same gates, the same continuity notebook, the same logging — whether the agent is Claude Code, GSD, or a future runtime.

---

## Core Components

### 1. Universal Hook Dispatcher

**File:** `hooks/run-hook.sh <EventName>`

The sole entry point registered in every agent's `settings.json`. When an agent fires an event (e.g. `PreToolUse`, `SessionStart`, `Stop`), it calls this script with the event payload on stdin.

The dispatcher:
1. Reads JSON payload from stdin
2. Discovers `hooks/<EventName>.d/*.sh` (executable, sorted by name prefix)
3. Runs each handler in order, forwarding stdin
4. Propagates the highest non-zero exit code (exit 2 = blocking veto)

Two cross-cutting behaviors are baked into the dispatcher itself (not handlers):
- **Recursion guard:** if `AGENTS_SUMMARIZER=1` is set, the entire dispatch no-ops — prevents a hook→summarizer→hook fork bomb when the continuity notebook spawns a Haiku subprocess
- **Context forwarding:** for context events (`SessionStart`, `UserPromptSubmit`, `PreCompact`, `PostCompact`), text wrapped in `<<<NB_CTX_BEGIN>>>`…`<<<NB_CTX_END>>>` sentinels is forwarded to real stdout for the LLM to see; all other handler output is captured to logs only

### 2. Handler Scripts

**Location:** `hooks/<EventName>.d/NN-name.sh`

Named with a numeric prefix (`10-`, `20-`, `30-`) for deterministic sort order. Gaps of 10 leave room for insertion without renaming.

Each handler:
- Sources `hooks/lib-log.sh` for structured logging
- Reads the JSON payload with `INPUT=$(cat)`
- Exits 0 (allow), exit 2 (veto — only effective on blocking events like `PreToolUse`)
- Requires no changes to `run-hook.sh` or `settings.json` — auto-discovered

### 3. Hook Wiring Tool

**File:** `bin/activate-hooks`

Python script that idempotently wires `run-hook.sh` into all agent `settings.json` files. For each agent:
- Ensures all `<Event>.d/` directories exist
- Detects any existing non-`run-hook.sh` commands and migrates them into `.d/` scripts
- Rewrites settings entries to point at `run-hook.sh`

Run after adding a new handler or registering a new agent runtime.

---

## Gate Systems

Two gates enforce consistent agent behavior at the tool-use layer:

### bash-ban-raw-tools

**Handler:** `hooks/PreToolUse/20-bash-ban-raw-tools.sh`

Blocks `cat`, `head`, `tail`, `find`, `grep`, `rg`, `wc` in Bash tool calls. Also blocks `| head` / `| tail` pipelines.

**Why:** Raw command output floods the context window. The `rtk` prefix wraps commands in the RTK token-compression pipeline, which filters noisy output before it reaches the LLM (90–99% reduction for tests, 60–80% for git/files).

**Escape hatches:**
- `rtk <command>` — always-safe prefix; applies filter if one exists, passthrough otherwise
- `touch /tmp/bash-raw-unlock-$PPID` — session-scoped 10-minute unlock

### code-nav-gate

**Handler:** `hooks/PreToolUse/30-code-nav-gate.sh` + `hooks/PostToolUse/20-code-nav-marker.sh`

Blocks the `Grep`, `Glob`, `Read`, and `Search` tools on source files until an MCP tool fires first in the session.

**Why:** Enforces a "semantic first" code navigation discipline. CBM (code browser MCP) and Serena understand code structure; raw Read/Grep on unfamiliar code leads to piecemeal file reads that waste context.

**Pass-through:** Non-code file extensions (`.md`, `.json`, `.yaml`, `.sh`, `.toml`, config paths, system paths) are never gated.

**Unlock window:** Any MCP tool call touches `/tmp/nav-mcp-used-$PPID`; the gate allows Read/Grep for 120 seconds after.

**Escape hatch:** `touch /tmp/nav-unlock-$PPID` — unlocks for the whole session.

---

## Continuity Notebook

**Problem:** Context compaction wipes session state. Without intervention, the agent after compaction has no memory of what was decided, attempted, or in progress.

**Solution:** A running lab-notebook that captures context incrementally, so recovery after compaction is tight rather than lossy.

### Artifacts (per session)

```
~/.agents/runtime/notebook/<project-slug>/<session_id>/
  intent.md       verbatim user prompts (never LLM-generated; code pastes trimmed)
  notes/NNNN.md   immutable summarizer chunks, one per pass (never re-summarized)
  brief.md        last assembled brief = intent + recent notes (for debugging)
  .turns          turn counter
  .lastline       transcript byte offset of last summarized line
  .last-inject    dedup marker — prevents double inject on SessionStart+PostCompact same fire
```

### Flow

| Event | Handler | Action |
|-------|---------|--------|
### Context Feed (compaction recovery)

The context-feed system captures session context through hook payloads and assembles a recovery brief for post-compaction injection. Fully hook-driven — no transcript parsing, no LLM summarizer.

**Python package:** `bin/context_feed/` — harness adapters, brief assembly, logging. See `docs/compaction-context-feed.md` for full spec.

| Event | Handler | Action |
|-------|---------|--------|
| `UserPromptSubmit` | `30-context-feed-capture.sh` | Capture user prompt → `intent.md` |
| `Stop` | `20-context-feed-capture.sh` | Capture `last_assistant_message` → `notes/NNNN.md` |
| `PostToolUse` (gsd_*_complete) | `30-notebook-unit.sh` | *(GSD/pi only — not yet migrated)* |
| `PreCompact` | `20-context-feed-assemble.sh` | Assemble brief from `intent.md` + `notes/` |
| `SessionStart` / `PostCompact` | `30-context-feed-inject.sh` / `20-context-feed-inject.sh` | Emit brief between `NB_CTX_*` sentinels |

**Legacy pipeline** (transcript-parsing + Haiku summarizer) moved to `bin/legacy/`. See `.legacy` handler backups in each event directory.

---

## Shared Libraries

| File | Purpose |
|------|---------|
| `hooks/lib-log.sh` | Sets `LOG_DIR`/`LOG_FULL`/`LOG_OPS`, tees stdout+stderr to `full.log`, exposes `log_op()`. Source in every handler. |
| `hooks/lib-wrapper.sh` | agentmemory-specific wrapper; sources `lib-log.sh`, adds `am_log_setup()`, `am_run_node()`, `am_debug()` |
| `hooks/lib-notebook.sh.legacy` | *(Legacy)* Old notebook helpers — `nb_spawn_summarizer`, `nb_emit_brief`, `.lastline` tracking. Replaced by `bin/context_feed/`. |
| `hooks/lib-pi-adapter.sh` | Normalize pi/GSD payloads to match Claude Code shape (`session_id`, `cwd`, field renames). Used by GSD-only handlers not yet migrated. |

---

## Runtime Context Injection (AGENTS.md)

**Script:** `scripts/agent-startup.sh`

Fires on `SessionStart` and `PostCompact`. Reads `~/AGENTS.md` and `./.agents/AGENTS.md`, then emits a `hookSpecificOutput` JSON payload that re-injects those directives into the agent's context window. This is how universal directives (caveman mode, RTK rules, gate rules, etc.) survive session boundaries.

---

## Supported Agent Runtimes

| Runtime | Config file | Events registered |
|---------|------------|-------------------|
| Claude Code | `~/.claude/settings.json` | `ElicitationResult` `Notification` `PostCompact` `PostToolUse` `PreCompact` `PreToolUse` `SessionStart` `Stop` `UserPromptSubmit` |
| GSD | `~/.gsd/agent/settings.json` | `PostCompact` `PostToolUse` `PreCompact` `PreMilestone` `PreToolUse` `SessionStart` `Stop` |

**Critical:** Each runtime only registers the events it supports. `bin/activate-hooks` enforces this via separate `CLAUDE_EVENTS` / `GSD_EVENTS` lists. Never add `PreMilestone` to Claude Code or `ElicitationResult`/`Notification`/`UserPromptSubmit` to GSD.

**Adding a new runtime:** append one entry to `AGENT_CONFIGS` at the bottom of `bin/activate-hooks` with the correct `events` list, then run it.

---

## Logging

Logs land in `~/.agents/logs/<project-slug>/`:
- `full.log` — all stdout/stderr from every handler execution
- `ops.log` — strategic decision trail (`ALLOWED` / `BLOCKED` / `START` / `END`)

Debug any handler with `AGENT_HOOK_DEBUG=1` before triggering the relevant agent action.

---

## Adding a New Handler

1. Drop an executable `NN-name.sh` into `hooks/<EventName>.d/`
2. Source `lib-log.sh` and call `log_setup "your-hook-name"` near the top
3. Read JSON payload with `INPUT=$(cat)` — structure varies by event
4. Exit 0 to allow, exit 2 to veto (veto only works on blocking events like `PreToolUse`)
5. Run `python3 bin/activate-hooks` to ensure directories exist (idempotent)

No changes to `run-hook.sh` or `settings.json` needed.

---

## Extending to a New Agent Runtime

1. Determine which events the runtime supports and what JSON payload shape it sends
2. Add an entry to `AGENT_CONFIGS` in `bin/activate-hooks`:
   - `settings_path` — absolute path to the runtime's settings file
   - `events` — list of supported event names
   - `hook_key` — the JSON key the runtime uses for hook commands (e.g. `"hooks"`)
3. Run `python3 bin/activate-hooks`
4. Test with `AGENT_HOOK_DEBUG=1` + a real action in that runtime

Handlers that are runtime-agnostic (like the gate systems) fire automatically. Handlers that use runtime-specific payload fields (like the notebook, which expects `session_id` + `transcript_path`) should degrade gracefully when those fields are absent.

---

## GSD Auto-Mode Hook Setup

GSD auto-mode spawns Claude Code SDK sessions with `settingSources: ["project"]` — these sessions only load project-level `.claude/settings.json`, **not** `~/.claude/settings.json`. For hooks to fire in GSD auto-mode, each project needs a `.claude/settings.json` with hooks wired.

**Per-project setup:**

```bash
# Extract hooks from global settings into project-level config
python3 -c "
import json
hooks = json.load(open('$HOME/.claude/settings.json')).get('hooks', {})
json.dump({'hooks': hooks}, open('.claude/settings.json', 'w'), indent=2)
"
echo ".claude/" >> .gitignore
```

**Alternative:** Patch the installed gsd-pi package's `stream-adapter.js` to use `settingSources: ["global", "project"]`, but this is overwritten on package updates.

**Payload differences:** GSD PreCompact sends `{ branchEntries: N }` — no `session_id`, `transcript_path`, or `cwd`. The `lib-pi-adapter.sh` adapter derives these from `$PWD` and session marker files. All notebook hooks must use `pi_adapt()` instead of raw `$(cat)` to normalize the payload.

**Transcript discovery:** GSD sessions write transcripts to the standard Claude Code projects directory (`~/.claude/projects/<slug>/`). The `20-fold-tail.sh` handler has a fallback that constructs this path from `CWD`, preserving the leading dash in the slug.
