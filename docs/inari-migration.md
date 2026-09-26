# Inari replacement and recovery plan

Status on 26 September 2026: **not cleared for erasure or return**. Repository
access, a restore rehearsal and preservation of `/boot` still require a local
sudo password. No installation, pool export, service restart or disk erasure has
been performed for this audit.
Every SOPS file now also decrypts without the old keys: on 26 September Hugo
proved each of the six files opens with the YubiKey's PIV identity alone and with
the offline key on kagutsuchi alone. Restic restores and boot-key recovery remain
unverified. The key changes that wait for the new hardware are listed in
[Key changes after the migration](#key-changes-after-the-migration).

## Hardware and timing

Beelink offered an EQR6 7735HS with 24 GB RAM and a 500 GB SSD for an additional
EUR 150. Acceptance is likely but nothing has been paid or shipped. The earliest
return date is 28 September. Return the original RAM and currently installed
original SSD; retain the separately purchased 2x32 GB DDR5-4800 SO-DIMM kit.
Beelink confirmed that kit works in the replacement.

The running machine identifies its SSD as Crucial CT500P3PSSD8, serial
24054701B359, 465.8 GiB. This identifies the installed drive; it does not establish
its purchase provenance. Match it to the return agreement before packing.
The replacement SSD's manufacturer and model remain unknown.

## Evidence collected on the running machine

The hostname is `inari`. The checkout was clean at `ad51273`; fetching origin
showed no newer commits. The running system is
`/nix/store/lkr6zb8n6jdz9v8xswkjhpl9m36azavx-nixos-system-inari-26.05.20260916.4c78701`.
The table records snapshot timestamps from Restic's journal output, not a fresh
repository listing. Times are CEST.

| Repository | Latest snapshot seen in journal | Result |
| --- | --- | --- |
| `/raid5pool/backups/restic/data` | `46a5bdfa`, 26 Sep 13:15:26 | 13.366 GiB; backup and 5% data check completed at 13:18 |
| `/raid5pool/backups/restic/state` | `64513906`, 23 Sep 00:00:06 | 177.825 GiB; backup and 5% data check completed at 00:10 |
| B2, selected paths only | `d5f2946d`, 26 Sep 13:25:48 | Backup completed at 13:29 |

On 26 September at 13:14, `postgresqlBackup` failed because the PostgreSQL
socket was absent. Its dependent state backup did not start. The dump succeeded
at 13:25 before the offsite backup, but the local state backup was not retried.
The underlying startup failure has not been reproduced or fixed. A fresh state
backup is required before shutdown; the timer's last-trigger time and the unit's
`Result=success` do not prove a recent snapshot.

`nix eval` confirms the two local sets back up `/persist/data` and `/persist/state`.
They exclude `.direnv`, `.git`, `.stfolder` and `.stversions`; data also excludes
`/persist/data/home/hugob/projects`. State excludes the configured Discord and
Steam paths. Review and separately preserve wanted excluded files, especially
uncommitted projects. `/boot`, `/nix` and `/persist/local/cache` are outside these
local backup roots. Rebuilding `/nix` requires available flake inputs and packages;
save any locally built, otherwise unavailable software separately.

B2 covers photos, documents, `/raid5pool/data`, `/persist/data` and PostgreSQL
dumps. It excludes photo thumbnails and encoded video. It does **not** cover the
whole state tree or all HDD data, and cannot substitute for the local migration
backup. No historical monthly offsite restore result was found in the journal.

Both pools are ONLINE, with zero recorded read/write/checksum errors. Their
21 September scrubs reported zero errors. `raid5pool` is a three-drive RAIDZ1 with
about 5.75 TiB available. All its current datasets report encryption off, so the
pool needs no TPM or ZFS decryption key. Restic repositories remain separately
password-protected.

Pool GUID: `7197263990503489242`. HDDs are ST4000NE001-2MA101, serials
`WS2568N2`, `WS256ZB1`, `WS256V7L`. Preserve all three drives and their USB/SATA
connections. One pool member uses a JMicron USB identifier. Record physical bay
labels as well as serials. Import on replacement hardware remains untested.

`zroot` uses AES-256-GCM and a prompted key location. The configuration expects
`/boot/zroot-key.jwe` sealed to the old TPM and
`/boot/zroot-recovery-key.age` as its recovery copy. Their existence, decryption
and key validity have not yet been checked because `/boot` is root-only.
`zfs get` reports `keyformat raw` for zroot, while `partitions.nix` creates it
with `keyformat = "passphrase"` from `/kagutsuchi/secrets/inari/disk.key`: the
key was replaced after installation. That 9-byte file therefore no longer
unlocks the pool, and disko would reuse it for a new pool unless it is replaced.

## Run the non-destructive audit

Review [the script](../scripts/inari-migration-check.sh), then run on Inari:

```sh
nix develop -c bash scripts/inari-migration-check.sh
```

It requests sudo in your terminal. Do not send the password in chat. It does not
stop services, start backups, prune repositories, change ZFS keys or install
anything. It writes a new private `inari-migration.*` directory under
`/raid5pool/backups` and briefly uses root-only `/run` storage for decrypted keys.
Each retry uses a new directory and leaves previous evidence intact.

The script encrypts all of `/boot`, SSH host keys, initrd SSH keys, the Restic
password, rendered B2 credentials and this checkout into `recovery.tar.age`.
It checks local decryption and validates the recovered ZFS key using
`zfs load-key -n`. It then uses the archived Restic password to list snapshots,
pin one snapshot per set, check repository structure and restore both complete
snapshots with `--verify`. Expect roughly 191 GiB of restored files and substantial
disk I/O. It checks for at least 300 GiB free before each restore.

Restored data is plaintext on the unencrypted HDD pool, within a root-only
directory. Preserve that permission boundary. The encrypted recovery archive
must also be copied to another device. Do not commit either secrets or restored
files to Git. A failed script is not a passed rehearsal; inspect its report and
retain any archive already created.

## Prove recovery without the old SSD

The Restic password comes from `hosts/nixos/common/secrets.yaml`. B2 credentials
come from `hosts/nixos/inari/secrets.yaml`. SOPS currently uses the shared SSH
host private key at `/persist/state/etc/ssh/ssh_host_ed25519_key`. Keeping that
key only inside an encrypted Restic backup creates a recovery dependency loop.

Four recipients can decrypt the SOPS files, and the audit script encrypts
`recovery.tar.age` to the same four by reading `.sops.yaml`:

| Recipient | Private half | Status |
| --- | --- | --- |
| `pilot_yubikey` | PIV slot 82 on YubiKey 30636315. Identity stub `~/.config/sops/age/yubikey.txt` on Amaterasu | Decrypts all six files on its own (tested 26 September) |
| `recovery_offline` | `age/yomi-recovery.txt` on kagutsuchi | Decrypts all six files on its own (tested 26 September) |
| `pilot_user_key` | Old shared SSH login key, SHA256:mYs7VNSw… | To be retired after the migration |
| `shared_host_key` | Inari's and Amaterasu's shared host key, SHA256:G5JybhUg… | To be replaced after the migration |

kagutsuchi is the USB key stick that `scripts/live.sh` and disko take their
install-time keys from. It was plain ext4 and held `shared_host_key`'s private
half, the old login key and every host's SSH host keys in the clear. It is now
LUKS2 (header UUID `40ed3eaf-4232-4961-b87b-88b2f998ec10`), unlocked with
`sudo scripts/kagutsuchi.sh open` and locked with `close`. Besides `secrets/<host>/`
it holds `gpg/` (the pilot's OpenPGP primary key, its backups and revocation
certificates) and `age/`. Its passphrase is kept offline; without it the stick is
unreadable.

The 26 September Amaterasu report also found permission problems:

- Both old pilot Age key files, `/persist/state/home/hugob/.config/sops/age/keys.txt`
  and `/persist/state/home/hugob/sops/.config/sops/age/keys.txt`, were mode 0644.
  Hugo was given `chmod 600` for both; the result has not been rechecked.
- `/persist/state/home/hugob/.ssh/id_ed25519` is an unencrypted copy of the old
  login key. It goes when that key is retired.
- The shared host private key is owned by `hugob:users`, mode 0700, on Amaterasu
  and on Inari. Home-manager's sops reads it through `sops.age.sshKeyPaths`.
  Replacing the host keys has to account for that.
- `~/.gnupg` was 0755 on both hosts; it is 0700 on Inari. Impermanence copies the
  mode of an existing source directory, so a `chmod 700 ~/.gnupg` fixes it for
  good.

Amaterasu's host key, checked against its live daemon:

```text
SHA256:G5JybhUglUyo8obZulgovg1mVvyQf6PQQejW8QjC1GE
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAOhNvRjubxhkVPKRHqiGzPvmMX5vD7kQP9b1+k+mvOq root@amaterasu
```

This is the same key as Inari's. The
[Amaterasu agent prompt](amaterasu-recovery-prompt.md) that produced the report is
kept for reference.

On Amaterasu, test the archive with each new identity, never with the old keys:

```fish
set t (mktemp -d -p /run/user/(id -u))
sudo scripts/kagutsuchi.sh open
sudo cat /kagutsuchi/age/yomi-recovery.txt > $t/offline.txt; chmod 600 $t/offline.txt
sudo scripts/kagutsuchi.sh close
age -d -i $t/offline.txt recovery.tar.age | tar -tf - >/dev/null; and echo OFFLINE-OK
age -d -i ~/.config/sops/age/yubikey.txt recovery.tar.age | tar -tf - >/dev/null; and echo PIV-OK
command rm -rf $t
```

Require both. Then confirm the boot recovery file, Restic password, B2
credentials and host keys are present. Extract into private temporary storage,
decrypt the inner ZFS recovery file, and test access to Restic with the recovered
password. Test B2 snapshot listing with its archived credentials too. Never print
the credential values. Local decryption on Inari alone does not establish
independent access.

## Before returning the SSD

1. Complete the audit and independent recovery-identity test. Save its report,
   exact snapshot IDs and encrypted archive somewhere outside the returned PC.
2. Review excluded projects and any other SSD data outside the two persist roots.
   The audit archive includes this checkout, not every project.
3. Arrange a maintenance window. Stop application writers in a reviewed order,
   take fresh database dumps while PostgreSQL is available, and make final local
   backups of both persist roots. Include SQLite and container writers. Ordinary
   live Restic backups are not an atomic application/database snapshot.
4. Restore the final snapshot IDs and verify files. Import database dumps into a
   disposable PostgreSQL cluster with the matching extensions; test representative
   application data. A file checksum restore alone is not an application test.
5. Review the final report and erasure plan with Hugo. Only after that review may
   the original SSD be erased. Shut down cleanly and retain all HDDs. Disconnect
   the HDD pool before any SSD erasure or installation operation.

## Replacement installation outline, subject to review

Inspect the replacement SSD's exact model, serial, capacity, firmware and SMART/NVMe
health before deciding to keep it long term. Install the retained RAM and check
hardware stability before restoring production services.

Use compatible NixOS rescue/install media with ZFS support. Keep the HDDs
disconnected during partitioning. The current disko configuration defaults to
`/dev/nvme0n1` and references `/kagutsuchi/secrets/inari/disk.key`; it is not a
ready-to-run replacement installer. Select the SSD by its verified identity and
review the encryption-key setup before running any destructive command.
`scripts/live.sh` asks for kagutsuchi's passphrase when it unlocks the stick.
The ISO's `liftoff` helper clones the GitHub mirror over https, which needs no
credentials and is kept in sync with Inari's Forgejo. It runs in its own
process, so `cd yomi` afterwards yourself.
Replace `secrets/inari/disk.key` with a freshly generated key before disko runs;
the current file is the stale 2024 passphrase.

Create a fresh encrypted `zroot`, its blank rollback snapshot and persistent
datasets. Reconnect and import the existing HDD pool, initially read-only to
verify its identity and contents. Do not recreate or upgrade it. Use ZFS compatible
with its active features; the current host pins ZFS 2.3. Preserve host ID
`14725dd3` when replacing the old Inari, and investigate any import ownership
warning instead of blindly forcing import.

Restore the selected snapshots under the installer target, preserving Restic's
`persist/data` and `persist/state` paths, ownership and permissions. Restore host
keys before SOPS activation: the replacement boots with the existing shared host
key, which every SOPS file is still encrypted to. It gets its own key only once it
is running (see below). `live.sh` copies `secrets/inari/ssh*` from kagutsuchi into
`/mnt/persist/state/etc/ssh/`; those are the same keys the archive holds. Keep application services stopped until persistent
mounts and database recovery are verified. Review the generated hardware config
and actual NIC names; the existing config explicitly uses `eno1` and `wlp2s0`.

Seal the new root key to the replacement TPM, create a new independently
decryptable recovery copy, and install the new blob at `/boot/zroot-key.jwe`.
Encrypt the recovery copy to `recovery_offline` and `pilot_yubikey`, not to the
old keys, and prove it with each of them and `zfs load-key -n`.
The old TPM blob is archival material, not a portable unlock mechanism. Validate
manual recovery and TPM boot on the replacement, then verify mounts, secrets,
networking and services. Run a new backup and restore check before declaring the
migration complete.

## Key changes after the migration

Held until the replacement runs, because until then the migration archive and
the first boot depend on the old keys. Do them in this order, verifying each step
before the next.

### 1. Separate host keys

`shared_host_key` is one private key installed on both hosts, and it sat
unencrypted on kagutsuchi until 26 September. Both hosts get a new one. The order
guarantees each host can decrypt at every boot:

1. On the host, as root, generate the new key beside the old one:
   `ssh-keygen -t ed25519 -N '' -C root@<host> -f /persist/state/etc/ssh/ssh_host_ed25519_key.new`.
2. Add `ssh-to-age < …key.new.pub` to `.sops.yaml` as `<host>_host_key`, in every
   rule the host needs, next to `shared_host_key`. Run `just sops-rekey`, commit,
   and switch. The secrets are now encrypted to both keys.
3. Move the new key into place (`…key.new` → `ssh_host_ed25519_key`, both halves),
   keeping the owner and mode home-manager's sops expects (see above). Switch
   again and confirm `sops-install-secrets` succeeds, then reboot once. A decryption
   failure is visible at this point, while the old key is still a recipient and
   can be put back.
4. `just import-host-key <host>` pins the new key in `hosts/nixos/<host>/keys/`,
   which feeds every host's `knownHosts`. Commit, and switch the other hosts.
5. `just export-keys` on the host puts the new keys on kagutsuchi.

Do this for Inari while Hugo is at home, and for Amaterasu, then remove
`shared_host_key` from `.sops.yaml` and rekey. Inari's initrd has its own RSA host
key in `/etc/secrets/initrd/`; the port 2222 unlock uses that, not these keys.

### 2. Retire the old login key

The old shared login key (SHA256:mYs7VNSw…) may leave only when:

- the new `/boot/zroot-recovery-key.age` and `recovery.tar.age` no longer need it
  (both are encrypted to all `.sops.yaml` recipients),
- a reboot at home has unlocked Inari's initrd over port 2222 with the YubiKey
  key. It is already authorized there (`boot.initrd.network.ssh.authorizedKeys`
  lists `id_ed25519_sk.pub`), but that has never been tried. If the YubiKey were
  refused, unlocking needs someone at the machine.

Then remove it from:

- `hosts/nixos/amaterasu/keys/id_ed25519.pub`, `hosts/nixos/tsukuyomi/keys/id_ed25519.pub`
  and `hosts/nixos/inari/services/guacamole/ed25519.pub`. The guacamole
  user-mapping does not contain the private key: its secret decrypts to 393
  bytes, and the private key alone is 464.
- The `~/.ssh/id_ed25519` fallbacks in `yomi.pilot.sshIdentity` (`home/amaterasu.nix`,
  `home/inari.nix`) and the key files under `~/.ssh` on both hosts.
- `pilot_user_key` in `.sops.yaml`, then `just sops-rekey`.
- `secrets/amaterasu/id_ed25519*` on kagutsuchi.
- Hugo's Forgejo and GitHub accounts.

The `just ssh-to-age` recipe converts that key and goes with it.

### 3. Rotate the secret values

Rekeying does not revoke anything. Every past revision stays encrypted to
`pilot_user_key` and `shared_host_key`, and the repository is mirrored publicly.
Anyone holding either private key can read every value ever committed. That was
anyone with kagutsuchi until 26 September. So every value in the six
`secrets.yaml` files needs rotating. `sops` lists the names. Start with the
credentials that reach outside the house:

- the B2 account (`b2_account_id`, `b2_account_key`) and `backup_password`,
  which protects the Restic repositories themselves. Changing it means
  `restic key add`/`remove` on every repository, not a new repository.
- the Cloudflare tokens and tunnel credentials, `tailscale_auth_key`, the
  `GITHUB_TOKEN` and the Forgejo runner tokens
- the mail and SMTP passwords (`hugob_mail_pass`, `outlook_mail_pass`,
  `imap_personal_password`, `msmtp_password`, `no_reply_smtp_password`, …)
- third-party API keys (Exa, AccuWeather, Govee, MaxMind, WakaTime, …)
- `wireless`/`wifi_password`, `pilot_password` and `amaterasu_restic_ssh_key`.

Service-internal secrets (OIDC clients, app keys, `*_env` files) come after
those; each needs its service's own procedure. `yubikey/u2f_keys` is unused
since `yomi.yubikey` was removed and can be deleted.

## Filesystem choice for the replacement SSD

Recommendation for this migration: retain ZFS on the SSD and the HDD pool, while
improving backup coverage and snapshot boundaries. Btrfs inside LUKS2 is a viable
alternative if making root recovery independent of ZFS is a priority. It is not
necessary to recover through Restic, which restores files to either filesystem.
No filesystem change is implemented by this plan.

| Consideration | Keep ZFS root | Btrfs inside LUKS2 |
| --- | --- | --- |
| Existing configuration | Existing datasets, Sanoid and rollback remain usable | Amaterasu supplies a starting layout and shared rollback module, but Inari needs new unlock and snapshot configuration |
| Boot and recovery | Root import/unlock requires ZFS and the new TPM blob | Root uses Btrfs and cryptsetup; HDD import still requires ZFS |
| Kernel maintenance | Continue the tested ZFS/kernel pairing | Still need a compatible ZFS/kernel pairing for the HDD pool |
| Encryption recovery | Preserve a portable root key alongside the TPM-sealed blob | LUKS2 can have independent recovery, TPM2 and FIDO2 unlock slots |
| Snapshot replication | Can later use ZFS send to a separate HDD dataset | Use Restic or stored Btrfs send streams; cannot receive Btrfs streams as ZFS datasets |
| Migration work | Fresh install, new TPM enrollment, restore and validation | Those tasks plus rollback, monitoring, snapshot policy and container-storage review |

These tradeoffs follow from the existing host configuration and the upstream
[OpenZFS kernel-module requirements](https://openzfs.github.io/openzfs-docs/Developer%20Resources/Custom%20Packages.html),
[Btrfs subvolume model](https://btrfs.readthedocs.io/en/latest/Subvolumes.html), and
[systemd LUKS2 enrollment support](https://github.com/systemd/systemd/blob/main/man/systemd-cryptenroll.xml).
FIDO2 disk unlocking requires separate enrollment and a compatible token; an SSH
credential does not automatically unlock LUKS. Keep a recovery key independent of
both the motherboard and YubiKey. Back up the LUKS header after enrollment if that
layout is chosen.

The strongest argument for Btrfs here is standardizing the SSD layout with
Amaterasu and allowing root recovery before the ZFS HDD pool is available. The
benefit is limited by the fact that Inari will continue operating ZFS for its
HDDs. Neither choice fixes faulty RAM/CPU hardware or supplies redundant SSD data
copies. There is no workload benchmark here supporting a performance or endurance
claim for switching filesystems.

Keep the current mount-path contract whichever filesystem wins:

| Mount | Intended handling |
| --- | --- |
| `/boot` | ESP, consider 1 GiB for headroom; encrypted recovery archive after boot-key changes |
| `/` | Disposable root with a tested blank rollback baseline |
| `/nix` | Separate dataset/subvolume; rebuildable, no routine snapshots or Restic backup |
| `/persist/data` | Irreplaceable user data, snapshots and complete intended backup coverage |
| `/persist/state` | Service state and identities, backups with explicit database consistency handling |
| `/persist/local/cache` | Rebuildable caches, no routine snapshots or backup |
| `/raid5pool` | Existing pool and dataset layout, retained intact |

On Btrfs, use sibling top-level subvolumes so root rollback cannot delete
persistent data. Nested subvolumes are separate snapshot boundaries; snapshotting
the parent does not capture their contents. Test the existing rollback module
with the chosen layout rather than copying the laptop installer verbatim.

There is a measurable opportunity in storage structure before changing filesystem.
The current SSD uses about 226 GiB physically. `/nix` uses 83.2 GiB. Live persistent
data and state use about 8.24 and 71.9 GiB, while their snapshots retain another
11.3 and 43.3 GiB. The state backup contains about 2.81 million files. Inventory
the largest state directories before splitting them: regenerated container image
layers and caches may deserve different retention from volumes and databases.
Do not exclude all of `/var/lib/docker`, since it can contain irreplaceable volumes.
Any new child dataset/subvolume must be included explicitly in snapshot and backup
verification. Keep service paths stable to avoid needless restore remapping.

Continue the existing placement of Nix build scratch on the HDD pool until the
replacement SSD is identified and measured. The repository records substantial
historical writes on the old SSD, but current SMART data was not collected during
this audit. A filesystem switch alone is not evidence of reduced SSD wear.

For Btrfs, start with normal checksumming/COW and modest Zstd compression. Do not
disable COW globally for databases or Docker as a speculative optimization:
NOCOW sacrifices data checksums and compression. Tune only a measured problem,
with a separate tested backup policy. See [Btrfs compression requirements](https://btrfs.readthedocs.io/en/latest/Compression.html).
