{
  config,
  lib,
  pkgs,
  ...
}: let
  backup = config.services.restic.backups.offsite;
in {
  # A repository check cannot prove that a SQL dump can actually be imported.
  # Use the production extensions, but a disposable cluster with no TCP listener.
  systemd.services.restic-offsite-restore = {
    description = "Restore a B2 document and PostgreSQL dump into disposable storage";
    wants = ["network-online.target"];
    after = ["network-online.target" "restic-backups-offsite.service" "restic-backups-offsite-check.service"];
    restartIfChanged = false;
    path = [backup.package pkgs.jq pkgs.zstd config.services.postgresql.finalPackage];
    environment = {
      PGHOST = "/run/restic-offsite-restore";
      PGPORT = "55432";
      PGUSER = "yomi_restore_admin";
    };
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      EnvironmentFile = backup.environmentFile;
      LoadCredential = [
        "password:${backup.passwordFile}"
        "repository:${backup.repositoryFile}"
      ];
      CacheDirectory = "restic-offsite-restore";
      CacheDirectoryMode = "0700";
      RuntimeDirectory = "restic-offsite-restore";
      RuntimeDirectoryMode = "0700";
      TimeoutStartSec = "4h";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      UMask = "0077";
      # Only this small success marker needs root access to the textfile directory.
      ExecStartPost = "+${pkgs.writeShellScript "restic-restore-success" ''
        set -eu
        metric=/var/lib/restic-metrics/offsite-restore.prom
        tmp="$metric.tmp"
        trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT
        printf '# HELP yomi_restic_last_success_timestamp_seconds Unix timestamp of the last successful restic job.\n# TYPE yomi_restic_last_success_timestamp_seconds gauge\n' > "$tmp"
        printf 'yomi_restic_last_success_timestamp_seconds{host="inari",backup="offsite-restore"} %s\n' \
          "$(${pkgs.coreutils}/bin/date +%s)" >> "$tmp"
        ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$metric"
      ''}";
      ReadWritePaths = ["/var/lib/restic-metrics"];
    };
    script = ''
      set -euo pipefail
      export RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/password"
      export RESTIC_REPOSITORY_FILE="$CREDENTIALS_DIRECTORY/repository"
      export RESTIC_CACHE_DIR="$CACHE_DIRECTORY/restic"
      work="$CACHE_DIRECTORY/work"
      # CacheDirectory survives a killed run; discard its incomplete restore.
      rm -rf "$work"
      mkdir -p "$work"
      cleanup() {
        if [ -f "$work/pgdata/postmaster.pid" ]; then
          pg_ctl -D "$work/pgdata" -m immediate -w stop
        fi
        rm -rf "$work"
      }
      trap cleanup EXIT

      # Pin one snapshot so a concurrent backup cannot change 'latest' midway.
      snapshot=$(restic --retry-lock=30m snapshots --host inari --json | jq -er 'max_by(.time).id')
      restic --retry-lock=30m ls --json "$snapshot" /raid5pool/media/documents/originals > "$work/files.jsonl"
      document=$(jq -ser 'map(select(.type == "file" and .size > 0)) | first.path' "$work/files.jsonl")
      restic --retry-lock=30m dump "$snapshot" "$document" > "$work/document"
      test -s "$work/document"
      restic --retry-lock=30m dump "$snapshot" /persist/state/var/backup/postgresql/all.sql.zstd > "$work/all.sql.zstd"
      zstd --test "$work/all.sql.zstd"

      initdb -D "$work/pgdata" -U "$PGUSER" --auth=trust --no-locale
      pg_ctl -D "$work/pgdata" -l "$work/postgres.log" \
        -o "-c listen_addresses= -k $PGHOST -p $PGPORT -c shared_preload_libraries=${lib.escapeShellArg config.services.postgresql.settings.shared_preload_libraries}" -w start
      zstd -dc "$work/all.sql.zstd" | psql -X --set=ON_ERROR_STOP=1 --dbname=postgres > "$work/import.log" 2>&1 || {
        echo "PostgreSQL restore failed; inspect the dump in an isolated environment."
        exit 1
      }
      # An empty or truncated-but-valid SQL file must not count as recovery.
      for database in immich paperless; do
        count=$(psql -XAt --dbname="$database" -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")
        test "$count" -gt 0
      done
      echo "Restored one document and imported the PostgreSQL dump successfully."
    '';
  };
  systemd.timers.restic-offsite-restore = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-01 05:00:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
