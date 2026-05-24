# chezmoi secrets & password managers

Keep secrets out of the repo by fetching them at `apply` time from a password manager via
template functions, or by encrypting (see `encryption.md`). Each integration shells out to
the manager's CLI, which must be installed and authenticated. Outputs are cached per
arguments within a run.

Generic fallback (any CLI): `secret`/`secretJSON` use the `secret.command` config.

```text
{{ secret "show" "$ID" }}                    # raw string
{{ secretJSON "kv" "get" "-format=json" "$ID" }}   # parsed JSON (HashiCorp Vault example)
```

## 1Password (`op`)

```bash
op account add --address $SUBDOMAIN.1password.com --email $EMAIL
eval $(op signin --account $SUBDOMAIN)
```

```text
{{ onepasswordRead "op://vault/item/field" }}            {{/* simplest */}}
{{ (onepasswordDetailsFields "$UUID").password.value }}  {{/* by field name */}}
{{ (onepasswordItemFields "$UUID").exampleLabel.value }}
{{- onepasswordDocument "$UUID" -}}                      {{/* whole document */}}
```

Modes (config `[onepassword] mode`): `account` (default), `connect` (env `OP_CONNECT_HOST`,
`OP_CONNECT_TOKEN`), `service` (env `OP_SERVICE_ACCOUNT_TOKEN`). Set `prompt = false` to
disable interactive sign-in. Debug: `chezmoi execute-template "{{ onepasswordItemFields \"$UUID\" | toJson }}" | jq .`

## Bitwarden (`bw`) / rbw / Bitwarden Secrets

```bash
export BW_SESSION="$(bw unlock --raw)"   # or: bw login $EMAIL --raw
```

```text
{{ (bitwarden "item" "example.com").login.password }}
{{ (bitwardenFields "item" "example.com").token.value }}      {{/* custom field */}}
{{ bitwardenAttachment "id_rsa" "$ITEMID" }}
{{ bitwardenAttachmentByRef "id_rsa" "item" "example.com" }}
{{ (rbw "test-entry").data.password }}                        {{/* unofficial rbw CLI */}}
{{ (bitwardenSecrets "$SECRET_ID" .accessToken).value }}      {{/* Bitwarden Secrets Manager */}}
```

## pass / gopass / passhole

```text
{{ pass "$PASS_NAME" }}            {{ (passFields "GitHub").password }}
{{ gopass "$PASS_NAME" }}          {{ gopassRaw "path/to/secret" }}
{{ passhole "example.com" "password" }}
```

## KeePassXC (`keepassxc-cli`)

Config: `[keepassxc] database = "/path/Passwords.kdbx"` (plus `args`, `mode`, `prompt`).

```text
{{ (keepassxc "example.com").Password }}
{{ keepassxcAttribute "SSH Key" "private-key" }}
{{- keepassxcAttachment "SSH Config" "config" -}}   {{/* needs cli >= 2.7.0 */}}
```

## LastPass (`lpass`)

```bash
lpass login $LASTPASS_USERNAME
```

```text
{{ (index (lastpass "GitHub") 0).password | quote }}
{{ (index (lastpass "SSH") 0).note.privateKey }}   {{/* note parsed as key:value */}}
```

## HashiCorp Vault

```text
{{ (vault "$KEY").data.data.password }}
```

## Doppler

```bash
doppler login
```

```text
{{ doppler "SECRET_NAME" "project" "config" }}
{{ (dopplerProjectJson "project" "config").PASSWORD }}
```

Defaults via `[doppler] project = "..."  config = "..."`.

## Cloud / OS keystores

- **Azure Key Vault**: `{{ azureKeyVault "secret-name" }}` (or `... "vault-name"`); set
  `[azureKeyVault] defaultVault`.
- **AWS Secrets Manager**: `{{ (awsSecretsManager "name").username }}` /
  `{{ awsSecretsManagerRaw "name" }}`; `[awsSecretsManager] profile`, `region`.
- **OS keyring** (macOS Keychain / GNOME Keyring / Windows Cred Mgr):

```bash
chezmoi secret keyring set --service=github --user=$USER --value=...
chezmoi secret keyring get --service=github --user=$USER
```

```text
token = {{ keyring "github" .github.user | quote }}
```

(FreeBSD: `keyring` only works if chezmoi was built with cgo — official binaries are not.)

## Patterns

- Combine `promptStringOnce` for non-secret per-machine values; password-manager funcs for
  secrets. Don't store secrets in `[data]` (that lands in the config file).
- Install the manager's CLI before secret templates run via a `read-source-state` pre-hook
  (see `scripts.md`).
- Test a function in isolation: `chezmoi execute-template '{{ pass "x" }}'`.
