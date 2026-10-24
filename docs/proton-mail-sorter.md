# Proton Mail automatically sorted through n8n on inari

This adds a separate Proton workflow. The existing Migadu inbox organizer and mail-sorter timer are unchanged.

The worker classifies only `INBOX` and `Archive`, using `qwen3.5:9b` through the local Ollama endpoint. It preserves the twelve categories and reviewed rules of the Windows sorter, including concrete personal urgency, booked concerts, Phoenix with scout context, and the distinction between advertising and real orders. Twitch live notifications from actual Twitch domains bypass the model and go to Werbung.

The target folders are Wichtig, Konzerte, Pfadfinder, Schule, Entwicklung, Rechnungen, Bestellungen, Werbung, Newsletter, Konten-Sicherheit, Termine and Sonstiges. There is no `KI-` prefix. Wichtig keeps its current read flag. Every other classified message is marked read before a native IMAP MOVE. No copy/delete or blanket EXPUNGE fallback exists.

Every ten minutes n8n starts one background job through an authenticated loopback HTTP endpoint. After sorting new mail, it also marks existing unread mail in the known category folders read, without AI. This includes legacy `KI-…` folders and excludes Wichtig, INBOX, Archive, unknown folders and category subfolders. Defaults are 50 classifications and 1,000 retroactive read updates per job; subsequent jobs continue from what remains. `markExistingRead = false` disables this second pass. The separate manual workflow runs just that pass.

## Files and prerequisites

- `hosts/nixos/inari/services/proton-mail-sorter.nix`: optional service and workflow registration.
- `hosts/nixos/inari/services/proton-mail-sorter/`: worker, classifier and tests.
- `hosts/nixos/inari/services/n8n/workflows/proton-mail-sorter.json`: scheduled/manual sorting.
- `hosts/nixos/inari/services/n8n/workflows/proton-mark-read.json`: manual read-only pass without a model call.

Both Bridge and Ollama are expected on **inari**, not on the Windows PC. The defaults are STARTTLS IMAP at `127.0.0.1:1143` and Ollama at `127.0.0.1:8442`, using the existing port registry. Adjust to the actual local listeners if needed. Bridge must already be authenticated and keep its keyring/session across reboots. The Bridge username/password can differ from those of the Windows instance. Use the server instance's credentials.

The repository's existing `ollama.nix` currently has `enable = false`. If the server's running Ollama is not already enabled by another local module, align its NixOS configuration before rebuilding, for example:

```nix
# Inside the inari host configuration, whose arguments already include lib.
services.ollama = {
  enable = lib.mkForce true;
  host = lib.mkForce "127.0.0.1";
  # Avoid loading every model in the currently disabled module's old list.
  loadModels = lib.mkForce ["qwen3.5:9b"];
};
```

This worker does not silently replace the model with the existing llama.cpp classifier. A CPU-only server can be considerably slower than the Windows GPU. Jobs do not overlap; a busy response leaves the current job running. Ollama is a separate service, so size its CPU/RAM limits according to the host's actual resources. The worker's own memory cap does not cap model inference.

Check locally on inari, without exposing either service publicly:

```sh
curl -fsS http://127.0.0.1:8442/api/tags
OLLAMA_HOST=http://127.0.0.1:8442 ollama pull qwen3.5:9b
```

## 1Password on a headless server

Use a read-only 1Password service account, not an interactive desktop session or a cached Windows token. Service accounts cannot access built-in Personal, Private, Employee or default Shared vaults. The existing `Personal / Proton Mail Bridge` reference must therefore not be copied blindly into the server configuration. Create a dedicated vault, for example `Automation`, with:

1. `Proton Mail Bridge (inari)` containing the server's `username` and `password` fields.
2. `Proton Mail Sorter` containing a random `api-token` field of at least 32 characters.

Grant the service account only `read_items` for that dedicated vault. Keep its bootstrap token in the host's encrypted sops file. The worker receives it through systemd `LoadCredential` and supplies it only to the `op read` child process. Neither token nor Bridge fields go into the Nix store, workflow JSON, command-line arguments or n8n execution output. Values are cached in memory for 15 minutes to limit 1Password requests. Restart the worker after secret rotation if the change must take effect immediately.

