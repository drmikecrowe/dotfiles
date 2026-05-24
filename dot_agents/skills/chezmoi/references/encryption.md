# chezmoi encryption

chezmoi can encrypt files at rest in the source repo so secrets can be committed safely.
Files marked `encrypted_` in the source state are stored as ciphertext and decrypted on
`apply`. **age** is recommended over GPG (simpler, modern). There's also a "transparent"
mode delegating to git's clean/smudge filters (transcrypt).

Add any file encrypted:

```bash
chezmoi add --encrypt ~/.ssh/id_rsa
```

## age (recommended)

Generate a key, then configure recipient + identity:

```bash
chezmoi age-keygen --output=$HOME/key.txt
# prints: Public key: age1ql3z7hjy54pw3hyww5...
```

```toml
encryption = "age"
[age]
    identity = "/home/user/key.txt"
    recipient = "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"
```

Multiple identities/recipients:

```toml
encryption = "age"
[age]
    identities = ["/home/user/key1.txt", "/home/user/key2.txt"]
    recipients = ["recipient1", "recipient2"]
```

Symmetric (passphrase, no key file):

```toml
encryption = "age"
[age]
    passphrase = true
```

`rage` (Rust age impl) as the backend:

```toml
encryption = "age"
[age]
    command = "rage"
```

Ad-hoc encrypt/decrypt with the builtin:

```bash
chezmoi age encrypt --passphrase plaintext.txt > ciphertext.txt
chezmoi age decrypt --passphrase ciphertext.txt > out.txt
```

### Bootstrapping the age key on a new machine

You can't decrypt until the private key is present, so encrypt the key itself with a
passphrase, commit it, and decrypt it in a `run_onchange_before_` script.

```bash
chezmoi cd
chezmoi age-keygen | chezmoi age encrypt --passphrase --output=key.txt.age
echo key.txt.age >> .chezmoiignore   # don't manage the encrypted key as a target
```

`run_onchange_before_decrypt-private-key.sh.tmpl`:

```bash
#!/bin/sh
if [ ! -f "${HOME}/.config/chezmoi/key.txt" ]; then
    mkdir -p "${HOME}/.config/chezmoi"
    chezmoi age decrypt --output "${HOME}/.config/chezmoi/key.txt" \
        --passphrase "{{ .chezmoi.sourceDir }}/key.txt.age"
    chmod 600 "${HOME}/.config/chezmoi/key.txt"
fi
```

## GPG

Asymmetric (recipient key):

```toml
encryption = "gpg"
[gpg]
    recipient = "..."
```

Symmetric:

```toml
encryption = "gpg"
[gpg]
    symmetric = true
```

Passphrase via init prompt + symmetric args:

```toml
{{ $passphrase := promptStringOnce . "passphrase" "passphrase" -}}
encryption = "gpg"
[data]
    passphrase = {{ $passphrase | quote }}
[gpg]
    symmetric = true
    args = ["--batch", "--passphrase", {{ $passphrase | quote }}, "--no-symkey-cache"]
```

Silence GPG stderr noise with `args = ["--quiet"]`.

## Transparent / transcrypt

Set `encryption = "transparent"` and use git filters. Files named `encrypted_*` get
`filter=crypt diff=crypt merge=crypt` in `.gitattributes`. Init transcrypt inside the source
dir:

```bash
chezmoi cd
transcrypt -c aes-256-cbc -p $PASSWORD
git ls-crypt    # list files transcrypt manages
```

## Re-encrypting everything (e.g. migrating GPG → age)

```bash
for f in $(chezmoi managed --include encrypted --path-style absolute); do
  chezmoi forget "$f"
  chezmoi add --encrypt "${f%.asc}"
done
```

## Decrypt inside a template

```text
{{ joinPath .chezmoi.sourceDir ".ignored-encrypted-file.age" | include | decrypt }}
```
