# Inari replacement and recovery plan

Status on 26 September 2026: **not cleared for erasure or return**. Repository
access, a restore rehearsal and preservation of `/boot` still require a local
sudo password. No installation, pool export, service restart or disk erasure has
been performed for this audit.

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

The archive is encrypted to both recipients in `.sops.yaml`: the pilot's
SSH-derived Age identity and the shared host identity also configured on
Amaterasu. Confirm an independent private identity is present and usable before
returning anything. The public recipient strings alone cannot decrypt backups.
The pilot's SSH private key also needs its passphrase when converted to Age.

Hugo currently has a YubiKey SSH login key, but has not confirmed an independent
Age identity. Inari's attempted SSH connection to Amaterasu stopped at host-key
verification because no trusted ED25519 host key was available. No remote key
inspection was performed. Use the [Amaterasu agent prompt](amaterasu-recovery-prompt.md)
to establish this locally. SSH login authorization does not add an Age recipient.
Age supports YubiKey PIV identities through a separate plugin; that is distinct
from the existing FIDO2 SSH credential. See the [Age documentation](https://github.com/FiloSottile/age#readme).

On an independent machine, using its existing Age identity:

```sh
age -d -i /path/to/independent-age-identity recovery.tar.age | tar -tf -
```

Require both pipeline commands to succeed, and confirm the boot recovery file,
Restic password, B2 credentials and host keys are present. Then extract into
private temporary storage, decrypt the inner ZFS recovery file, and test access
to Restic using the recovered password. Test B2 snapshot listing with its archived
credentials too. Never print the credential values. Local decryption on Inari
alone does not establish independent access.

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

Create a fresh encrypted `zroot`, its blank rollback snapshot and persistent
datasets. Reconnect and import the existing HDD pool, initially read-only to
verify its identity and contents. Do not recreate or upgrade it. Use ZFS compatible
with its active features; the current host pins ZFS 2.3. Preserve host ID
`14725dd3` when replacing the old Inari, and investigate any import ownership
warning instead of blindly forcing import.

Restore the selected snapshots under the installer target, preserving Restic's
`persist/data` and `persist/state` paths, ownership and permissions. Restore host
keys before SOPS activation. Keep application services stopped until persistent
mounts and database recovery are verified. Review the generated hardware config
and actual NIC names; the existing config explicitly uses `eno1` and `wlp2s0`.

Seal the new root key to the replacement TPM, create a new independently
decryptable recovery copy, and install the new blob at `/boot/zroot-key.jwe`.
The old TPM blob is archival material, not a portable unlock mechanism. Validate
manual recovery and TPM boot on the replacement, then verify mounts, secrets,
networking and services. Run a new backup and restore check before declaring the
migration complete.

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
