# chezmoi externals & importing archives

`.chezmoiexternal.<fmt>` (TOML/YAML/JSON, may be a `.tmpl`) declares files, archives, or git
repos to pull from URLs into the target state — e.g. vim plugins, oh-my-zsh, prebuilt
binaries. Keys are target paths relative to home. The file is itself a template.

## External types

| `type` | Pulls |
|---|---|
| `file` | A single file from a URL |
| `archive` | An archive (tar/tar.gz/tgz/tbz2/txz/tar.zst/zip), extracted to the dir |
| `archive-file` | One named file extracted out of an archive |
| `git-repo` | A cloned git repository |

## Common fields

`url` / `urls` (fallbacks), `refreshPeriod` (e.g. `"168h"` — how often to re-fetch),
`exact` (treat dir as exact), `stripComponents` (drop leading path components),
`executable`, `private`, `readonly`, `format` (force archive format), `path` (file within
archive), `include`/`exclude` (glob filters), `decompress`, `filter.command`/`filter.args`
(pipe through a decompressor), `checksum.sha256|sha384|sha512|size`, `clone.args`,
`pull.args`.

## File external

```toml
[".vim/autoload/plug.vim"]
    type = "file"
    url = "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim"
    refreshPeriod = "168h"
```

## Archive externals (oh-my-zsh + plugins)

```toml
[".oh-my-zsh"]
    type = "archive"
    url = "https://github.com/ohmyzsh/ohmyzsh/archive/master.tar.gz"
    exact = true
    stripComponents = 1
    refreshPeriod = "168h"
[".oh-my-zsh/custom/plugins/zsh-syntax-highlighting"]
    type = "archive"
    url = "https://github.com/zsh-users/zsh-syntax-highlighting/archive/master.tar.gz"
    exact = true
    stripComponents = 1
    refreshPeriod = "168h"
```

Tagged releases don't need a `refreshPeriod` (immutable); moving branches like `master` do.

Filter to just the files you need:

```toml
[".oh-my-zsh/custom/plugins/zsh-syntax-highlighting"]
    type = "archive"
    url = "https://github.com/zsh-users/zsh-syntax-highlighting/archive/master.tar.gz"
    exact = true
    stripComponents = 1
    include = ["*/*.zsh", "*/highlighters/**"]
```

## archive-file — extract a single binary, with GitHub helpers

```toml
[".local/bin/zellij"]
    type = "archive-file"
    url = {{ gitHubLatestReleaseAssetURL "zellij-org/zellij" "zellij-x86_64-unknown-linux-musl.tar.gz" | quote }}
    executable = true
    path = "zellij"
```

Tip: inspect an archive's internal layout to set `path` correctly: `tar tzf file.tar.gz`.

Templated version pin:

```toml
{{ $ageVersion := "1.1.1" -}}
[".local/bin/age"]
    type = "archive-file"
    url = "https://github.com/FiloSottile/age/releases/download/v{{ $ageVersion }}/age-v{{ $ageVersion }}-{{ .chezmoi.os }}-{{ .chezmoi.arch }}.tar.gz"
    path = "age/age"
```

## git-repo external

```toml
[".config/nvim"]
    type = "git-repo"
    url = "https://github.com/NvChad/NvChad.git"
    refreshPeriod = "168h"
    [".config/nvim.pull"]
        args = ["--ff-only"]
```

Private repo (guard on SSH key presence so it's skipped where the key is absent):

```toml
{{ if stat (joinPath .chezmoi.homeDir ".ssh" "id_rsa") }}
[".path/to/private/repo"]
    type = "git-repo"
    url = "git@private.com:org/repo.git"
{{ end }}
```

## Unsupported compression — pipe through a filter

```toml
[".Software/anki/2.1.54-qt6"]
    type = "archive"
    url = "https://github.com/ankitects/anki/releases/download/2.1.54/anki-2.1.54-linux-qt6.tar.zst"
    filter.command = "zstd"
    filter.args = ["-d"]
    format = "tar"
```

## Applying & refreshing

```bash
chezmoi apply                          # uses cached externals within refreshPeriod
chezmoi --refresh-externals apply      # force re-fetch (also: -R)
```

## One-off import of an archive into the SOURCE state

Different from externals: `import` copies an archive's contents into your source state so you
manage them as normal files.

```bash
curl -s -L -o ${TMPDIR}/omz.tar.gz https://github.com/ohmyzsh/ohmyzsh/archive/master.tar.gz
mkdir -p $(chezmoi source-path)/dot_oh-my-zsh
chezmoi import --strip-components 1 --destination ~/.oh-my-zsh ${TMPDIR}/omz.tar.gz
```