Sources: [1Password service-account setup and vault restrictions](https://developer.1password.com/docs/service-accounts/get-started/), [reading secret references](https://developer.1password.com/docs/cli/reference/commands/read/).

## Configure inari

Add the encrypted `proton_mail_sorter_op_token` key with `sops hosts/nixos/inari/secrets.yaml`. Do not put a token literal into Nix or the public repository. Then add host settings using the actual copied field references:

```nix
sops.secrets.proton_mail_sorter_op_token.sopsFile = ./secrets.yaml;

yomi.protonMailSorter = {
  enable = true;
  apply = false; # First inspect the private plans; change to true for automatic writes.
  serviceAccountTokenFile = config.sops.secrets.proton_mail_sorter_op_token.path;
  usernameRef = "op://Automation/Proton Mail Bridge (inari)/username";
  passwordRef = "op://Automation/Proton Mail Bridge (inari)/password";
  apiTokenRef = "op://Automation/Proton Mail Sorter/api-token";
  bridgeCertificateSha256 = "REPLACE_WITH_64_HEX_CHARACTERS";
};
```

The module is imported but **disabled by default**, so merely applying this patch does not modify a mailbox or require new secrets at activation. Invalid/missing references or fingerprint fail evaluation when enabled.

Obtain the fingerprint from your own, verified Bridge process on inari. This reads its public certificate without an IMAP login:

```sh
openssl s_client -starttls imap -connect 127.0.0.1:1143 </dev/null 2>/dev/null \
  | openssl x509 -outform DER | sha256sum
```

Use the 64 hexadecimal characters, without the trailing filename marker. A new Bridge instance may have a different certificate from Windows. Certificate changes fail closed; do not disable the pin check to make a job run.

## Validate and deploy

New files must be tracked for flake evaluation. On a Linux checkout with Nix:

```sh
git add hosts/nixos/inari/services/proton-mail-sorter* \
  hosts/nixos/inari/services/n8n/workflows/proton-*.json \
  hosts/nixos/inari/default.nix hosts/nixos/common/base/ports.nix \
  docs/proton-mail-sorter.md
nix develop -c just lint
just nixos-rebuild dry-build inari
nix build --no-link .#nixosConfigurations.inari.config.system.build.proton-mail-sorter-tests
```

The test derivation is present when `yomi.protonMailSorter.enable = true`. No test logs into a real mailbox or reads real 1Password fields. It exercises synthetic IMAP, a test loopback HTTP server, private plan/action logs and Code nodes in a real Node VM without `process`.

After inspecting the evaluated units and choosing to switch, the changed services are the new worker and n8n's environment/startup imports. If applying the optional Ollama override above, Ollama is also affected. No firewall, nginx or tunnel change is needed.

## Attach the n8n credential once

The repo's normal importer seeds both workflows with `enforce = false`. They are initially inactive, so the placeholder credential cannot trigger repeated failing requests. After deployment:

1. Open **Proton Mail - sort unsorted automatically**.
2. Create an HTTP Header Auth credential, header name `Authorization`, value `Bearer <the api-token from 1Password>`.
3. Attach the same credential to both workflows' **Start private job** node. Credentials remain in n8n's encrypted store, as required by this repo.
4. Run the sorting workflow manually. HTTP 202 means the background job started; it does not mean all mail is already sorted. A busy response does not start another job.
5. Inspect `journalctl -u proton-mail-sorter` for the completed counter-only status. Private previews and action logs are in the service's state directory, `/var/lib/private/proton-mail-sorter` with DynamicUser, also accessible through its `/var/lib/proton-mail-sorter` systemd link as appropriate. They contain subjects; do not publish them.
6. To view status inside n8n, use the same credential with GET `={{ $env.PROTON_SORTER_URL + "/api/status" }}`. No message bodies or secret values are returned.
7. After checking dry-run plans, set `apply = true`, dry-build and deploy. Activate/publish the scheduled workflow in n8n. It then handles new and existing categorized unread mail automatically every ten minutes.
8. Later use `just n8n-export` as described in `services/n8n/AGENTS.md`, merge the real credential IDs into these two source JSON files and only then consider switching `enforce` to true. Do not commit unrelated exports or credentials.

The worker never accepts destination names, endpoints, model names or `apply` overrides from HTTP bodies. Message data is sent only to the configured private Ollama endpoint. Folder names, UIDVALIDITY and message hashes are checked before writes. Unknown categories and inference failure preserve the mail. Missing or changed messages are held and recorded. A read-flag failure prevents that message's move. Partial earlier changes remain applied and recorded; subsequent jobs only process mail still in the unsorted folders. A restart during a job is reported as interrupted rather than silently successful.

## Validation performed while preparing this patch

The local environment was Windows `tsukuyomi`, not inari. The tests use the pinned `imap-tools` 1.15.0 version. n8n HTTP Request 4.2, Schedule Trigger 1.2 and relevant HTTP parameter names were checked against the upstream source for the pinned n8n 2.39.6 release. The two workflow graphs and their Code nodes were tested with Node VM. Nixpkgs package paths were checked at the repository's exact pinned revision.

No Nix or WSL Linux distribution was available locally, so **Nix evaluation, `just lint`, the inari dry-build and a real n8n CLI import remain to run on inari**. The files have not been pushed, deployed or tested against the live server. No real mail was read, marked read or moved by these tests.
