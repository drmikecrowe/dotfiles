# Yazi Keybindings Reference

## Navigation

| Key | Action | Description |
|-----|--------|-------------|
| `l` | smart-enter | Enter directory or open file in one key |
| `h` | back | Go to parent directory |
| `j` | down | Move down |
| `k` | up | Move up |
| `gg` | top | Go to top of list |
| `G` | bottom | Go to bottom of list |
| `/h` | hidden toggle | Show/hide hidden files |

## Tabs

| Key | Action | Description |
|-----|--------|-------------|
| `t` | smart-tab | Create new tab and enter hovered directory |
| `2` | smart-switch | Switch to or create tab 2 |
| `1-9` | tab-switch | Switch to tab 1-9 |
| `[` | tab-prev | Previous tab |
| `]` | tab-next | Next tab |

## File Operations

| Key | Action | Description |
|-----|--------|-------------|
| `y` | yank | Copy (yank) selected files |
| `x` | cut | Cut selected files |
| `p` | smart-paste | Paste into hovered directory or CWD |
| `d` | remove | Trash selected files |
| `D` | delete | Permanently delete selected files |
| `a` | create | Create new file/directory |
| `r` | rename | Rename file |
| `C` | ouch compress | Compress selection to 7z archive |

## Pane Management

| Key | Action | Description |
|-----|--------|-------------|
| `T` | toggle-pane min-preview | Toggle preview pane (hide/show) |
| `vpm` | toggle-pane max-preview | Maximize preview pane |
| `vpp` | toggle-pane min-parent | Toggle parent pane |
| `vpc` | toggle-pane min-current | Toggle current pane |
| `vpr` | toggle-pane reset | Reset all panes to default |

## Archive Operations

| Key | Action | Description |
|-----|--------|-------------|
| `ma` | archivemount mount | Mount selected archive as virtual filesystem |
| `mu` | archivemount unmount | Unmount archive and save changes |

**Supported archive formats:** zip, tar, bz2, 7z, rar, xz

## Recycle Bin (trash-cli)

| Key | Action | Description |
|-----|--------|-------------|
| `R` | recycle-bin menu | Open interactive recycle bin menu |

The menu provides options to:
- `o` - Open trash directory
- `r` - Restore from trash
- `d` - Delete from trash permanently
- `e` - Empty entire trash
- `D` - Empty files older than X days

**Requires:** `trash-cli` installed (`sudo pacman -S trash-cli`)

## Directory Preview (eza-preview)

When hovering over a directory, these keys control the preview:

| Key | Action | Description |
|-----|--------|-------------|
| `et` | eza-preview | Toggle tree/list view |
| `e+` | inc-level | Increase tree depth |
| `e-` | dec-level | Decrease tree depth |
| `es` | toggle-follow-symlinks | Follow symlinks on/off |
| `eh` | toggle-hidden | Show/hide hidden files |
| `ei` | toggle-git-ignore | Respect gitignore on/off |
| `eg` | toggle-git-status | Show git status on/off |

**Requires:** `eza` installed (`sudo pacman -S eza`)

## File Size

| Key | Action | Description |
|-----|--------|-------------|
| `/s` | what-size | Calculate size of selection or CWD |
| `/c` | what-size --clipboard | Copy size to clipboard |

## Git

| Key | Action | Description |
|-----|--------|-------------|
| `gi` | lazygit | Open lazygit TUI |

**Requires:** `lazygit` installed (`sudo pacman -S lazygit`)

## Shell

| Key | Action | Description |
|-----|--------|-------------|
| `!` | shell | Open interactive shell in CWD |
| `;` | shell | Run shell command |
| `:` | command | Run Yazi command |

## Preview Scrolling (Alt keys)

