# Proton Mail sorted on inari

Personal mail for `hugo-berendi.de` lives at Proton. Proton Mail Bridge on inari makes it available over IMAP. A worker on inari classifies new mail with Qwen3.5-9B on the local llama.cpp server and files it. n8n only triggers the worker. Service mail from `tengu.hugo-berendi.de` still goes out through Migadu. That is a separate account, and nothing here touches it.

The worker classifies only `INBOX` and `Archive`, plus whatever is left in the retired `Folders/Wichtig` and `Folders/KI-Wichtig`. It files mail into twelve folders, which Bridge shows as `Folders/<name>`: Konzerte, Pfadfinder, Diabetes, Schule, Entwicklung, Rechnungen, Bestellungen, Werbung, Newsletter, Konten-Sicherheit, Termine, Sonstiges. There is no `KI-` prefix. Twitch live notifications from real Twitch domains skip the model and go to Werbung. Every message is marked read and then moved with native IMAP MOVE, except mail labelled Action, which keeps its read state. There is no copy/delete fallback and no EXPUNGE.

## Folder upkeep

Each sorting job takes the retired `Folders/Wichtig` and `Folders/KI-Wichtig` first, so their mail gets its Action label before the INBOX and Archive backlog uses up the job's budget. It then tidies up, without the model:

- **Merge:** the Windows sorter's `Folders/KI-<category>` are moved into `Folders/<category>`, up to `maxReadMessages` per job.
- **Delete:** every folder under `Folders/` that is not one of the twelve categories, has no subfolders and is empty at that moment is deleted. That covers emptied imports, the retired Wichtig folders and merged `KI-` folders. Labels are never touched. Names in `keepFolders` (without the `Folders/` prefix) are kept even when empty.

The job's status in the journal lists how many messages came from each folder, and which folders were merged or deleted. It logs folder names only.

## Labels

A message sits in one folder but can carry several labels. The labels answer what cuts across folders. Bridge shows them as `Labels/<name>`, and the worker sets one with an IMAP COPY there, before the move.

| Label | Meaning | Set by |
|---|---|---|
| `Action` | You have to do something, with a real deadline or consequence. Replaces the old Wichtig folder, so an urgent prescription stays in Diabetes. | The model, in the same call as the folder |
| `Steuer <year>` | A document worth keeping for a German income tax return: payslips, Lohnsteuerbescheinigung, work equipment, training and travel costs, health co-payments, insurance, donation receipts, Finanzamt mail. | The model; the year comes from the mail's `Date` header |
| `Alias` | Arrived through a SimpleLogin alias | `X-SimpleLogin-*` headers or a `@yokai.hugo-berendi.de` recipient, no model |

Rules in code override the model: no Action on Werbung, Newsletter or Konten-Sicherheit (mostly one-time codes, expired by the time a job files them), or on mail older than 30 days; no Steuer on Werbung, Newsletter or Konten-Sicherheit.

Mail already in the category folders is labelled too, once each. That pass only runs in a job that found nothing new to sort, up to 50 messages per job (`maxLabelMessages`). Werbung, Newsletter and Konten-Sicherheit are labelled without the model. `labelExisting = false` turns it off.

Every ten minutes n8n starts one background job through an authenticated loopback endpoint. After sorting, the same job marks unread mail in the known category folders as read, without the model. It does this for the legacy `KI-…` folders too, and never for INBOX, Archive, unknown folders, subfolders, or mail labelled Action. Each job handles up to 50 classifications and 1,000 read updates, and the next job continues with whatever is left. `markExistingRead = false` turns the second pass off. The manual workflow runs only that pass.

## Pieces

| File | Role |
|------|------|
| `hosts/nixos/inari/services/protonmail-bridge/default.nix` | Bridge as a system service, tailnet relay, sorter settings |
| `hosts/nixos/inari/services/protonmail-bridge/bridge-cert.pem` | Bridge's public certificate, pinned. Absent until the first login (see below) |
| `hosts/nixos/inari/services/proton-mail-sorter/default.nix` | Worker module and workflow registration |
| `hosts/nixos/inari/services/proton-mail-sorter/` | Worker, classifier, tests, and the sops file with the 1Password token |
| `hosts/nixos/inari/services/llama-cpp/classifier.nix` | llama.cpp on loopback serving Qwen3.5-9B, thinking off |
| `hosts/nixos/inari/services/n8n/workflows/proton-*.json` | Scheduled and manual triggers |

The relay and the sorter turn on together when `bridge-cert.pem` exists. Before that, a switch starts only Bridge.

## Secrets

The server uses a 1Password service account that can read only the **Automation** vault. Service accounts cannot reach Personal, so the Windows entry `Personal / Proton Mail Bridge` is not used. Its values belong to the Windows Bridge anyway. Automation holds:

1. `Proton Mail Bridge (inari)`, with fields `username` and `password`. These are the values Bridge on inari prints under `info`, not the Proton account password.
2. `Proton Mail Sorter`, an API credential whose `credential` field holds a random string of at least 32 characters.

The module refers to both by item ID (`op://Automation/<id>/<field>`): `op read` rejects the parentheses in the first title, and IDs survive renames. Find them with `op item list --vault Automation`.

The service-account token is in `proton-mail-sorter/secrets.yaml`, encrypted with sops. systemd hands it to the worker through `LoadCredential`, and the worker passes it only into the environment of the `op read` child process. Read values are cached in memory for 15 minutes. No value goes into the Nix store, workflow JSON, a command line or n8n execution data.

## First deployment

1. **Switch**, done by a human. This starts Bridge. `llama-cpp-classifier` downloads Qwen3.5-9B (about 5.7 GB, pinned and hash-checked) on its first start.
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
8. **Go live after review.** Set `apply = true` in `protonmail-bridge/default.nix`, switch, and activate the scheduled workflow in n8n.
9. **Pull the credential ID back.** Use `just n8n-export` as described in `docs/n8n.md` to bring the real credential ID into the JSON. Only then consider `enforce = true`.

Other devices use `mail.hugo-berendi.de`: IMAP on 993 and SMTP on 465, both SSL/TLS, with the inari Bridge credentials. The name resolves to inari's tailscale address, so it works only on the tailnet.

## What the worker guarantees

- It never takes destination names, endpoints, model names or `apply` from an HTTP body.
- Mail content goes only to the local llama.cpp server.
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
