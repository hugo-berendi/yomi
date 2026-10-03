{
  pkgs,
  config,
}: let
  restore = config.systemd.services.restic-offsite-restore;
  appState = config.systemd.services.restic-app-state;
  appStateScript = pkgs.writeShellScript "app-state-fixture" appState.script;
  restoreScript = pkgs.writeShellScript "restore-fixture" (builtins.replaceStrings
    ["/raid5pool/" "/persist/state/"]
    ["$FIXTURE/raid5pool/" "$FIXTURE/persist/state/"]
    restore.script);
in
  pkgs.runCommand "yomi-recovery-checks" {
    nativeBuildInputs = restore.path ++ [pkgs.python3 pkgs.sqlite pkgs.coreutils];
  } ''
    python3 ${./app-state.py} ${../hosts/nixos/inari/services/restic/app-state.py} ${appStateScript} ${appState.environment.APP_STATE_SOURCES}
    export FIXTURE="$TMPDIR/fixture"
    export CREDENTIALS_DIRECTORY="$TMPDIR/credentials"
    export CACHE_DIRECTORY="$TMPDIR/restore-cache"
    export PGUSER=yomi_restore_admin
    export PGPORT=55432
    export PGHOST="$TMPDIR/restore-socket"
    export PAPERLESS_ORIGINALS="$FIXTURE${restore.environment.PAPERLESS_ORIGINALS}"
    mkdir -p "$CREDENTIALS_DIRECTORY" "$CACHE_DIRECTORY" "$PGHOST" "$TMPDIR/source-socket"
    printf 'synthetic-test-password' > "$CREDENTIALS_DIRECTORY/password"
    printf '%s' "$TMPDIR/repository" > "$CREDENTIALS_DIRECTORY/repository"
    export RESTIC_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/password"
    export RESTIC_REPOSITORY_FILE="$CREDENTIALS_DIRECTORY/repository"
    restic init

    mkdir -p "$FIXTURE/raid5pool/media/documents/documents/originals" \
      "$FIXTURE/persist/state/var/backup/postgresql" \
      "$FIXTURE/persist/state/var/backup/app-state/paperless"
    printf 'synthetic original document' > "$FIXTURE/raid5pool/media/documents/documents/originals/document.pdf"
    sqlite3 "$FIXTURE/persist/state/var/backup/app-state/paperless/db.sqlite3" \
      'CREATE TABLE documents_document (id INTEGER PRIMARY KEY); INSERT INTO documents_document VALUES (1);'
    initdb -D "$TMPDIR/source-pg" -U postgres --auth=trust --no-locale > /dev/null
    pg_ctl -D "$TMPDIR/source-pg" -l "$TMPDIR/source-pg.log" \
      -o "-c listen_addresses= -k $TMPDIR/source-socket -p 55431" -w start
    trap 'pg_ctl -D "$TMPDIR/source-pg" -m immediate -w stop >/dev/null 2>&1 || true' EXIT
    psql -h "$TMPDIR/source-socket" -p 55431 -U postgres -d postgres -c 'CREATE DATABASE immich'
    psql -h "$TMPDIR/source-socket" -p 55431 -U postgres -d immich -c 'CREATE TABLE fixture (id int); INSERT INTO fixture VALUES (1);'
    pg_dumpall -h "$TMPDIR/source-socket" -p 55431 -U postgres | zstd > "$FIXTURE/persist/state/var/backup/postgresql/all.sql.zstd"
    pg_ctl -D "$TMPDIR/source-pg" -m fast -w stop
    restic backup --host inari --tag app-state-v1 "$FIXTURE"
    ${restoreScript}
    test ! -e "$CACHE_DIRECTORY/work"
    ${restoreScript}
    test ! -e "$CACHE_DIRECTORY/work"
    cp "$FIXTURE/persist/state/var/backup/postgresql/all.sql.zstd" "$TMPDIR/valid.sql.zstd"
    zstd -dc "$TMPDIR/valid.sql.zstd" > "$TMPDIR/missing-extension.sql"
    printf '\nCREATE EXTENSION definitely_missing_restore_fixture;\n' >> "$TMPDIR/missing-extension.sql"
    zstd -c "$TMPDIR/missing-extension.sql" > "$FIXTURE/persist/state/var/backup/postgresql/all.sql.zstd"
    restic backup --host inari --tag app-state-v1 "$FIXTURE"
    if ${restoreScript}; then
      echo 'Missing PostgreSQL extension counted as successful recovery' >&2
      exit 1
    fi
    test ! -e "$CACHE_DIRECTORY/work"
    test "$(stat -c %a "$CACHE_DIRECTORY/import-failure.log")" = 600
    grep -F 'extension "definitely_missing_restore_fixture" is not available' "$CACHE_DIRECTORY/import-failure.log"
    cp "$TMPDIR/valid.sql.zstd" "$FIXTURE/persist/state/var/backup/postgresql/all.sql.zstd"
    restic backup --host inari --tag app-state-v1 "$FIXTURE"
    ${restoreScript}
    test ! -e "$CACHE_DIRECTORY/work"
    test ! -e "$CACHE_DIRECTORY/import-failure.log"
    # Valid SQLite with the wrong application schema must not count as recovery.
    sqlite3 "$FIXTURE/persist/state/var/backup/app-state/paperless/db.sqlite3" 'DROP TABLE documents_document; CREATE TABLE unrelated (id int);'
    restic backup --host inari --tag app-state-v1 "$FIXTURE"
    if ${restoreScript}; then
      echo 'Wrong Paperless schema counted as successful recovery' >&2
      exit 1
    fi
    test ! -e "$CACHE_DIRECTORY/work"
    echo 'App-state, restic, PostgreSQL and Paperless SQLite recovery checks passed' > "$out"
  ''
