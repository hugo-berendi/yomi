# Proton Mail sorted on inari

Personal mail for `hugo-berendi.de` lives at Proton. Proton Mail Bridge on inari makes it available over IMAP. A worker on inari classifies new mail with `qwen3.5:9b` through a local Ollama and files it. n8n only triggers the worker. Service mail from `tengu.hugo-berendi.de` still goes out through Migadu. That is a separate account, and nothing here touches it.

The worker classifies only `INBOX` and `Archive`. It files mail into thirteen folders, which Bridge shows as `Folders/<name>`: Wichtig, Konzerte, Pfadfinder, Diabetes, Schule, Entwicklung, Rechnungen, Bestellungen, Werbung, Newsletter, Konten-Sicherheit, Termine, Sonstiges. There is no `KI-` prefix. Twitch live notifications from real Twitch domains skip the model and go to Werbung. Wichtig keeps its read flag. Every other message is marked read and then moved with native IMAP MOVE. There is no copy/delete fallback and no EXPUNGE.

Every ten minutes n8n starts one background job through an authenticated loopback endpoint. After sorting, the same job marks unread mail in the known category folders as read, without the model. It does this for the legacy `KI-…` folders too, and never for Wichtig, INBOX, Archive, unknown folders or subfolders. Each job handles up to 50 classifications and 1,000 read updates, and the next job continues with whatever is left. `markExistingRead = false` turns the second pass off. The manual workflow runs only that pass.

## Pieces

| File | Role |
|------|------|
| `hosts/nixos/inari/services/protonmail-bridge.nix` | Bridge as a system service, tailnet relay, sorter settings |
| `hosts/nixos/inari/services/protonmail-bridge/bridge-cert.pem` | Bridge's public certificate, pinned. Absent until the first login (see below) |
| `hosts/nixos/inari/services/proton-mail-sorter.nix` | Worker module and workflow registration |
| `hosts/nixos/inari/services/proton-mail-sorter/` | Worker, classifier, tests, and the sops file with the 1Password token |
| `hosts/nixos/inari/services/ollama.nix` | Ollama on loopback with only `qwen3.5:9b` |
| `hosts/nixos/inari/services/n8n/workflows/proton-*.json` | Scheduled and manual triggers |

The relay and the sorter turn on together when `bridge-cert.pem` exists. Before that, a switch starts only Bridge and Ollama.

## Secrets

The server uses a 1Password service account that can read only the **Automation** vault. Service accounts cannot reach Personal, so the Windows entry `Personal / Proton Mail Bridge` is not used. Its values belong to the Windows Bridge anyway. Automation holds:

1. `Proton Mail Bridge (inari)`, with fields `username` and `password`. These are the values Bridge on inari prints under `info`, not the Proton account password.
2. `Proton Mail Sorter`, with field `api-token`: a random string of at least 32 characters.

The service-account token is in `proton-mail-sorter/secrets.yaml`, encrypted with sops. systemd hands it to the worker through `LoadCredential`, and the worker passes it only into the environment of the `op read` child process. Read values are cached in memory for 15 minutes. No value goes into the Nix store, workflow JSON, a command line or n8n execution data.

## First deployment

1. **Switch**, done by a human. This starts Bridge and Ollama. `ollama-model-loader` pulls `qwen3.5:9b`, about 6.6 GB, onto the raid.
2. **Log Bridge in**: `sudo protonmail-bridge-setup`, then `login` (Proton password and 2FA), then `info`. Leave IMAP and SMTP security at STARTTLS. The pins rely on it.
3. **Put the Bridge credentials from `info`** and an API token into the Automation vault, as described above.
4. **Pin the certificate.** Read it from the local listener:

   ```sh
   openssl s_client -starttls imap -connect 127.0.0.1:1143 </dev/null 2>/dev/null \
     | openssl x509 -outform PEM > hosts/nixos/inari/services/protonmail-bridge/bridge-cert.pem
   openssl s_client -starttls smtp -connect 127.0.0.1:1025 </dev/null 2>/dev/null \
     | openssl x509 -noout -fingerprint -sha256
   openssl x509 -in hosts/nixos/inari/services/protonmail-bridge/bridge-cert.pem -noout -fingerprint -sha256
   ```

   Both fingerprints must match. Bridge uses one certificate for both listeners. Commit the PEM. stunnel and the worker both pin this file. A regenerated certificate then fails closed instead of being trusted on first use.
5. **Switch again.** This starts the stunnel relay, nginx on 993/465 with an ACME certificate for `mail.hugo-berendi.de`, and the worker in preview mode (`apply = false`). n8n imports both workflows, inactive.
6. **Attach the n8n credential.** Create an HTTP Header Auth credential with header `Authorization` and value `Bearer <api-token>`, and attach it to the **Start private job** node of both workflows. It stays in n8n's encrypted store.
7. **Run a preview.** Run the sorting workflow manually. HTTP 202 only means the job started. `journalctl -u proton-mail-sorter` shows the counters. The plan, with subjects, is in `/var/lib/private/proton-mail-sorter/plan-*.jsonl`. Keep it private.
8. **Go live after review.** Set `apply = true` in `protonmail-bridge.nix`, switch, and activate the scheduled workflow in n8n.
9. **Pull the credential ID back.** Use `just n8n-export` as described in `services/n8n/AGENTS.md` to bring the real credential ID into the JSON. Only then consider `enforce = true`.

Other devices use `mail.hugo-berendi.de`: IMAP on 993 and SMTP on 465, both SSL/TLS, with the inari Bridge credentials. The name resolves to inari's tailscale address, so it works only on the tailnet.

## What the worker guarantees

- It never takes destination names, endpoints, model names or `apply` from an HTTP body.
- Mail content goes only to the local Ollama.
- It checks UIDVALIDITY and a SHA256 of the message before every write. A missing or changed message is held and logged, never acted on through an old UID.
- An unusable model answer (not JSON, unknown category) holds only that message. The failure is cached for the day.
- An unreachable model, a login failure or a changed certificate stops the run before any change.
- A failed read flag stops that message's move.
- Changes that were already made stay applied and are logged in `actions-*.jsonl`. A restart during a job is reported as interrupted.

## Validation

The package was prepared on Windows (`tsukuyomi`) and checked on inari against the current tree:

- The patch applied cleanly.
- 17 Python tests pass against nixpkgs' `imap-tools` 1.13.0, and two workflow tests pass in a real Node `vm`.
- `system.build.proton-mail-sorter-tests` builds.
- `just lint` and `just nixos-rebuild dry-build inari` pass.
- The generated `stunnel.cfg`, the nginx stream block and the worker's derived pin were inspected with a throwaway certificate.

Not tested yet: the model against synthetic mail, a real IMAP login, and a real n8n import. All three need the first switch.
