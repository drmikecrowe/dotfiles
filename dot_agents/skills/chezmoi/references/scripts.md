# chezmoi scripts

Scripts let chezmoi perform actions (install packages, run setup) during `apply`. A source
file named with a `run_` prefix is a script. Scripts can be templates (`.tmpl`) and are
executed in alphabetical order within their phase.

## Run variants

| Prefix | When it runs |
|---|---|
| `run_` | Every `apply` |
| `run_once_` | Once per unique content hash (state-tracked) — idempotent setup |
| `run_onchange_` | Whenever the script's (rendered) contents change |
| `run_before_` | Before any files are updated (combine: `run_before_`, `run_once_before_`, …) |
| `run_after_` | After files are updated |

Ordering: `run_before_` scripts → file updates → `run_after_` scripts; within each, alpha
order by source name. `run_once_`/`run_onchange_` state is keyed on content, so changing the
file (or the data it embeds) re-triggers it.

## Basic package-install script

`run_onchange_install-packages.sh`:

```shell
#!/bin/sh
sudo apt install ripgrep
```

Cross-platform via template:

```shell
{{ if eq .chezmoi.os "linux" -}}
#!/bin/sh
sudo apt install ripgrep
{{ else if eq .chezmoi.os "darwin" -}}
#!/bin/sh
brew install ripgrep
{{ end -}}
```

> Template-script gotcha: when the OS guard is false you want an empty file, and you must not
> emit a blank line before the shebang. Trim it: `{{ if eq .chezmoi.os "linux" -}}` then
> `#!/bin/sh` on the next line.

## Declarative packages (data-driven, re-runs on change)

Define packages in `.chezmoidata.yaml`:

```yaml
packages:
  darwin:
    brews: ['git']
    casks: ['google-chrome']
```

`run_onchange_install-packages.sh.tmpl` — because the rendered package list is embedded, the
script re-runs only when the list changes:

```bash
{{ if eq .chezmoi.os "darwin" -}}
#!/bin/bash
brew bundle --file=/dev/stdin <<EOF
{{ range .packages.darwin.brews -}}
brew {{ . | quote }}
{{ end -}}
{{ range .packages.darwin.casks -}}
cask {{ . | quote }}
{{ end -}}
EOF
{{ end -}}
```

## Force re-run on an external file's change

Embed a hash of a tracked file in a comment so `run_onchange_` notices edits:

```bash
#!/bin/bash
# dconf.ini hash: {{ include "dconf.ini" | sha256sum }}
dconf load / < {{ joinPath .chezmoi.sourceDir "dconf.ini" | quote }}
```

## Periodic scripts (daily / weekly)

Embed a changing date so the hash changes on schedule:

```text
#!/bin/sh
# {{ now | date "2006-01-02" }}     # changes daily
echo "new day"
```

```text
#!/bin/sh
# {{ output "date" "+%V" | trim }}  # changes weekly (ISO week)
echo "new week"
```

## Install a password manager before reading source state (hook)

A `read-source-state` pre-hook runs a script before templates are evaluated — useful so the
password-manager CLI exists before any secret template runs.

```toml
[hooks.read-source-state.pre]
    command = ".local/share/chezmoi/.install-password-manager.sh"
```

Idempotent installer skeleton:

```sh
#!/bin/sh
type password-manager-binary >/dev/null 2>&1 && exit
case "$(uname -s)" in
Darwin) : ;;  # install commands
Linux)  : ;;
*) echo "unsupported OS"; exit 1 ;;
esac
```

## Environment, temp dir, shebang notes

- Custom env for scripts: `[scriptEnv]` in config (`MY_VAR = "value"`).
- If `/tmp` is mounted `noexec`, set `scriptTempDir = "~/tmp"`.
- Avoid hardcoded shebangs that may not exist everywhere. Prefer `#!/usr/bin/env bash`, or on
  Nix/Termux use `#!{{ lookPath "bash" }}`.

## Reset script state (force re-run)

```bash
chezmoi state delete-bucket --bucket=scriptState   # run_once_ scripts
chezmoi state delete-bucket --bucket=entryState    # run_onchange_ scripts
chezmoi state dump                                 # inspect persistent state
```
