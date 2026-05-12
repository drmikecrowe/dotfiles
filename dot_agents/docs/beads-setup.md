# Beads Getting Started Guide

### Dolt SQL Server + Gastown Integration on a Single Manjaro Machine

> **⚠️ Rapid churn notice.** This guide reflects the current state of `main` as of mid-March 2026 (tested with v0.60.0). Beads has had 80+ releases in ~6 months. Always cross-check `bd help` and `bd help init` for the authoritative flag list on your installed version.

---

## Mental model: three things that must all be healthy

1. **One shared Dolt SQL server** — a single `dolt sql-server` process on port **3307**, running as a systemd user service, hosting all your projects as separate named databases. Every `bd` command connects to it via MySQL protocol. If it's down, `bd` fails or deadlocks. It should never be down.

2. **`.beads/` directory per project** — created by `bd init`. Contains config files and (locally) the Dolt database directory. Lives inside your git repo root.

3. **`metadata.json`** — the file that tells Beads _how_ to connect: which host, port, mode, and critically **which database name** (`dolt_database`) to use on the shared server. Every project needs a unique `dolt_database` value.

Most setup failures are one of these three breaking in isolation while the other two look healthy. The shared server model eliminates the most common failure class: port conflicts from multiple per-project servers.

---

## Prerequisites

```bash
# Install Dolt — required, must be on PATH
curl -L https://github.com/dolthub/dolt/releases/latest/download/install.sh | bash
dolt version   # Need 1.82.4+

# Install Beads CLI
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
# OR via AUR (you're on Manjaro):
yay -S beads-git
# OR via go:
go install github.com/steveyegge/beads/cmd/bd@latest

bd version     # Verify it's installed and on PATH
```

---

## Part 1: Initializing a project from scratch

### The key fact: `--backend dolt` is gone

As of a recent release, **Dolt is the default backend**. The `--backend dolt` flag was removed because it's now implicit. Plain `bd init` gives you Dolt automatically.

```bash
cd ~/your-project

bd init                  # Interactive wizard — Dolt backend, prompts for role/hooks/etc.
bd init --quiet          # Non-interactive — auto-installs hooks, accepts all defaults
bd init --prefix myapp   # Custom issue prefix (default: "bd")
bd init --stealth        # Local-only — doesn't commit .beads/ to the repo (personal use)
bd init --contributor    # OSS fork workflow — routes planning issues to separate repo
bd init --team           # Team member workflow — uses collaboration branch
bd init --force          # Re-initialize an existing .beads/ (careful: may reset state)
```

The `bd init` wizard will:

- Create `.beads/` directory and the Dolt database inside it at `.beads/dolt/`
- Prompt for your role (maintainer vs. contributor) unless a flag specifies it
- Offer to install git hooks (say yes: pre-commit, post-merge, post-checkout, pre-push, prepare-commit-msg)
- Offer to configure the git merge driver (say yes for multi-agent work)
- **Auto-start the Dolt SQL server** for the initial database operations

### What `bd init` creates

```
your-project/
└── .beads/
    ├── config.yaml          # Project config (git-tracked)
    ├── config.local.yaml    # Machine-local overrides (gitignored)
    ├── metadata.json        # Backend/connection metadata (git-tracked)
    ├── interactions.jsonl   # Interaction log (git-tracked)
    ├── dolt/                # Dolt database (gitignored — not committed to git)
    │   ├── .dolt/
    │   ├── .bd-dolt-ok      # Marker file indicating v0.56+ format
    │   ├── sql-server.pid
    │   └── sql-server.log
    └── hooks/               # Git hook scripts
        ├── pre-commit
        ├── pre-push
        ├── post-merge
        ├── post-checkout
        └── prepare-commit-msg
```

### Verify it worked

```bash
bd where --json          # Shows which database is active and how it was found
bd doctor                # Full health check
bd doctor --fix          # Auto-fix any issues (backfill project_id, update hooks)
bd doctor --server       # Dolt server-specific checks
bd ready                 # Quick status — shows open issues
bd info                  # Database info including backend type
```

---

## Part 2: Running a shared Dolt server (recommended)

The default Beads behavior is one `dolt sql-server` process per project, each with its own port, PID file, and lifecycle. This gets messy fast with multiple projects and Gastown.

**The better approach**: run one persistent Dolt server on port 3307, shared across all projects. Dolt is a full SQL server — one process can host multiple databases simultaneously, namespaced by `dolt_database` in each project's `metadata.json`.

