# Getting Started with Beads and Gas Town

A comprehensive guide for setting up a new project with Steve Yegge's AI coding orchestration tools.

---

## Overview

### What is Beads?

**Beads (bd)** is a git-backed issue tracking system — "a memory upgrade for your coding agent." It provides persistent, git-synchronized work items that AI agents can create, track, and close. Each bead gets a unique ID like `smb-abc12` that can be referenced across sessions.

### What is Gas Town?

**Gas Town (gt)** is a multi-agent orchestration system for Claude Code. It coordinates multiple AI workers (polecats) operating in parallel across git worktrees, with persistent tracking through beads. Gas Town enables you to dispatch independent work items to separate agents that grind simultaneously.

### The Core Idea

Instead of doing a 10-step refactor sequentially (one branch, one PR), you break it into independent pieces and dispatch them to polecats that work in parallel. Each polecat gets its own isolated git worktree and focuses on one bead until completion.

---

## Prerequisites

- **Go 1.23+**
- **Git 2.25+**
- **Beads 0.44.0+** — `go install github.com/steveyegge/beads/cmd/bd@latest`
- **sqlite3**
- **tmux 3.0+**
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`

---

## Installation

### Install Beads

```bash
go install github.com/steveyegge/beads/cmd/bd@latest
```

### Install Gas Town

```bash
go install github.com/steveyegge/gastown/cmd/gt@latest
```

---

## Initial Setup

### Step 1: Create Your Town

The "town" is your workspace directory containing all projects and agents.

```bash
gt install ~/gt --git
```

This creates:
- `~/gt/` — Your town directory
- `~/gt/.dolt-data/` — Dolt database storage (beads, routing, state)
- `~/gt/config.json` — Town configuration
- `~/gt/routes.json` — Bead routing rules

### Step 2: Create a Rig (Project)

A "rig" is a project container that wraps a git repository.

```bash
gt rig add myproject https://github.com/username/myproject.git
```

This creates:
- `~/gt/myproject/.repo.git` — Bare git clone
- `~/gt/myproject/config.json` — Rig configuration with bead prefix

**Choose your bead prefix wisely** — it's used for all bead IDs in this project (e.g., `mp-abc12` for "myproject").

### Step 3: Add Yourself as Crew

Crew members are persistent human workspaces within a rig.

```bash
gt crew add myproject --name mike
```

This creates:
- `~/gt/myproject/crew/mike/` — Your worktree
- A branch for your work

### Step 4: Attach the Mayor

The Mayor is the AI coordinator that manages the town.

```bash
gt mayor attach myproject
```

This creates:
- `~/gt/myproject/mayor/rig/` — The mayor's worktree
- Sets up hooks for persistent agent work

---

## Beads Setup (AI Tool Integration)

### Configure Your AI Tool

Beads supports multiple AI coding tools. Run the appropriate setup command:

```bash
# For Claude Code (recommended)
bd setup claude

# Other options
bd setup cursor
bd setup windsurf
bd setup cody
bd setup kilocode
bd setup gemini
bd setup aider
```

### What This Does

The setup command:
1. Adds hooks to your AI tool's configuration
2. Configures `bd prime` to run on session start
3. Sets up `PreCompact` hooks for context preservation

### AGENTS.md

Create an `AGENTS.md` file in your repo root with project-specific instructions. This is the industry-standard format for AI coding agent instructions:

```markdown
# Project Instructions for AI Agents

## Build Commands
- `npm run build` — Build the project
- `npm test` — Run tests

## Code Style
- Use TypeScript strict mode
- Prefer functional components

