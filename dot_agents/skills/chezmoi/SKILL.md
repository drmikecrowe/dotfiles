---
name: chezmoi
description: "Manage dotfiles across machines with chezmoi — install, add/edit/apply files, bootstrap new machines, and use templates, encryption, scripts, and externals. Use when the user mentions chezmoi, dotfiles, the source state (~/.local/share/chezmoi), dot_ files, .tmpl templates, .chezmoiignore/.chezmoidata/.chezmoiexternal, or wants to sync config across machines. Official docs: https://www.chezmoi.io"
---

# chezmoi

chezmoi manages a user's dotfiles across multiple diverse machines from a single git
repository. It stores the desired state of files (the **source state**) in
`~/.local/share/chezmoi` and applies it to the home directory (the **target/destination
state**).

## Mental model (read this first)

- **Source state** lives in `~/.local/share/chezmoi` (a git repo). chezmoi never edits
  your home dir directly — you edit the source, then `apply`.
- **Source filenames are encoded with attribute prefixes**, not literal names. `~/.bashrc`
  is stored as `dot_bashrc`; a template is `dot_zshrc.tmpl`; a private file is
  `private_dot_netrc`. Never hand-create these names — let `chezmoi add` / `chezmoi chattr`
  manage them.
- The normal loop is: **`add` → `edit` → `diff` → `apply`**. On other machines:
  **`init` → `update`**.
- Prefer chezmoi's own commands (`chezmoi cd`, `chezmoi edit`, `chezmoi git`) over poking at
  the source dir by hand, because they handle templates, encryption, and the name encoding.

## Source filename attributes

| Prefix / suffix | Meaning |
|---|---|
| `dot_` | Becomes a leading `.` (e.g. `dot_bashrc` → `.bashrc`) |
| `.tmpl` | File is a template (see `references/templating.md`) |
| `private_` | Removes group/world permissions |
| `readonly_` | Removes write permissions |
| `executable_` | Adds execute permission |
| `encrypted_` | File is encrypted at rest (see `references/encryption.md`) |
| `exact_` | Directory: remove anything not in source state |
| `create_` | Create only if absent; never overwrite/update |
| `run_` | Script, run on `apply` (see `references/scripts.md`) |
| `symlink_` | Target is a symlink whose contents are the link target |
| `literal_` | Stop attribute parsing (escape literal names) |

Set/change attributes on an existing entry with `chezmoi chattr`:

```bash
chezmoi chattr +template ~/.bashrc
chezmoi chattr private,template ~/.netrc
chezmoi chattr +create,+private ~/.kube/config
```

## Install

One-line install + bootstrap from a GitHub dotfiles repo (the canonical new-machine command):

```bash
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply $GITHUB_USERNAME
# private repo over SSH:
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply git@github.com:$GITHUB_USERNAME/dotfiles.git
# one-shot (install, apply, then delete chezmoi — for containers/throwaway env):
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --one-shot $GITHUB_USERNAME
# install to a chosen bin dir:
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
```

Package managers (binary identical; pick what the machine has):

```bash
brew install chezmoi          # macOS / Linuxbrew
pacman -S chezmoi             # Arch
dnf install chezmoi           # Fedora
apt install chezmoi           # Debian/Ubuntu (if packaged) — else use the curl installer
winget install twpayne.chezmoi  # Windows
mise use --global chezmoi@latest
```

PowerShell install:

```powershell
iex "&{$(irm 'https://get.chezmoi.io/ps1')}"
```

## Everyday workflow

```bash
chezmoi add ~/.bashrc          # start managing a file (copies into source state)
chezmoi add --template ~/.gitconfig   # add as a template
chezmoi add --encrypt ~/.ssh/id_rsa   # add encrypted
chezmoi add --recursive ~/.config/nvim
chezmoi edit ~/.bashrc         # edit the SOURCE of a file (handles tmpl/encryption)
chezmoi edit --apply ~/.bashrc # edit then apply on exit
chezmoi diff                   # preview what apply would change
chezmoi status                 # short status of changed targets
chezmoi apply -v               # make home dir match source state
chezmoi apply --dry-run -v     # see what would happen, change nothing
chezmoi re-add                 # pull edits made directly in home back into source (no templates)
chezmoi cd                     # subshell in the source dir
chezmoi managed                # list everything chezmoi manages
chezmoi unmanaged              # list files in home that are NOT managed
chezmoi forget ~/.bashrc       # stop managing (removes from source, keeps home file)
chezmoi doctor                 # diagnose configuration problems
```