### Step 1: Create a central Dolt data directory

```bash
mkdir -p ~/.local/share/beads-dolt
cd ~/.local/share/beads-dolt
dolt init
```

### Step 2: Create a server config file

```yaml
# ~/.local/share/beads-dolt/config.yaml
log_level: info

behavior:
  autocommit: false # Beads manages commits itself
  dolt_transaction_merge: true

listener:
  host: 127.0.0.1
  port: 3307
  read_timeout_millis: 28800000
  write_timeout_millis: 28800000

performance:
  query_parallelism: 2
```

### Step 3: Install as a persistent systemd user service

```ini
# ~/.config/systemd/user/beads-dolt.service
[Unit]
Description=Beads shared Dolt SQL server
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/.local/share/beads-dolt
ExecStart=/usr/bin/dolt sql-server --config %h/.local/share/beads-dolt/config.yaml
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now beads-dolt.service

# Verify it's up:
systemctl --user status beads-dolt.service
ss -tlnp | grep 3307

# Logs:
journalctl --user -u beads-dolt -f
```

### Step 4: Point each project at the shared server

When you run `bd init`, it creates `.beads/dolt/` locally and may auto-start a per-project server. After init, stop that and redirect to the shared server:

```bash
cd ~/your-project
bd init --quiet

# Stop the local server bd init started:
bd dolt stop

# Create the project's database namespace on the shared server:
dolt --host 127.0.0.1 --port 3307 --no-tls sql -q "CREATE DATABASE IF NOT EXISTS myapp;"

# Edit .beads/metadata.json to point at the shared server:
```

```json
{
  "backend": "dolt",
  "database": "dolt",
  "dolt_mode": "server",
  "dolt_server_host": "127.0.0.1",
  "dolt_database": "myapp",
  "project_id": "c84267e9-5526-4e1d-bd7d-5c3141b3ed9c",
  "last_bd_version": "0.60.0"
}
```

**Note:** `dolt_server_port` is deprecated — remove it from metadata.json. The port is now stored in `.beads/dolt-server.port`.

```bash
# Verify:
bd where --json
bd doctor --server
```

**Critical**: every project must have a unique `dolt_database` name. Two projects sharing the same name on the shared server will corrupt each other's data.

### Step 5: For Gastown

Tell Gastown the server is externally managed rather than letting it try to start its own:

```bash
# In your Gastown town root:
gt dolt fix-metadata --host 127.0.0.1 --port 3307
gt doctor
```

Skip `gt dolt start` — the systemd service handles that. If Gastown tries to start a competing server, kill it:

```bash
gt dolt kill-imposters
```

### What changes day-to-day with a shared server

- **No more `bd dolt start` per project** — the systemd service is always up after login
- **No more port conflicts** — everything on 3307, namespaced by database name
- **No per-project PID/log files** — `journalctl --user -u beads-dolt -f` for all logs
- **`bd dolt start` becomes a no-op / error** — that's fine, the server is already there
- **`bd doctor --server` still works** — just checks the connection on 3307

### Verify the shared server has all your databases

```bash
dolt sql -u root -h 127.0.0.1 -P 3307 -q "SHOW DATABASES;"
# Expected: myapp, gastown, proj2, information_schema, ...
```

### Switching server modes (reference)

```bash
bd dolt set mode server    # Multi-writer MySQL protocol on 3307 (required for Gastown)
bd dolt set mode embedded  # Single-writer in-process (legacy, avoid)
```

For Gastown and multi-agent work, **server mode is mandatory**. The shared server setup above keeps you in server mode permanently.

---

## Part 3: Sharing the database between your project repo and Gastown

With the shared Dolt server from Part 2 running, this becomes straightforward — both your project and Gastown connect to the same server process, each using their own `dolt_database` namespace.

### Recommended: register your project as a Gastown rig

```bash
# In your Gastown town directory
gt rig add ~/your-project --prefix myapp

# Tell Gastown about the externally-managed server
gt dolt fix-metadata --host 127.0.0.1 --port 3307

# Verify
gt doctor
bd where --json   # From inside ~/your-project — confirm shared server on 3307
```

Each rig gets its own issue prefix (`myapp-*`) to prevent ID collisions across the shared server.

### Alternative: redirect file (no Gastown ownership)

If you want the repos fully independent but sharing the database:

