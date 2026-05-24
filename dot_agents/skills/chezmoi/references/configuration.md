# chezmoi configuration, tools & hooks

Config file: `~/.config/chezmoi/chezmoi.{toml,yaml,json,jsonc}`. Inspect with
`chezmoi cat-config` (effective file) / `chezmoi dump-config` (resolved values). Generate it
at init from `.chezmoi.<fmt>.tmpl` in the source root (see `templating.md`).

```toml
sourceDir = "/home/user/.dotfiles"
[git]
    autoPush = true
```

## Top-level variables (selected)

`sourceDir`, `destDir`, `cacheDir`, `tempDir`, `encryption` (`age`|`gpg`|`transparent`),
`format` (`json`|`yaml`), `mode` (`file`|`symlink`), `umask`, `pager`/`pagerArgs`,
`progress`, `verbose`, `color`, `interactive`, `useBuiltinAge`, `useBuiltinGit`,
`scriptTempDir`, `workingTree`. Arbitrary template data goes under `[data]`; extra process
env under `[env]`; script env under `[scriptEnv]`.

## git integration

```toml
[git]
    autoAdd = false       # stage changes after any change
    autoCommit = false    # commit after any change
    autoPush = false      # push after any change
    command = "git"
    commitMessageTemplate = "{{ promptString \"Commit message\" }}"
    commitMessageTemplateFile = ".commit_message.tmpl"
    lfs = false
```

`autoCommit` implies add; `autoPush` implies commit. Non-git VCS (e.g. Fossil): set
`[update] command/args` and add an empty `~/.local/share/chezmoi/.git` dir so chezmoi
recognizes the work tree.

## Diff / merge / edit tools

```toml
[diff]
    command = "code"            # or "meld", "delta" (pager), "difft"...
    args = ["--wait", "--diff"]
    pager = "delta"             # diff-so-fancy / delta / less -R
    exclude = ["scripts"]       # hide entry types from diff
```

```toml
[merge]
    command = "nvim"
    args = ["-d", "{{ .Destination }}", "{{ .Source }}", "{{ .Target }}"]
```

```toml
[edit]
    command = "code"
    args = ["--wait"]
    apply = false               # apply on editor exit
    watch = false               # apply on every save
    hardlink = true             # set false for editor autocmd-on-save setups
```

Template vars available to diff/merge: `.Destination`, `.Source`, `.Target`. When the config
is itself a template, escape literal braces: `{{ printf "%q" "{{ .Destination }}" }}`.

`textconv` transforms content before diffing (e.g. binary plists):

```toml
[[textconv]]
    pattern = "**/*.plist"
    command = "plutil"
    args = ["-convert", "xml1", "-o", "-", "-"]
```

## Hooks

Run commands/scripts around any command, pre/post:

```toml
[hooks.apply.post]
    command = "echo"
    args = ["post-apply-hook"]

[hooks.read-source-state.pre]
    command = ".local/share/chezmoi/.install-password-manager.sh"

[hooks.add.post]
    script = "post-add-hook.ps1"     # `script` runs via the configured interpreter
```

## Interpreters (run scripts by extension on Windows etc.)

```toml
[interpreters.py]
    command = 'C:\Python39\python3.exe'
[interpreters.ps1]
    command = "powershell"
    args = ["-NoLogo"]
```

## Entry-type filters (used by many commands)

`--include` / `--exclude` accept comma lists; prefix with `no` to subtract:
`all`, `none`, `dirs`, `files`, `remove`, `scripts`, `symlinks`, `always`, `encrypted`,
`externals`, `templates`. e.g. `chezmoi apply --exclude=scripts`,
`chezmoi managed --include=files,symlinks`, `chezmoi diff --exclude=encrypted`.

## Path styles

`--path-style absolute|relative|source-absolute|source-relative|all` and `--tree` change how
`managed`/`unmanaged`/`source-path` print paths.

## Command quick reference

```bash
chezmoi init [repo] [--apply] [--purge]   # clone/create source
chezmoi update                            # git pull + apply
chezmoi add / re-add / forget / chattr    # manage source entries
chezmoi edit [--apply|--watch]            # edit source
chezmoi apply [--dry-run] [-v] [target]   # sync home to source
chezmoi diff / status / verify            # inspect pending changes
chezmoi managed / unmanaged / ignored     # listings
chezmoi cat <target>                      # rendered target contents
chezmoi cd / git -- ...                   # work in source repo
chezmoi data / execute-template / cat-config / dump-config
chezmoi source-path / target-path [path]  # map between source<->target
chezmoi merge[-all] <target>              # 3-way merge
chezmoi archive [--output=f.tar.gz]       # tar of target state
chezmoi import --destination=... f.tar.gz # import archive into source
chezmoi state ...                         # persistent state (script re-runs)
chezmoi doctor                            # diagnostics
chezmoi purge [--force]                   # remove chezmoi config/state/source
chezmoi generate install.sh               # emit a bootstrap installer
chezmoi completion <shell>                # shell completions
```

## Snap redirection gotcha

Under the snap package, shell redirection of stdin/stdout may fail due to confinement. Use
`cat f | chezmoi cmd` instead of `chezmoi cmd <f`, and `chezmoi cmd -o f` / `--output=f`
instead of `chezmoi cmd >f`.
