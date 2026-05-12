# The complete getting-started guide to Gas Town

**Gas Town is a multi-agent orchestration system that coordinates swarms of AI coding agents (primarily Claude Code) working in parallel on your repositories.** Built in Go by Steve Yegge and released January 1, 2026, it solves the chaos of manually juggling multiple AI agents by providing persistent work tracking, structured agent roles, and crash-recoverable workflows — all backed by Git. Think of it as "Kubernetes for coding agents." You talk to one AI coordinator (the Mayor), and it dispatches, monitors, and merges work from dozens of parallel workers. This guide walks you through every step from first install to running full swarms.

---

## Prerequisites and installing Gas Town

Gas Town requires several tools installed before you begin. The core dependency chain is **Go → Beads → Gas Town**, plus a few supporting tools.

**Required software:**

- **Go 1.24+** — Gas Town and Beads are both Go binaries
- **Git 2.25+** — worktree support is essential since every worker agent gets an isolated worktree
- **tmux 3.0+** — strongly recommended; all agent sessions run inside tmux and the entire multi-agent experience depends on it
- **sqlite3** — used internally for convoy database queries (pre-installed on macOS/Linux)
- **Claude Code CLI** — the default AI runtime (install from claude.ai/code)

**Optional runtimes** (Gas Town supports multiple AI backends): Codex CLI, Gemini CLI, Cursor, Amp, OpenCode. Built-in agent presets include `claude`, `gemini`, `codex`, `cursor`, `auggie`, and `amp`.