```bash
cd ~/gastown-workspace
mkdir -p .beads
echo "/home/you/your-project/.beads" > .beads/redirect

bd where   # Should show your-project's .beads as the active database
```

**Redirect constraints**: Single-level only (A → B works; A → B → C doesn't).

### The one thing that still breaks: Gastown trying to start its own server

Even with the shared server running, Gastown may attempt to start a competing `dolt sql-server` on 3307. Kill it and prevent it:

```bash
gt dolt kill-imposters        # Clean up any Gastown-spawned servers
gt dolt fix-metadata --host 127.0.0.1 --port 3307   # Point Gastown at the real server
```

---

## Part 4: Config files and environment variables

### Configuration precedence (highest wins)

1. CLI flags (`--json`, `--prefix`, etc.)
2. Environment variables
3. `.beads/config.local.yaml` (gitignored, machine-specific)
4. `.beads/config.yaml` (git-tracked, project config)
5. `~/.config/bd/config.yaml` (global user config)
6. Database config table (inside Dolt)
7. Hardcoded defaults

### The project config: `.beads/config.yaml`

```yaml
issue-prefix: "myapp"

dolt:
  auto-commit: on # Commit to Dolt history after each write

sync:
  mode: dolt-native # dolt-native | git-portable | realtime | belt-and-suspenders
  export_on: push
  import_on: pull
  conflict:
    strategy: newest # newest | ours | theirs | manual

git:
  author: "beads-bot <beads@example.com>"
  no-gpg-sign: true
```

**Format is YAML, not TOML.** The documentation website mentions `.toml` in some places but the actual codebase reads `.yaml`. If you have a `config.toml`, it will be silently ignored.

### The metadata file: `.beads/metadata.json`

This is what controls how Beads discovers and connects to the database. If this is wrong, nothing works:

```json
{
  "backend": "dolt",
  "database": "dolt",
  "dolt_mode": "server",
  "dolt_server_host": "127.0.0.1",
  "dolt_database": "myapp",
  "project_id": "c84267e9-5526-4e1d-bd7d-5c3141b3ed9c",
  "last_bd_version": "0.60.0"
}
```

**Important changes in recent versions:**

- **`dolt_server_port` is deprecated** — can cause cross-project data leakage. The port file (`.beads/dolt-server.port`) is now the primary source. Remove `dolt_server_port` from `metadata.json` to silence the warning.
- **`project_id` is now required** — auto-generated UUID for project identity (added in GH#2372). `bd doctor --fix` will backfill this for older projects.
- `dolt_mode` must be `"server"` for multi-agent use. If it says `"embedded"`, switch it:

```bash
bd dolt set mode server
cat .beads/metadata.json   # Verify dolt_mode changed
```

### Useful environment variables

| Variable             | What it does                                     |
| -------------------- | ------------------------------------------------ |
| `BEADS_DIR`          | Override `.beads/` location (useful for testing) |
| `BEADS_DB`           | Override database path directly                  |
| `BD_ACTOR`           | Actor name for audit trails                      |
| `BD_BRANCH`          | Branch-per-agent write isolation                 |
| `BD_DEBUG_RPC=1`     | Show Dolt server communication                   |
| `BD_DEBUG_SYNC=1`    | Show sync internals                              |
| `BD_DEBUG_ROUTING=1` | Show issue routing decisions                     |

The three `BD_DEBUG_*` variables are invaluable for diagnosing connection failures.

---

## Part 5: Git hooks and git integration

### Installing hooks

```bash
bd hooks install           # Install all hooks
bd hooks install --force   # Reinstall (do this after migration or re-init)
bd hooks status            # Check what's installed
bd hooks uninstall         # Remove all beads hooks
```

Installed hooks (as of v0.60.0):
- `pre-commit` — validates before commit
- `pre-push` — validates before push
- `post-merge` — syncs after merge
- `post-checkout` — handles branch switching
- `prepare-commit-msg` — prepares commit message

### Known bug: hook self-deadlock when server is down

If `dolt_mode: server` is configured but the Dolt server isn't running when a git commit or checkout fires, the hook tries to connect, fails, falls back to embedded mode, and acquires the noms LOCK — deadlocking itself. Symptoms:

```
Warning: Dolt server at 127.0.0.1:3307 is not reachable, falling back to embedded mode
Warning: could not open database: failed to create dolt database: the database is locked
```

**Fix**: Always start the Dolt server before doing git operations in a beads repo.

```bash
bd dolt start && git commit -m "..."
```

This is a known bug (issue #1719) — the hook subcommand was missing from the `noDbCommands` list. Check if your version has the fix, or simply make `bd dolt start` part of your session startup.

---

## Part 6: `bd doctor` — your primary diagnostic tool

Run this whenever something breaks. It checks everything.

```bash
bd doctor                  # Full diagnostic
bd doctor --server         # Dolt server-specific checks (phantom entries, connection)
bd doctor --fix            # Auto-repair detected issues (review suggestions before applying)
bd doctor --gastown        # Gastown integration checks
```

### What `bd doctor --fix` can auto-repair (v0.60.0)

| Issue | Auto-fix? | Description |
|-------|-----------|-------------|
| Git Hooks outdated | ✓ Yes | Reinstalls all hooks to latest version |
| Project Identity missing | ✓ Yes | Backfills `project_id` UUID into metadata.json |
| Gitignore outdated | ✓ Yes | Updates `.beads/.gitignore` with required patterns |
| Dolt Format (pre-0.56) | ✗ Manual | Delete `.beads/dolt/.dolt/` and re-run, or restart server |
| Dolt Status uncommitted | ✗ Manual | Run `bd vc commit -m "message"` |
| Git Working Tree dirty | ✗ Manual | Commit or stash changes |
| Git Upstream ahead | ✗ Manual | Run `git push` |

`bd doctor --fix` is generally safe but has had bugs in past versions — it once reset sync branch history and self-deadlocked on embedded mode. Review what it proposes before confirming destructive actions.

---

## Part 7: Common errors and fixes

### "Can't find database" / `bd` connects to nothing

```bash
bd where --json            # What database does bd think it's using?
cat .beads/metadata.json   # Is dolt_mode: "server"?
ss -tlnp | grep 3307       # Is the server actually running?
bd dolt start              # Start it if not
```

### Stale LOCK file (database locked by another process)

```bash
# Test if the lock is actually held by a live process:
flock -n .beads/dolt/.dolt/lock echo "Lock is free"
# If "Lock is free" prints, it's a stale file — safe to remove:
rm .beads/dolt/.dolt/lock
bd dolt start
```

### Port 3307 already in use

```bash
ss -tlnp | grep 3307
kill $(lsof -t -i :3307)    # Kill the conflicting process
# If running Gastown:
gt dolt kill-imposters
bd dolt start               # Restart clean
```

### Phantom catalog entries (issues from wrong database appearing)

Caused by `dolt_database` in `metadata.json` not matching the actual Dolt database name.

```bash
cat .beads/metadata.json | grep dolt_database
ls .beads/dolt/            # What's the actual database directory name?
# If they don't match, edit metadata.json to fix dolt_database
bd doctor --server         # Verify fix
```

### After `git clone` — Dolt database is missing

The `.beads/dolt/` directory is gitignored, so clones don't include it. After cloning a repo with an existing `.beads/` config:

```bash
git clone <repo>
cd <repo>
bd init                    # Recreates the Dolt database from config (safe on existing .beads/)
bd doctor
```

### Old reset data keeps coming back

If you ran `bd admin reset --force` but issues keep reappearing:

```bash
bd admin reset --force
# Also delete any sync branches on the remote:
git config --get beads.sync.branch    # Find the branch name
git push origin --delete <sync-branch-name>
bd init
```

### Skip-worktree bits causing git to ignore changes

Leftover from the old beads-sync worktree feature:

```bash
git ls-files -v | grep '^S'                           # Find affected files
git update-index --no-skip-worktree <file>            # Fix each one
```

### Pre-0.56 Dolt database format (missing `.bd-dolt-ok` marker)

If `bd doctor` reports "Dolt database from pre-0.56 bd version", the database lacks the format marker:

```bash
# Option 1: Delete and let it rebuild
rm -rf .beads/dolt/.dolt/
bd doctor --fix        # Will auto-rebuild

# Option 2: Restart the Dolt server (auto-recovery will rebuild it)
systemctl --user restart beads-dolt.service
bd doctor --fix
```

### Deprecated `dolt_server_port` in metadata.json

```bash
# Remove the deprecated field to silence the warning:
nvim .beads/metadata.json   # Delete the "dolt_server_port" line
bd doctor --fix             # Verify fix
```

---

## Part 8: The complete setup checklist

Start here if you're setting up fresh or recovering from a broken state.

### Step 1: Verify prerequisites

```bash
dolt version       # Must be 1.82.4+
bd version         # Must be installed, note the version
which bd           # Must be on PATH
```

### Step 2: Set up the shared Dolt server (do this once, not per project)

```bash
mkdir -p ~/.local/share/beads-dolt
cd ~/.local/share/beads-dolt
dolt init

# Create config.yaml in that directory (see Part 2 for full contents)
# Then install the systemd service (see Part 2) and start it:
systemctl --user daemon-reload
systemctl --user enable --now beads-dolt.service
ss -tlnp | grep 3307       # Confirm listening
```

### Step 3: Clean up any previous broken state (if re-initializing a project)

```bash
cd ~/your-project
bd admin reset --force      # Only if you had a previous broken setup
rm -rf .beads/              # Nuclear option: wipe and start clean (DESTROYS DATA)
# Do NOT kill port 3307 — that's the shared server, leave it running
```

### Step 4: Initialize the project

```bash
cd ~/your-project
bd init --quiet             # Non-interactive, installs hooks
bd dolt stop                # Stop the local server bd init auto-started
```

### Step 5: Create the project's database on the shared server and point metadata at it

```bash
# Pick a unique database name for this project
dolt sql -u root -h 127.0.0.1 -P 3307 -q "CREATE DATABASE IF NOT EXISTS myapp;"

# Edit .beads/metadata.json:
#   "dolt_mode": "server"
#   "dolt_server_host": "127.0.0.1"
#   "dolt_database": "myapp"    <-- must be unique per project
#   (remove dolt_server_port — it's deprecated, use .beads/dolt-server.port instead)

bd where --json             # Confirm active database
bd doctor --fix             # Run fix to backfill project_id and verify setup
```

### Step 6: Set git role

```bash
git config beads.role maintainer    # You have push access
# OR
git config beads.role contributor   # Fork/OSS contributor
git config --get beads.role         # Verify
```

### Step 7: Integrate with Gastown (if applicable)

```bash
# In your Gastown town directory:
gt rig add ~/your-project --prefix myapp
gt dolt fix-metadata --host 127.0.0.1 --port 3307   # Use the shared server
gt doctor

# Back in your project:
bd where --json             # Confirm shared server on 3307
bd doctor --gastown
```

### Step 8: Test a write

```bash
bd create "Test issue - delete me" -p 3
bd ready                     # Should show the new issue
bd close <id> --reason "Setup test"
bd vc commit -m "Setup test" # Commit the Dolt changes
```

### Step 9: Verify git hooks work

```bash
# Make a throwaway commit to test hooks
touch .beads/test-hook
git add .beads/test-hook
git commit -m "Test beads hooks"
# Should complete without lock errors or warnings
git reset HEAD~1 --soft    # Undo test commit
rm .beads/test-hook
```

### Step 10: Final verification

```bash
bd doctor                    # Should show all green (no errors)
bd doctor --fix              # Apply any remaining fixes
git pull --rebase && git push   # Sync with remote
```

---

## Quick reference

```bash
# Shared server (systemd — runs automatically after login)
systemctl --user status beads-dolt.service
journalctl --user -u beads-dolt -f        # Logs
ss -tlnp | grep 3307                      # Confirm listening
dolt sql -u root -h 127.0.0.1 -P 3307 -q "SHOW DATABASES;"  # All project DBs

# Diagnostics
bd doctor
bd doctor --server
bd doctor --fix
bd where --json
bd ready                     # Show open issues (quick status)
BD_DEBUG_RPC=1 bd list       # Debug connection issues

# Dolt version control
bd vc commit -m "message"    # Commit Dolt changes

# After cloning a repo with existing .beads/
bd init                       # Recreates Dolt DB
bd doctor --fix               # Backfill project_id, update hooks/gitignore
# Then edit metadata.json to point at shared server (remove dolt_server_port)

# Pre-0.56 database format fix
rm -rf .beads/dolt/.dolt/     # Delete old format, will auto-rebuild
bd doctor --fix

# Emergency reset
bd admin reset --force        # Reset local data (leaves shared server alone)
rm .beads/dolt/.dolt/lock     # Clear stale lock (verify with flock first)
gt dolt kill-imposters        # Kill any rogue server Gastown spawned

# Gastown
gt rig add ~/your-project --prefix myapp
gt dolt fix-metadata --host 127.0.0.1 --port 3307
gt dolt kill-imposters
gt doctor
```
