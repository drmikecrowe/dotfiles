# chezmoi templating

Templates let one source file produce different output per machine. A file is a template if
its source name ends in `.tmpl`, or it lives in `.chezmoitemplates/`, or the config-file
template `.chezmoi.<fmt>.tmpl`. chezmoi uses Go `text/template` plus
[sprig](https://masterminds.github.io/sprig/) functions plus chezmoi-specific functions.

## Make a file a template

```bash
chezmoi add --template ~/.zshrc      # add as template
chezmoi chattr +template ~/.zshrc    # convert existing managed file
# or edit the source name to end in .tmpl inside `chezmoi cd`
```

## Syntax basics

```text
{{ .chezmoi.hostname }}          {{/* substitute a variable */}}
{{ if eq .chezmoi.os "darwin" }} {{/* conditional */}}
# darwin
{{ else if eq .chezmoi.os "linux" }}
# linux
{{ else }}
# other
{{ end }}
```

Whitespace control: a leading `-` trims preceding whitespace, trailing `-` trims following.

```text
HOSTNAME={{- .chezmoi.hostname }}   →   HOSTNAME=myhost
```

Write a literal `{{`/`}}` with `{{ "{{" }}` / `{{ "}}" }}`, or a longer literal token
`{{ "{{ .Target }}" }}`.

## Built-in `.chezmoi.*` variables (most used)

| Variable | Value |
|---|---|
| `.chezmoi.os` | `darwin`, `linux`, `windows` (runtime.GOOS) |
| `.chezmoi.arch` | `amd64`, `arm64`, … (runtime.GOARCH) |
| `.chezmoi.hostname` | hostname up to first `.` |
| `.chezmoi.fqdnHostname` | fully-qualified hostname |
| `.chezmoi.osRelease` | parsed `/etc/os-release` (Linux); e.g. `.chezmoi.osRelease.id` |
| `.chezmoi.kernel.osrelease` | `/proc/sys/kernel/osrelease` — contains `microsoft` under WSL |
| `.chezmoi.homeDir` | home dir (forward slashes) |
| `.chezmoi.sourceDir` / `.sourceFile` / `.targetFile` | source dir / current template's source / its target |
| `.chezmoi.username` / `.uid` / `.gid` / `.group` | user identity |
| `.chezmoi.config` | the effective config |
| `.chezmoi.windowsVersion` | Windows build/edition info |

Run `chezmoi data` to dump the entire data dict (built-ins + your custom data). Custom
variables come from the `[data]` section of config, `.chezmoidata.<fmt>` files, and
`promptStringOnce`-style init prompts.

## Detecting WSL

```text
{{ if eq .chezmoi.os "linux" }}
{{   if (.chezmoi.kernel.osrelease | lower | contains "microsoft") }}
# WSL-specific
{{   end }}
{{ end }}
```

## Flattening nested OS/distro conditionals with a custom `osid`

In `.chezmoi.toml.tmpl` (or a `.chezmoidata`):

```text
{{- $osid := .chezmoi.os -}}
{{- if hasKey .chezmoi.osRelease "id" -}}
{{-   $osid = printf "%s-%s" .chezmoi.os .chezmoi.osRelease.id -}}
{{- end -}}
[data]
    osid = {{ $osid | quote }}
```

Then templates branch on `{{ if eq .osid "linux-debian" }}` etc.

## Per-machine config via prompts (init-time)

`.chezmoi.toml.tmpl` rendered once on `chezmoi init`:

```text
{{- $email := promptStringOnce . "email" "Email address" -}}
[data]
    email = {{ $email | quote }}
```

Prompt functions: `promptString[Once]`, `promptBool[Once]`, `promptInt[Once]`,
`promptChoice[Once]`, `promptMultichoice[Once]`. The `*Once` variants only prompt if the
value isn't already stored. Use `stdinIsATTY` to fall back to a default when non-interactive
(e.g. Codespaces):

```text
{{- $codespaces := env "CODESPACES" | not | not -}}
{{- if $codespaces }}
    email = "me@example.com"
{{- else }}
    email = {{ promptString "email" | quote }}
{{- end }}
```

## Useful functions

- `output "cmd" "arg"...` — run a command, capture stdout (often `| trim`). e.g.
  `{{ output "scutil" "--get" "ComputerName" | trim }}`. `outputList` takes a list of args.
- `include "file"` — inline the literal contents of a source file. Combine with `decrypt` for
  encrypted includes. Pair with `sha256sum` to trigger `run_onchange_` scripts.
- `lookPath "bin"` / `findExecutable` / `findOneExecutable` — conditionally enable config if
  a binary is (or will be) present.
- `stat` / `lstat` — branch on file existence/type.
- `joinPath`, `quote`, `toJson`/`fromJson`, `toToml`/`fromToml`, `toYaml`/`fromYaml`,
  `toIni`/`fromIni`, `jq`.
- `gitHubKeys "user"`, `gitHubLatestRelease`, `gitHubLatestReleaseAssetURL`,
  `gitHubLatestTag`, `gitHubReleaseAssetURL` — GitHub API helpers (cached), great with
  externals.

Example — populate `~/.ssh/authorized_keys` from GitHub:

```text
{{ range gitHubKeys "USERNAME" -}}
{{   .Key }}
{{ end -}}
```

## Reusable templates (`.chezmoitemplates/`)

Define `.chezmoitemplates/part.tmpl`, then in any template:

```text
{{ template "part.tmpl" . }}              {{/* pass the whole context */}}
{{ template "alacritty" .alacritty.small }}  {{/* pass specific data */}}
{{ template "alacritty" dict "fontsize" 12 "font" "DejaVu Sans Mono" }}
```

## Testing & debugging templates

```bash
chezmoi execute-template '{{ .chezmoi.os }}/{{ .chezmoi.arch }}'
chezmoi cd && chezmoi execute-template < dot_zshrc.tmpl
echo '{{ .chezmoi | toJson }}' | chezmoi execute-template
# simulate init prompts:
chezmoi execute-template --init --promptString email=me@home.org < .chezmoi.toml.tmpl
chezmoi cat ~/.zshrc          # show rendered target contents
```

## Missing-key behavior

Default is `missingkey=error`. Override per file with a directive
`{{/* chezmoi:template:missing-key=zero */}}` or globally via `template.options` in config.