## Key Files
- `src/index.ts` — Entry point
- `src/utils/` — Shared utilities
```

---

## Basic Workflow

### Creating Beads

Create beads for discrete units of work:

```bash
bd create --rig myproject --title="Extract config into shared module" --type=task --priority=2
bd create --rig myproject --title="Replace inline styles with CSS classes" --type=task --priority=2
bd create --rig myproject --title="Migrate utils from CommonJS to ESM" --type=task --priority=2
```

Each bead gets a unique ID like `mp-abc12`, `mp-x7k2m`, etc.

### Setting Dependencies

Some steps must happen before others:

```bash
bd dep add mp-abc12 mp-x7k2m   # "Extract config" depends on "Migrate to ESM"
```

View unblocked work:

```bash
bd ready
```

### Slinging Work to Polecats

Each `gt sling` spawns a worker agent in its own git worktree:

```bash
gt sling mp-x7k2m myproject   # ESM migration — no blockers, goes first
gt sling mp-abc12 myproject   # CSS classes — independent, can run in parallel
```

Each polecat gets:
- Its own worktree (isolated branch)
- The bead hooked to it (knows what to do)
- A tmux session running an agent

### Monitoring Progress

```bash
gt polecat list myproject     # See active polecats
gt convoy list                # If you grouped work into a convoy
bd list --rig myproject       # See bead statuses
```

Polecats close their beads when done and push their branches.

---

## Key Concepts

### Role Taxonomy

| Role | Description |
|------|-------------|
| **Mayor** | Primary AI coordinator with full workspace context |
| **Polecat** | Ephemeral worker agent — spawns, completes tasks, disappears |
| **Crew** | Persistent human workspaces within a rig |
| **Deacon** | Background supervisor daemon |
| **Witness** | Per-rig polecat lifecycle manager |
| **Refinery** | Per-rig merge queue processor |
| **Dog** | Utility role for cross-rig work |

### Bead ID Format

Beads use the format `prefix-abc12` where:
- `prefix` is set in the rig's config (e.g., `smb` for show_media_bias)
- `abc12` is a unique base62 identifier

### Convoy Tracking

For large refactors, bundle beads into a convoy:

```bash
gt convoy create "v5 ESM Migration" mp-001 mp-002 mp-003 mp-004
gt convoy status <convoy-id>
```

### Hooks

Hooks are git worktree-based persistent storage. When you "find something on your hook, YOU RUN IT" — this is the **Propulsion Principle**.

```bash
gt hook              # Shows hooked work (if any)
gt mail inbox        # Check for messages
```

---

## Directory Structure

After setup, your town looks like:

```
~/gt/
├── .dolt-data/           # Dolt databases (beads, routing, state)
├── config.json           # Town configuration
├── routes.json           # Bead routing rules
└── myproject/            # Your rig
    ├── .repo.git/        # Bare git clone
    ├── config.json       # Rig config (includes bead prefix)
    ├── mayor/
    │   └── rig/          # Mayor's worktree
    ├── crew/
    │   └── mike/         # Your crew workspace
    └── polecats/         # Polecat worktrees (ephemeral)
```

---

## Common Commands Reference

### Town Management

```bash
gt install ~/gt --git           # Create town
gt status                       # Town overview
gt dolt start                   # Start Dolt server
gt dolt stop                    # Stop Dolt server
```

### Rig Management

```bash
gt rig add <name> <git-url>     # Add new rig
gt rig list                     # List all rigs
gt rig remove <name>            # Remove rig
```

### Bead Operations

```bash
bd create --rig <name> --title="..." --type=task
bd list --rig <name>            # List beads
bd ready                        # Show unblocked work
bd dep add <bead> <depends-on>  # Add dependency
bd close <bead-id>              # Close a bead
```

### Polecat Operations

```bash
gt sling <bead-id> <rig>        # Dispatch work to polecat
gt polecat list <rig>           # List active polecats
gt polecat nuke <rig>/<id>      # Kill a polecat
```

### Convoy Operations

```bash
gt convoy create "Name" <bead-ids...>
gt convoy list
gt convoy status <id>
```

---

## Workflow Patterns

### The Mayor-Enhanced Orchestration Workflow (MEOW)

1. **Plan as Mayor**: Break work into discrete beads
2. **Set dependencies**: Only where truly required
3. **Parallelize aggressively**: Sling independent work simultaneously
4. **Monitor**: Track progress via convoys and bead lists
5. **Refinery merges**: Completed work integrates continuously

### Multi-Step Refactor Pattern

```bash
# 1. Create beads for each step
bd create --rig smb --title="Step 1: Extract config" --type=task
bd create --rig smb --title="Step 2: Migrate to ESM" --type=task
bd create --rig smb --title="Step 3: Update tests" --type=task

# 2. Set dependencies
bd dep add smb-001 smb-002   # Step 1 depends on Step 2

# 3. Bundle into convoy
gt convoy create "ESM Migration" smb-001 smb-002 smb-003

# 4. Sling unblocked work
gt sling smb-002 smb   # Goes first (no dependencies)

# 5. After completion, sling next
gt sling smb-001 smb   # Now unblocked
```

### When to Fix It Yourself

Not everything needs a polecat. If you're already reading the code and spot a quick fix, just do it directly in your crew or mayor worktree.

**Rule of thumb**: If it takes longer to describe than to do, just do it.

---

## Troubleshooting

### Orphaned Dolt Databases

If you have leftover databases from earlier setup attempts:

```bash
gt dolt cleanup
```

### Stale Worktrees

If a polecat worktree is stuck:

```bash
gt polecat nuke <rig>/<id> --force
```

### Sync Issues

If your rig's main branch diverges from origin:

```bash
cd ~/gt/myproject/mayor/rig
git fetch origin
git reset --hard origin/main
```

### Prefix Conflicts

If you see multiple bead prefixes for the same rig, check `routes.json` and remove stale entries.

---

## Resources

- **Beads GitHub**: https://github.com/steveyegge/beads
- **Gas Town GitHub**: https://github.com/steveyegge/gastown
- **Beads Setup Docs**: https://github.com/steveyegge/beads/blob/main/docs/SETUP.md
- **Gas Town Overview**: https://github.com/steveyegge/gastown/blob/main/docs/overview.md