| Key | Action | Description |
|-----|--------|-------------|
| `Alt+Up` | seek -1 | Scroll preview up 1 line |
| `Alt+Down` | seek +1 | Scroll preview down 1 line |
| `Alt+PgUp` | seek -15 | Scroll preview up 1 page |
| `Alt+PgDn` | seek +15 | Scroll preview down 1 page |
| `Alt+Home` | seek -10000 | Scroll preview to top |
| `Alt+End` | seek +10000 | Scroll preview to bottom |

## Selection

| Key | Action | Description |
|-----|--------|-------------|
| `Space` | select | Toggle selection on hovered file |
| `v` | visual-mode | Enter visual (selection) mode |
| `V` | select-all | Select all files |
| `Esc` | escape | Clear selection / cancel |

## Search & Filter

| Key | Action | Description |
|-----|--------|-------------|
| `f` | filter | Filter files by pattern |
| `/` | find | Find files |
| `s` | search | Search files by name |

## Copy Paths

| Key | Action | Description |
|-----|--------|-------------|
| `yc` | copy path | Copy file path |
| `yd` | copy dirname | Copy directory path |
| `yn` | copy filename | Copy filename without path |

## Goto

| Key | Action | Description |
|-----|--------|-------------|
| `gh` | cd ~ | Go to home directory |
| `gc` | cd ~/.config | Go to config directory |
| `gd` | cd ~/Downloads | Go to downloads |
| `g/` | cd / | Go to root |
| `ge` | cd /etc | Go to /etc |

## Header Display

The filesystem usage is displayed in the header showing:
- Partition name
- Usage percentage with a visual bar
- Warning color when usage exceeds 90%

---

## Installed Plugins

| Plugin | Purpose |
|--------|---------|
| `smart-enter` | Enter dirs or open files with one key |
| `smart-paste` | Paste into hovered directory |
| `smart-tab` | Create tab and enter directory |
| `smart-switch` | Switch or create tabs |
| `toggle-pane` | Show/hide/maximize panes |
| `eza-preview` | Directory preview with eza |
| `ouch` | Archive preview and compression |
| `rich-preview` | Preview md/json/csv/ipynb/rst files |
| `archivemount` | Mount archives as filesystems |
| `recycle-bin` | Trash management with restore |
| `fs-usage` | Disk usage in header |
| `what-size` | Calculate file/folder sizes |
| `hexyl` | Hex previewer for binary files |
| `piper` | Pipe commands as previewer |
| `lazygit` | Git TUI integration |

## External Dependencies

Some plugins require external tools:

```bash
# Essential
sudo pacman -S eza          # Directory preview
sudo pacman -S trash-cli    # Recycle bin
sudo pacman -S ouch         # Archive handling

# Optional but recommended
sudo pacman -S lazygit      # Git TUI
sudo pacman -S hexyl        # Hex previewer
sudo pacman -S rich-cli     # Rich text preview (via pip)
```

## Notes

- **Overlapping plugins NOT installed:**
  - `compress.yazi` - Skipped (ouch.yazi already handles compression)
  - `ucp.yazi` - Skipped (smart-paste.yazi already handles paste operations)

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│  NAVIGATION        │  FILE OPS        │  SPECIAL           │
│  ──────────        │  ────────        │  ──────            │
│  l = enter/open    │  y = yank        │  R = recycle menu  │
│  h = back          │  x = cut         │  C = compress      │
│  j/k = down/up     │  p = paste       │  T = toggle prev   │
│  /h = hidden       │  d = trash       │  ! = shell         │
│                    │  r = rename      │  gi = lazygit      │
│  TABS              │  a = create      │                    │
│  ────              │                  │  PREVIEW SCROLL    │
│  t = new tab       │  ARCHIVES        │  ──────────────    │
│  1-9 = go tab      │  ────────        │  Alt+↑↓ = scroll   │
│  [/ ] = prev/next  │  ma = mount      │  Alt+PgUp/Dn = pg  │
│                    │  mu = unmount    │                    │
└─────────────────────────────────────────────────────────────┘
```
