# Prompt for the agent on Amaterasu

Help verify an independent recovery identity for Inari before its SSD is returned.

Run hostname first and follow the local AGENTS.md. Do not print, upload, or commit
private keys, passwords, decrypted secrets, or decrypted SOPS documents.

Inari's current Age recipients are:

- Pilot: `age1aew0wld84lhcdte90ra0a4xhkwd2tlaanyr94xeffufpl3rls55qclcsfv`
- Shared host: `age1x9dhumaa3qg77z9swunz3zl5r6ez6gqyhwd66ytp20ndzjefdvcsq6yfu8`

Check whether Amaterasu has:

1. `~/.config/sops/age/keys.txt` matching either recipient.
2. The older `~/.ssh/id_ed25519` private key. A public-key file alone is insufficient.
3. A persistent SSH host private key matching the shared-host recipient. Locate it
   from the evaluated SOPS configuration; use sudo through my terminal if needed.

Report only existence, permissions, public recipients/fingerprints and test
success/failure. The new YubiKey `sk-ssh-ed25519` login key does not by itself
establish Age decryption.

Using a matching private identity, prove decryption of both
`hosts/nixos/common/secrets.yaml` and `hosts/nixos/inari/secrets.yaml`, discarding
plaintext output. Never place passwords in command arguments or chat. Ask me to
enter any necessary passphrase locally.

If no usable identity exists, help establish an independent recovery identity
and arrange encrypted preservation from Inari before erasure. Do not rotate
existing keys or overwrite YubiKey slots.

Also report Amaterasu's actual SSH host ED25519 public-key fingerprint from
`/etc/ssh/ssh_host_ed25519_key.pub` so it can be independently verified on Inari.

Nothing destructive is authorized. Return a concise report of what was actually
tested and what remains blocked.
