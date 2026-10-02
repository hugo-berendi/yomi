{
  config,
  lib,
  pkgs,
  ...
}: let
  destination = "/persist/state/var/backup/app-state";
  snapshotName = "yomi-app-state-backup";
  snapshotMounts = "/run/restic-app-state";
  stateSnapshot = "${snapshotMounts}/state";
  raidSnapshot = "${snapshotMounts}/raid";
  state = path: {source = "${stateSnapshot}/${path}";};
  applications = {
    vaultwarden = (state "var/lib/bitwarden_rs") // {sqlite = ["db.sqlite3"];};
    forgejo =
      (state "var/lib/forgejo")
      // {
        exclude = ["dump"];
        sqlite = ["data/forgejo.db"];
      };
    n8n = (state "var/lib/private/n8n") // {sqlite = [".n8n/database.sqlite"];};
    home-assistant = state "var/lib/hass";
    pocket-id = state "var/lib/pocket-id";
    matrix = state "var/lib/tuwunel";
    mautrix-discord = state "var/lib/mautrix-discord";
    mautrix-signal = state "var/lib/mautrix-signal";
    mautrix-whatsapp = state "var/lib/mautrix-whatsapp";
    karakeep = state "var/lib/karakeep";
    calendar-sync = state "var/lib/vdirsyncer";
    ntfy = state "var/lib/ntfy-sh";
    ssh = state "etc/ssh";
    paperless = {
      source = "${raidSnapshot}/data/paperless";
      sqlite = ["db.sqlite3"];
    };
  };
  manifest = pkgs.writeText "app-state-sources.json" (builtins.toJSON applications);
  helper = builtins.path {
    path = ./restic/app-state.py;
    name = "yomi-app-state.py";
  };
  # raid5pool uses ZFS's native mountpoint after extraPools imports it; it has
  # no fileSystems entry. The persisted state dataset is mounted by NixOS.
  datasets = [config.fileSystems."/persist/state".device "raid5pool"];
in {
  config = lib.mkIf config.yomi.restic.offsite.enable {
    assertions = [
      {
        assertion = config.fileSystems."/persist/state".fsType == "zfs" && lib.elem "raid5pool" config.boot.zfs.extraPools;
        message = "Inari's app-state backup needs ZFS snapshots for /persist/state and /raid5pool.";
      }
    ];
    yomi.restic.offsite.paths = [destination];
    yomi.restic.sets.offsite = {
      requires = ["restic-app-state.service"];
      # Restore rehearsals must select a snapshot with the new recovery format.
      extraBackupArgs = ["--tag app-state-v1"];
    };
    # The partial copy is never a recovery artifact. The local state backup
    # still includes the last published copy as well as the original state.
    yomi.restic.sets.state.exclude = ["${destination}.partial" "${destination}.previous"];
    # postgresqlBackup runs as postgres and must traverse this shared parent.
    # The app-state artifact and each PostgreSQL backup keep private modes.
    systemd.tmpfiles.rules = ["d /persist/state/var/backup 0755 root root -"];
    systemd.services.restic-app-state = {
      description = "Stage application state from frozen ZFS snapshots";
      unitConfig.RequiresMountsFor = ["/persist/state" "/raid5pool"];
      restartIfChanged = false;
      path = [config.boot.zfs.package pkgs.coreutils pkgs.python3 pkgs.util-linux];
      environment = {
        APP_STATE_SOURCES = toString manifest;
        APP_STATE_DESTINATION = destination;
      };
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "4h";
        UMask = "0077";
        PrivateTmp = true;
        PrivateMounts = true;
        ProtectHome = true;
        NoNewPrivileges = true;
        RuntimeDirectory = "restic-app-state";
        RuntimeDirectoryMode = "0700";
      };
      script = ''
        set -euo pipefail
        snapshots=(${lib.escapeShellArgs (map (dataset: "${dataset}@${snapshotName}") datasets)})
        mounts=("$RUNTIME_DIRECTORY/state" "$RUNTIME_DIRECTORY/raid")
        cleanup() {
          local failed=0
          for mountpoint in "''${mounts[@]}"; do
            if mountpoint -q "$mountpoint"; then
              umount "$mountpoint" || failed=1
            fi
          done
          for snapshot in "''${snapshots[@]}"; do
            if zfs list -H -o name -t snapshot "$snapshot" >/dev/null 2>&1; then
              zfs destroy "$snapshot" || failed=1
            fi
          done
          return "$failed"
        }
        # Only this job uses the reserved name. Recover snapshots left by a
        # killed run, and release them on both success and failure.
        cleanup
        trap cleanup EXIT
        # Explicit private mounts avoid relying on .zfs automount visibility
        # across the host and this service's sandbox namespaces.
        for index in "''${!snapshots[@]}"; do
          zfs snapshot "''${snapshots[$index]}"
          mkdir -p "''${mounts[$index]}"
          mount -t zfs -o ro "''${snapshots[$index]}" "''${mounts[$index]}"
        done
        python3 ${helper} "$APP_STATE_SOURCES" "$APP_STATE_DESTINATION"
      '';
    };
  };
}