### Editing the source repo directly + committing

```bash
chezmoi cd            # now inside ~/.local/share/chezmoi
git add . && git commit -m "..." && git push
exit
# or without spawning a shell:
chezmoi git -- add .
chezmoi git -- commit -m "Update dotfiles"
chezmoi git -- push
```

Auto-commit/push can be enabled in config (`git.autoCommit`, `git.autoPush`) — see
`references/configuration.md`.

## New / second machine

```bash
chezmoi init https://github.com/$USER/dotfiles.git   # clone source, no apply
chezmoi init --apply $USER                           # clone + apply in one step
chezmoi update                                       # git pull + apply (routine sync)
```

`chezmoi update` runs `git pull --autostash --rebase` then `apply`. Use it as the daily
"pull latest dotfiles" command.

## Configuration file

User config lives at `~/.config/chezmoi/chezmoi.{toml,yaml,json}`. Common options:

```toml
sourceDir = "/home/user/.dotfiles"
[git]
    autoCommit = true
    autoPush = true
[data]
    email = "me@example.com"   # available in templates as .email
```

Inspect with `chezmoi cat-config` (effective file) and `chezmoi dump-config`.
Generate a config from a template at init time with a `.chezmoi.toml.tmpl` in the source
root (prompts for values once). Full variable list: `references/configuration.md`.

## Special source files & directories

| Name | Purpose |
|---|---|
| `.chezmoiignore` | Targets to NOT manage; one glob per line; interpreted as a template |
| `.chezmoidata.<fmt>` | Static template data merged into the data dict (`.fontSize`, etc.) |
| `.chezmoitemplates/` | Reusable named templates included via `{{ template "name" . }}` |
| `.chezmoiexternal.<fmt>` | Pull in files/archives/git-repos from URLs (see `references/externals.md`) |
| `.chezmoiremove` | Targets to delete from the destination |
| `.chezmoiroot` | Use a subdirectory as the source root |
| `.chezmoiversion` | Minimum required chezmoi version |
| `.chezmoi.<fmt>.tmpl` | Config-file template, rendered on `init` |

`.chezmoiignore` example (it's a template — branch on the machine):

```
README.md
{{- if ne .chezmoi.hostname "work-laptop" }}
.work
{{- end }}
```

## Deep-dive references

Load these only when the task needs them:

- **`references/templating.md`** — Go templates, `.chezmoi.*` variables, conditionals,
  `chezmoi data` / `execute-template`, machine-to-machine differences, `.chezmoitemplates`.
- **`references/encryption.md`** — age (recommended) and GPG encryption, `--encrypt`,
  encrypting the private key, transparent (transcrypt) encryption.
- **`references/scripts.md`** — `run_`, `run_once_`, `run_onchange_`, `run_before_` /
  `run_after_` scripts; declarative package installation; clearing script state.
- **`references/externals.md`** — `.chezmoiexternal` types (file, archive, archive-file,
  git-repo), refresh periods, `import`, decompression filters.
- **`references/password-managers.md`** — template functions for 1Password, Bitwarden,
  pass, gopass, KeePassXC, LastPass, Vault, Doppler, Azure Key Vault, AWS, keyring.
- **`references/configuration.md`** — full config variable reference, hooks, diff/merge/edit
  tools, interpreters.

## Conventions when helping the user

- To change a managed file, edit the **source** (`chezmoi edit` or `chezmoi cd`), then
  `chezmoi diff` and `chezmoi apply`. Don't edit the home-dir file and expect it to persist —
  it'll be overwritten on next apply (or use `chezmoi re-add` to capture manual edits).
- Always offer `chezmoi diff` / `--dry-run` before a real `apply` on an unfamiliar setup.
- Never write encoded source filenames (`dot_`, `private_`, etc.) by hand — use `add`/`chattr`.
- Secrets go through templates + a password manager or encryption, never committed plaintext.