**Install Beads first** (the `bd` command — Gas Town's issue-tracking substrate):

```bash
# Any of these methods works:
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
brew install beads
go install github.com/steveyegge/beads/cmd/bd@latest
```

**Then install Gas Town** (the `gt` command):

```bash
# Homebrew (recommended)
brew install steveyegge/gastown/gt

# npm
npm install -g @gastown/gt

# From source
go install github.com/steveyegge/gastown/cmd/gt@latest
```

If using `go install`, add Go binaries to your PATH by appending this to `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$PATH:$HOME/go/bin"
```

Verify both tools work: `gt version && bd version`. The latest release as of this writing is **v0.5.0** (January 22, 2026).

**Create your workspace** — this is the "Town," your top-level headquarters:

```bash
gt install ~/gt --git
cd ~/gt
```

The `--git` flag auto-initializes a git repository for your town configuration. This creates the directory structure including `.beads/` (town-level tracking), `mayor/` (Mayor agent config with `town.json`), and `deacon/` (the daemon watchdog).

**A note on cost:** Gas Town burns through AI tokens aggressively. One DoltHub reviewer reported **~$100 in Claude tokens for a 60-minute session** — roughly 10× the cost of a single Claude Code session. Yegge himself warns: "You won't like Gas Town if you ever have to think, even for a moment, about where money comes from." A Claude Pro Max subscription ($200/month) or equivalent is effectively required.

---

## What rigs are and how to create one

A **rig** is Gas Town's term for a project. Each rig wraps a single Git repository and manages all the agents, worktrees, and merge infrastructure for that project. Some Gas Town roles (Polecats, Refinery, Witness, Crew) exist per-rig, while others (Mayor, Deacon, Dogs) operate at the town level across all rigs.

**Add your first rig:**

```bash
gt rig add myproject https://github.com/you/repo.git
```

This creates a substantial directory structure:

```
~/gt/myproject/
├── config.json              # Rig identity and metadata
├── .repo.git/               # Bare repo (shared by all worktrees)
├── .beads/                  # Rig-level issue tracking (prefix: "my")
├── plugins/                 # Rig-level plugins
├── mayor/rig/               # Mayor's clone (canonical beads, on main)
│   └── CLAUDE.md            # Per-rig Mayor context
├── refinery/rig/            # Refinery worktree (on main branch)
│   └── CLAUDE.md            # Refinery context
├── witness/                 # Witness config (no clone — monitors only)
├── crew/                    # Persistent human workspaces (initially empty)
└── polecats/                # Ephemeral worker worktrees (dynamically created)
```

The critical architectural detail is the **bare repo pattern**: `.repo.git/` is a shared bare repository, and the Refinery and all Polecats operate as git worktrees pointing at it. This means they all share refs and can see each other's branches without pushing to a remote — the Refinery can directly access Polecat branches for merging.

The `config.json` file stores rig identity:

```json
{"type": "rig", "name": "myproject", "git_url": "https://github.com/...", "beads": {"prefix": "mp"}}
```

The `beads.prefix` field determines the prefix for all bead IDs created in this rig (e.g., `mp-abc12`). **Bead IDs use a prefix + 5-character alphanumeric format**, and the prefix tells you which rig an issue originated from.

**Managing rigs:**

```bash
gt rig list                    # List all rigs
gt rig add beads https://github.com/steveyegge/beads.git   # Add another
gt rig remove oldproject       # Remove a rig
```

After adding a rig, create your personal crew workspace so you have a place to do hands-on work:

```bash
gt crew add yourname --rig myproject
cd myproject/crew/yourname
```

Crew members are long-lived, named agents — your persistent workspace within a rig. You can have multiple crew members per rig with themed names (Yegge uses themes like Jane Austen characters or Lord of the Rings names per rig to identify at a glance which rig a crew member belongs to).

---

## Connecting to existing repos and how worktrees work

When you run `gt rig add`, Gas Town clones the target repository into the bare `.repo.git/` directory and then creates worktrees from it. You never work directly in the bare repo. Instead, every actor — Mayor, Refinery, Crew, and Polecats — gets their own isolated git worktree.

The Mayor's clone at `mayor/rig/` sits on `main` and holds the canonical Beads database. The Refinery's worktree at `refinery/rig/` also tracks `main` and is where merge processing happens. Crew members get their own worktrees under `crew/<name>/rig/`. Polecats get ephemeral worktrees created dynamically under `polecats/<name>/rig/` when work is slung to them — these are destroyed after the polecat completes its task.

**Cross-rig work** is supported through two patterns. The preferred approach uses worktrees:

```bash
gt worktree beads    # Creates ~/gt/beads/crew/gastown-joe/
# Your identity is preserved: BD_ACTOR = gastown/crew/joe
```

Alternatively, you can dispatch work to a rig's local workers:

```bash
bd create --prefix beads "Fix authentication bug"
gt sling bd-xyz beads
```

**Identity and attribution** are tracked automatically. All work is attributed to a structured actor identity:

```
Git commits:      Author: gastown/crew/joe <owner@example.com>
Beads issues:     created_by: gastown/crew/joe
Events:           actor: gastown/crew/joe
```

Gas Town uses **sparse checkout** to isolate its own configuration files from the source repo:

```bash
git sparse-checkout set --no-cone '/*' '!/.claude/' '!/CLAUDE.md' '!/CLAUDE.local.md' '!/.mcp.json'
```

Each role has specific environment variables set automatically when it runs. For example, a Polecat named "Toast" in the "myproject" rig gets: `GT_ROLE=polecat`, `GT_RIG=myproject`, `GT_POLECAT=Toast`, `BD_ACTOR=myproject/polecats/Toast`. These let every tool in the stack know who's doing what.

---

## Setting up beads for task management

**Beads** is Gas Town's universal data plane — a Git-backed issue tracking system where all work state lives. The `bd` CLI is how you create, manage, and query work items. The terms "bead" and "issue" are used interchangeably.

**Initialize Beads** in a project (Gas Town does this automatically for rigs, but standalone usage is also common):

```bash
cd your-project
bd init                    # Standard setup: creates .beads/ directory
bd init --stealth          # Local-only, won't commit to repo
bd init --team             # Branch workflow for collaboration
```

**Creating beads:**

```bash
bd create "Set up database" -p 1 -t task           # Priority 1 task
bd create "Add user auth" -p 2 -t feature           # Priority 2 feature  
bd create "Fix login crash" -t bug -d "Description"  # Bug with description
bd create "Auth System" -t epic -p 1                 # Epic (parent container)
bd create "Login page" -t task --parent <epic-id>    # Child of the epic
```

Types include **task**, **feature**, **bug**, and **epic** (a parent containing children). Priorities range from **P0** (highest/critical) to **P4** (lowest). Bead IDs are hash-based (e.g., `bd-a1b2c`) to prevent merge collisions across multiple agents working on different branches simultaneously.

**Dependencies control execution order:**

```bash
bd dep add <implement-id> <design-id>     # implement blocked until design completes
bd dep add <test-id> <implement-id>       # test blocked until implement completes
bd dep tree <id>                          # Visualize dependency tree
```

Children without explicit dependencies run in **parallel by default**. Adding a `blocks` dependency makes them sequential.

**The `bd ready` command is the most important query** — it shows all issues with no blocking dependencies that are available to work on right now:

```bash
bd ready                      # Show unblocked work
bd ready --json               # Machine-readable output (agents use this)
bd ready --include-deferred   # Include future-deferred issues
bd blocked                    # Show what's blocked and why
```

**Other essential commands:**

```bash
bd list                           # All issues
bd list --status=in_progress      # Filter by status
bd show <id>                      # Full issue details
bd update <id> --status in_progress   # Change status
bd close <id> --reason "Done"     # Close with reason
bd stats                          # Progress statistics
bd sync                           # Sync database with JSONL file
```

Beads stores data in **two layers**: SQLite (`.beads/beads.db`) for fast local queries, and JSONL (`.beads/issues.jsonl`) as the Git-tracked source of truth. The two auto-sync. Gas Town uses a **two-level Beads structure**: rig-level beads for project work (features, bugs), and town-level beads (with the `hq-` prefix) for orchestration work like patrols and release workflows. Beads routing is configured in `~/gt/.beads/routes.jsonl` so commands like `bd show gp-xyz` automatically route to the correct rig's database.

---

## Slinging work to polecats

The `gt sling` command is **the fundamental primitive** for dispatching work in Gas Town. It takes a bead ID and a rig name, spawns a Polecat worker agent, and that worker begins executing the task autonomously.

```bash
gt sling <bead-id> <rig>                    # Basic dispatch
gt sling gt-abc12 myproject                  # Spawn a polecat for this issue
gt sling gt-abc gt-def gt-ghi myproject      # Multiple beads (each gets own worker)
gt sling <bead-id> <rig> --agent cursor      # Override the AI runtime
```

**What happens behind the scenes when you sling:**

1. A polecat name is **allocated from the pool** (Mad Max-themed: Furiosa, Nux, Toast, etc.)
2. A **git worktree** is created at `~/gt/myproject/polecats/Furiosa/` from the shared `.repo.git`
3. The bead's status is updated to `hooked` with the assignee set to `myproject/polecats/Furiosa`
4. A **tmux session** starts: `gt-myproject-polecat-Furiosa`
5. `gt prime` runs automatically, injecting role context and discovering the hooked work
6. The polecat enters **AUTONOMOUS WORK MODE** and begins immediately — no human confirmation needed

The console output looks like:

```
🎯 Slinging my-abc123 to myproject...
Target is rig 'myproject', spawning fresh polecat...
  Allocated polecat: Furiosa
  Created worktree: ~/gt/myproject/polecats/Furiosa
  Auto-applying mol-polecat-work for polecat work...
✓ Work attached to hook (status=hooked)
✓ Args stored in bead (durable)
▶ Start prompt sent
Polecat spawned: myproject/polecats/Furiosa
```

This works because of **GUPP — the Gas Town Universal Propulsion Principle**: "If there is work on your hook, YOU MUST RUN IT." Every agent checks its hook on startup and executes immediately. Gas Town even sends a "GUPP Nudge" roughly 30–60 seconds after startup in case Claude Code is being "too polite" and waiting for input.

**When a polecat finishes**, it runs `gt done`, which pushes its branch to the shared bare repo, submits a merge request to the Refinery's merge queue, notifies the Witness, and then **destroys its own worktree and terminates its session**. Polecats are truly ephemeral — they spawn, work, submit, and vanish.

**Monitoring polecats:**

```bash
gt agents                              # List all active agents across town
gt polecat list <rig>                  # List polecats in a specific rig
gt peek myproject/polecats/Furiosa     # View last 30 lines of terminal output
gt nudge <agent> "message"             # Send immediate message to a worker
```

**Crash recovery** is built in. Every hook, bead, and molecule is stored durably in Git. If a polecat's Claude Code session crashes or runs out of context, the Witness detects it, spawns a new session, and the new session picks up exactly where the previous one left off by reading its hook. This is what Yegge calls **Nondeterministic Idempotence** — the path through the workflow is unpredictable, but the outcome converges as long as you keep throwing agents at it.

---

## Convoys group related work for tracking

Convoys solve a specific problem: when you sling five beads to five polecats, it's hard to tell when "the feature" is done by looking at individual issue completions. A **Convoy wraps multiple beads into a trackable delivery unit** — essentially a work order or feature ticket.

```bash
# Create a convoy with specific issues
gt convoy create "User Auth Feature" gt-abc gt-def gt-ghi --notify --human

# Create an empty convoy and add issues later
gt convoy create "Bug Fixes Sprint"
gt convoy add <convoy-id> gt-xyz gt-qrs

# Monitor progress
gt convoy list                    # Dashboard of all active convoys
gt convoy show <id>               # Detailed progress for one convoy
gt convoy status <id>             # Quick status check
gt convoy refresh <id>            # Force refresh if state seems stale
```

The `--notify` flag tells Gas Town to send notifications on progress, and `--human` marks the convoy as human-initiated (versus system-generated). Convoys have a clear lifecycle: **Created → Active → Landed**. "Landed" means all issues in the convoy are closed. Multiple swarms of polecats can attack the same convoy over time — a convoy might need two or three rounds of work before it lands.

Gas Town also provides a **web dashboard** for visual monitoring:

```bash
gt dashboard --port 8080
open http://localhost:8080
```

This gives you a real-time view with agent status, convoy progress, and auto-refresh via htmx. The TUI dashboard (Charmbracelet-based) shows expanding trees of convoy progress directly in the terminal.

A typical high-level workflow ties everything together: tell the Mayor what you want → Mayor creates a convoy with decomposed beads → Mayor slings each bead to a polecat → polecats work in parallel → polecats submit to merge queue → Refinery merges → convoy lands → Mayor notifies you.

---

## The Refinery merges everything to main

When multiple polecats work simultaneously, they each create branches and submit merge requests. Without coordination, they'd fight over rebasing. The **Refinery** is a dedicated Claude Code agent (one per rig) that processes the merge queue sequentially and intelligently.

The Refinery sits in its own worktree at `<rig>/refinery/rig/` on the `main` branch. Because it shares `.repo.git` with all polecats, it can **directly see their branches** without any remote push. Its workflow runs in a patrol loop:

1. **Check the merge queue** for pending MRs
2. **Check out** the polecat's branch
3. **Rebase** onto current `main`
4. **Run tests** if configured
5. **Merge to main** and push
6. **Close** the MR bead and source issue
7. Repeat until the queue is empty, then sleep with exponential backoff

If merge conflicts are too severe, the Refinery can **creatively re-implement** the change while preserving the original intent. If even that fails, it escalates to the human. No work is lost.

**Refinery commands:**

```bash
gt mq list                    # Show merge queue
gt mq next                    # Process next item
gt mq status                  # Queue status
gt mq submit                  # Submit something to the queue
gt mq retry                   # Retry a failed merge
gt mq reject                  # Reject a merge request
```

The **Witness** works alongside the Refinery as a per-rig patrol agent that monitors polecats. It detects stuck agents, nudges them, triggers recovery, and can alert the Refinery when work completes. Together, the Witness and Refinery form the quality and integration layer for each rig.

You don't have to use the Refinery. For simpler setups, you can tell polecats to **merge directly to main** or submit PRs for manual human review. Yegge notes that Refineries are most valuable "if you have done a LOT of up-front specification work and huge piles of Beads to churn through with long convoys."

---

## The Mayor, formulas, and putting it all together

**The Mayor** is your primary interface — a Claude Code instance at the town level with full context about all your rigs, agents, and workflows. Start every session here:

```bash
gt mayor attach        # Attach to the Mayor's tmux session (shorthand: gt may at)
gt mayor start --agent auggie   # Use a different AI runtime
```

Once attached, you simply talk to the Mayor in natural language: "Our tmux sessions are showing the wrong number of rigs in the status bar — file it and sling it." The Mayor creates a bead, slings it to a polecat, and the work begins. You can also give broader instructions like "review this codebase and file beads for all the TODO items" or "kick off the release process."

**Formulas** define reusable workflow templates in TOML. They live in `.beads/formulas/`:

```toml
# .beads/formulas/shiny.formula.toml
formula = "shiny"
description = "Design before code, review before ship"

[[steps]]
id = "design"
description = "Think about architecture"

[[steps]]
id = "implement"
needs = ["design"]

[[steps]]
id = "test"
needs = ["implement"]

[[steps]]
id = "submit"
needs = ["test"]
```

The pipeline to use a formula is **Cook → Pour → Sling**:

```bash
bd formula list                           # See available formulas
bd cook shiny                             # Cook into a protomolecule (frozen template)
bd mol pour shiny --var feature=auth      # Create a live molecule with steps as beads
gt convoy create "Auth feature" gt-xyz    # Track with a convoy
gt sling gt-xyz myproject                 # Dispatch to a polecat
```

Each molecule step becomes a real bead. The worker executes them in dependency order, closing each as it goes. If the worker crashes after completing "run-tests," a new polecat picks up at "build-binaries." Formulas support **composition** through `extends` and `aspects` for cross-cutting concerns like security audits.

**The complete quick-start checklist:**

```bash
# 1. Install everything
go install github.com/steveyegge/beads/cmd/bd@latest
go install github.com/steveyegge/gastown/cmd/gt@latest
# (also: Go 1.24+, Git 2.25+, tmux 3.0+, Claude Code CLI)

# 2. Create your town
gt install ~/gt --git && cd ~/gt

# 3. Add a project
gt rig add myproject https://github.com/you/repo.git

# 4. Create your crew workspace
gt crew add yourname --rig myproject

# 5. Start the Mayor and go
gt mayor attach
# Then just talk: "File a bead for <task>, then implement it"
```

Running in **Mayor-only mode** is the recommended starting point for learning. You can always add complexity later — polecats for parallel work, the Witness for monitoring, the Refinery for automated merging, and crew members for persistent collaboration. Gas Town is modular by design; every component works independently or in combination. Start simple, talk to the Mayor, and scale up as your comfort and token budget allow.

## Conclusion

Gas Town represents a genuine paradigm shift from "developer using one AI assistant" to **"developer as factory operator managing agent swarms."** The key mental model is a hierarchy: you talk to the Mayor, the Mayor creates convoys of beads and slings them to polecats, polecats work in isolated git worktrees and submit to the Refinery, and the Refinery merges everything to main. Everything is backed by Git through the Beads data plane, so work survives crashes, restarts, and context exhaustion. The system is opinionated, token-hungry, and designed for developers already comfortable managing multiple AI agents. Start with `gt mayor attach`, keep your first convoy small, and resist the urge to swarm until you understand how each piece works individually.