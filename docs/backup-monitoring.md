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
There is no independent dump timer when restic manages the schedule. This does
not make the running applications' files and databases one atomic snapshot.

The off-site integrity check reads 5% of B2 repository data every Sunday. The
monthly restore rehearsal downloads one original Paperless document and the
PostgreSQL dump, imports the dump into a disposable cluster with the configured
extensions, and checks for Immich and Paperless tables. It neither changes the
production database nor tests a complete application recovery. Temporary restored
data is removed after success or failure and before retrying an interrupted run.

After switching, these commands can establish the initial check/restore metrics
without waiting for their scheduled dates:

```sh
sudo systemctl start restic-backups-offsite-check.service
sudo systemctl start restic-offsite-restore.service
journalctl -u restic-backups-offsite-check -u restic-offsite-restore
```

Run the monitoring regressions with
`nix build .#checks.x86_64-linux.backup-monitoring`.
