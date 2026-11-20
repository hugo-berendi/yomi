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
    description = "Restore a B2 document, an Immich original, Paperless and Kodama SQLite, Suwayomi H2 and PostgreSQL dump";
    wants = ["network-online.target"];
    after = ["network-online.target" "restic-backups-offsite.service" "restic-backups-offsite-check.service"];
    restartIfChanged = false;
    path = [backup.package pkgs.jq pkgs.zstd pkgs.sqlite pkgs.file pkgs.coreutils pkgs.jdk21_headless config.services.postgresql.finalPackage];
    environment = {
      PGHOST = "/run/restic-offsite-restore";
      PGPORT = "55432";
      PGUSER = "yomi_restore_admin";
      PAPERLESS_ORIGINALS = "${config.services.paperless.mediaDir}/documents/originals";
      IMMICH_ORIGINALS = config.services.immich.mediaLocation;
      # The server jar bundles the H2 engine and tools that wrote the database.
      SUWAYOMI_JAR = "${config.services.suwayomi-server.package.src}";
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
      ExecStartPost = "+${lib.getExe (pkgs.writeShellApplication {
        name = "restic-restore-success";
        runtimeInputs = [pkgs.coreutils];
        text = ''
          metric=/var/lib/restic-metrics/offsite-restore.prom
          tmp="$metric.tmp"
          trap 'rm -f "$tmp"' EXIT
          printf '# HELP yomi_restic_last_success_timestamp_seconds Unix timestamp of the last successful restic job.\n# TYPE yomi_restic_last_success_timestamp_seconds gauge\n' > "$tmp"
          printf 'yomi_restic_last_success_timestamp_seconds{host="inari",backup="offsite-restore"} %s\n' \
            "$(date +%s)" >> "$tmp"
          chmod 0644 "$tmp"
          mv -f "$tmp" "$metric"
        '';
      })}";
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
      rm -f "$CACHE_DIRECTORY/import-failure.log"
      mkdir -p "$work"
      cleanup() {
        if [ -f "$work/pgdata/postmaster.pid" ]; then
          pg_ctl -D "$work/pgdata" -m immediate -w stop
        fi
        rm -rf "$work"
      }
      trap cleanup EXIT

      # Pin one snapshot so a concurrent backup cannot change 'latest' midway.
      snapshot=$(restic --retry-lock=30m snapshots --host inari --tag app-state-v1 --json | jq -er 'max_by(.time).id')
      restic --retry-lock=30m ls --json "$snapshot" "$PAPERLESS_ORIGINALS" > "$work/files.jsonl"
      document=$(jq -ser 'map(select(.type == "file" and .size > 0)) | first.path' "$work/files.jsonl")
      restic --retry-lock=30m dump "$snapshot" "$document" > "$work/document"
      test -s "$work/document"
      restic --retry-lock=30m dump "$snapshot" /persist/state/var/backup/app-state/paperless/db.sqlite3 > "$work/paperless.sqlite3"
      test "$(sqlite3 -readonly "$work/paperless.sqlite3" 'PRAGMA integrity_check')" = ok
      count=$(sqlite3 -readonly "$work/paperless.sqlite3" 'SELECT count(*) FROM documents_document')
      test "$count" -gt 0
      restic --retry-lock=30m dump "$snapshot" /persist/state/var/backup/app-state/kodama/kodama.db > "$work/kodama.db"
      test "$(sqlite3 -readonly "$work/kodama.db" 'PRAGMA integrity_check')" = ok
      count=$(sqlite3 -readonly "$work/kodama.db" 'SELECT count(*) FROM plays')
      test "$count" -gt 0

      # Open the restored Suwayomi library with the server's own H2 version.
      # COUNT(*) comes from table metadata, so SCRIPT TO /dev/null reads every
      # row; damaged pages raise an MVStore error. Its result set is schema
      # DDL only. Shell continues after an error and exits 0, so check both.
      mkdir "$work/suwayomi"
      restic --retry-lock=30m dump "$snapshot" /persist/state/var/backup/app-state/suwayomi/database.mv.db > "$work/suwayomi/database.mv.db"
      if ! timeout 20m java -Xmx512m -XX:-UsePerfData -Djava.io.tmpdir="$work" -Duser.home="$work" \
        -cp "$SUWAYOMI_JAR" org.h2.tools.Shell \
        -url "jdbc:h2:file:$work/suwayomi/database;IFEXISTS=TRUE" -user "" -password "" \
        -sql "SCRIPT NOPASSWORDS NOSETTINGS TO '/dev/null'; SELECT (SELECT COUNT(*) FROM MANGA) > 0 AND (SELECT COUNT(*) FROM CHAPTER) > 0 AND (SELECT COUNT(*) FROM MIGRATIONS) > 0 AS RESTORE_OK" \
        > "$work/suwayomi.log" 2>&1 ||
        grep -q -e '^Error' -e '^Exception' "$work/suwayomi.log" ||
        [ "$(tail -n 2 "$work/suwayomi.log" | head -n 1)" != TRUE ]; then
        # Engine errors can contain application data.
        echo "Suwayomi H2 restore check failed (an empty library also fails)."
        exit 1
      fi

      # The photo library is what the off-site set exists for, and the weekly
      # check only reads a 5% sample of it. Restore one random original:
      # restic verifies every blob hash on the way out, and the size and type
      # catch an empty or truncated entry in the snapshot itself.
      restic --retry-lock=30m ls --recursive --json "$snapshot" "$IMMICH_ORIGINALS" \
        | jq -c 'select(.type == "file" and .size > 0 and (.path | test("/(library|upload)/")) and (.path | test("\\.xmp$"; "i") | not))' \
        > "$work/photos.jsonl"
      photo=$(shuf -n 1 "$work/photos.jsonl")
      test -n "$photo"
      restic --retry-lock=30m dump "$snapshot" "$(jq -r .path <<< "$photo")" > "$work/photo"
      test "$(stat -c %s "$work/photo")" = "$(jq -r .size <<< "$photo")"
      file --brief --mime-type "$work/photo" | grep -Eq '^(image|video)/'

      restic --retry-lock=30m dump "$snapshot" /persist/state/var/backup/postgresql/all.sql.zstd > "$work/all.sql.zstd"
      zstd --test "$work/all.sql.zstd"

      initdb -D "$work/pgdata" -U "$PGUSER" --auth=trust --no-locale
      pg_ctl -D "$work/pgdata" -l "$work/postgres.log" \
        -o "-c listen_addresses= -k $PGHOST -p $PGPORT -c shared_preload_libraries=${lib.escapeShellArg config.services.postgresql.settings.shared_preload_libraries}" -w start
      zstd -dc "$work/all.sql.zstd" | psql -X --set=ON_ERROR_STOP=1 --dbname=postgres > "$work/import.log" 2>&1 || {
        # SQL errors can contain application data, so keep the log private.
        install -m 0600 "$work/import.log" "$CACHE_DIRECTORY/import-failure.log"
        echo "PostgreSQL restore failed; inspect $CACHE_DIRECTORY/import-failure.log privately."
        exit 1
      }
      # An empty or truncated-but-valid SQL file must not count as recovery.
      count=$(psql -XAt --dbname=immich -c "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")
      test "$count" -gt 0
      echo "Restored one document and one Immich original, validated Paperless and Kodama SQLite and Suwayomi H2 and imported the PostgreSQL dump successfully."
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
