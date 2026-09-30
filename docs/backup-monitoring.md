# Backup monitoring

Restic writes a success timestamp only after its backup, pruning and integrity
checks finish successfully. The metric files live in `/var/lib/restic-metrics`,
persist across reboots and are read by node-exporter's textfile collector.
Amaterasu exposes only that collector through its Tailscale firewall interface.

Grafana alerts after 30 hours without a successful inari backup or seven days
without an amaterasu backup. It retains the laptop's last observed success while
the laptop is offline. Missing metrics also alert, so a newly deployed host stays
unverified until its first successful run.

The state and off-site backup units require a fresh successful PostgreSQL dump.
There is no independent dump timer when restic manages the schedule.

The off-site backup also requires `restic-app-state.service`. That job snapshots
the ZFS datasets mounted at `/persist/state` and `/raid5pool`, copies selected
application directories, and publishes them under
`/persist/state/var/backup/app-state`. It preserves ownership, permissions,
encrypted n8n credentials, and n8n's encryption config. SQLite copies include
committed WAL transactions, roll back unfinished journal transactions, and pass
`PRAGMA integrity_check` before publication.
The original databases remain untouched. A failed copy retains the previous
complete artifact and prevents the off-site backup from starting.

The staged directories cover Vaultwarden, Forgejo, n8n, Home Assistant, Pocket ID,
Tuwunel, all three Matrix bridges, Karakeep, calendar sync status and OAuth tokens,
ntfy, SSH host keys, and Paperless metadata. `manifest.json` records the selected
sources and SQLite files. Forgejo's existing compressed dumps are excluded from
this copy because its repositories, configuration and SQLite database are already
included. The normal local state backup still covers those dumps.

The reserved ZFS snapshot name is `yomi-app-state-backup`. The job removes a stale
snapshot with that exact name before retrying and releases its snapshots on exit.
Snapshots left by SIGKILL or power loss are removed on the next run. Partial and
previous staging directories are excluded from the local state backup.

These are filesystem snapshots, not coordinated application exports. The two
pools, PostgreSQL dump, and media files do not represent one atomic transaction.
Tuwunel's frozen directory copy relies on database crash recovery; its separate
[managed RocksDB backup facility](https://matrix-construct.github.io/tuwunel/backups.html)
is not exercised by this job. The monthly rehearsal below covers Paperless and
PostgreSQL, not a complete recovery of every staged application.

The off-site integrity check reads 5% of B2 repository data every Sunday. The
monthly restore rehearsal selects the newest `app-state-v1` snapshot for inari.
It downloads one original Paperless document, the staged Paperless SQLite database
and the PostgreSQL dump. It checks SQLite integrity and a nonempty
`documents_document` table, imports PostgreSQL into a disposable cluster with the
configured extensions, and checks for Immich tables. Paperless does not use
PostgreSQL on this host. Temporary restored data is removed after success or
failure and before retrying an interrupted run.

Before the first switch that adds Matrix bridge persistence, migrate their current
directories. The running bridge services use static users, so their live state is
outside `/var/lib/private` and would otherwise be lost by root rollback. On inari,
stop the bridges, copy their directories with ownership intact, switch, then start
them again. Check that the destinations do not already hold a different copy
before copying. This migration needs interactive sudo and briefly disconnects the
bridges.

```sh
(
  set -e
  /run/wrappers/bin/sudo systemctl stop mautrix-discord mautrix-signal mautrix-whatsapp
  /run/wrappers/bin/sudo cp -a --reflink=auto /var/lib/mautrix-discord /var/lib/mautrix-signal /var/lib/mautrix-whatsapp /persist/state/var/lib/
  nix develop -c just nixos-rebuild switch inari
  /run/wrappers/bin/sudo systemctl start mautrix-discord mautrix-signal mautrix-whatsapp
)
```

After switching, run the off-site backup once before the restore rehearsal. Older
untagged snapshots lack the new staging artifact and are deliberately skipped.
The backup triggers both PostgreSQL and application state preparation. Inspect
the staging journal if any selected source is missing. These commands need
interactive sudo and contact B2:

```sh
sudo systemctl start restic-backups-offsite.service
sudo systemctl start restic-backups-offsite-check.service
sudo systemctl start restic-offsite-restore.service
journalctl -u restic-app-state -u restic-backups-offsite -u restic-backups-offsite-check -u restic-offsite-restore
```

For application recovery, restore the chosen `app-state/<application>` directory
into disposable storage first. Stop the application, place that copy at its
configured backing path, restore ownership, then start it using the matching
application version. n8n needs the database and `.n8n/config` together. Use the
standalone staged Paperless database rather than the additional raw database under
`/raid5pool/data`. Recover runtime secrets through sops separately.

Run the regressions with
`nix build --no-link .#checks.x86_64-linux.recovery .#checks.x86_64-linux.backup-monitoring .#checks.x86_64-linux.custom-options`.
The recovery check runs the generated staging script with a fixture ZFS command,
tests WAL recovery and interrupted publication, and restores a real local restic
repository into disposable SQLite and PostgreSQL databases. It does not access B2
or create snapshots on the host.
