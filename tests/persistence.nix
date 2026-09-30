{
  pkgs,
  configurations,
}: let
  inherit (pkgs) lib;
  wsl = configurations.wsl.config;
  fixture =
    (configurations.inari.extendModules {
      modules = [
        {
          home-manager.users.hugob.yomi.persistence.at = {
            state.apps.fixture = {
              name = "fixture-renamed";
              directories = [".fixture"];
              files = [".fixture-file"];
              excludeFromLocalBackups = true;
            };
            custom = {
              path = "/persist/state/plain";
              prefixDirectories = false;
              apps = {
                fixture = {
                  directories = [".fixture-unprefixed"];
                  excludeFromLocalBackups = true;
                };
                kept.directories = [".fixture-kept"];
              };
            };
          };
        }
      ];
    }).config;
  homeOf = c: c.home-manager.users.${c.yomi.pilot.name};
  directories = home: lib.concatMap (p: p.directories) (lib.attrValues home.home.persistence);
  excludedDirectories = home: let
    paths = map (p:
      if lib.hasPrefix "/" p
      then p
      else "${home.home.homeDirectory}/${p}") (
      [home.xdg.userDirs.extraConfig.PROJECTS]
      ++ lib.concatMap (app: home.yomi.persistence.at.state.apps.${app}.directories or []) ["steam" "discord"]
    );
  in
    lib.filter (d: lib.elem d.dirPath paths) (directories home);
  checks =
    [
      {
        name = "WSL has no system persistence entries";
        assertion = wsl.environment.persistence == {};
      }
      {
        name = "WSL has no home persistence entries";
        assertion = (homeOf wsl).home.persistence == {};
      }
      {
        name = "WSL generates no persistence mounts";
        assertion = !lib.any (m: lib.hasPrefix "/persist/" m.what) wsl.systemd.mounts;
      }
      {
        name = "WSL host keys use its persistent root filesystem";
        assertion = lib.all (key: lib.hasPrefix "/etc/ssh/" key.path) wsl.services.openssh.hostKeys;
      }
      {
        name = "WSL does not create unused persistence directories";
        assertion = !lib.any (rule: lib.hasInfix "/persist/" rule) wsl.systemd.tmpfiles.rules;
      }
      {
        name = "exclusions follow renamed, unprefixed and file persistence entries";
        assertion = lib.all (path: lib.elem path fixture.services.restic.backups.state.exclude) [
          "/persist/state/fixture-renamed/home/hugob/.fixture"
          "/persist/state/fixture-renamed/home/hugob/.fixture-file"
          "/persist/state/plain/home/hugob/.fixture-unprefixed"
        ];
      }
      {
        name = "other application state remains included";
        assertion = !lib.elem "/persist/state/plain/home/hugob/.fixture-kept" fixture.services.restic.backups.state.exclude;
      }
    ]
    ++ lib.concatMap (host: let
      c = configurations.${host}.config;
      home = homeOf c;
      excludes = c.services.restic.backups.data.exclude ++ c.services.restic.backups.state.exclude;
    in [
      {
        name = "${host} retains system and home persistence";
        assertion = c.environment.persistence != {} && home.home.persistence != {};
      }
      {
        name = "${host} exclusions select the actual mount sources";
        assertion = lib.all (d: lib.elem (d.persistentStoragePath + d.dirPath) excludes) (excludedDirectories home);
      }
    ]) ["amaterasu" "inari"];
  failures = map (c: c.name) (lib.filter (c: !c.assertion) checks);
  desktop = configurations.amaterasu.config;
  excludes = desktop.services.restic.backups.data.exclude ++ desktop.services.restic.backups.state.exclude;
  exclusionFile = pkgs.writeText "persistence-backup-excludes" (lib.concatStringsSep "\n" excludes);
  excludedFiles = map (d: d.persistentStoragePath + d.dirPath + "/excluded-fixture") (excludedDirectories (homeOf desktop));
in
  assert lib.assertMsg (failures == []) ("Persistence regression checks failed: " + lib.concatStringsSep ", " failures);
    pkgs.runCommand "yomi-persistence-checks" {nativeBuildInputs = [pkgs.restic pkgs.jq];} ''
      export RESTIC_REPOSITORY="$TMPDIR/repository"
      export RESTIC_CACHE_DIR="$TMPDIR/cache"
      export RESTIC_PASSWORD=synthetic-persistence-test
      restic init
      mkdir -p "$TMPDIR/persist/data/fixture" "$TMPDIR/persist/state/fixture"
      echo 'included data' > "$TMPDIR/persist/data/fixture/included-data"
      echo 'included state' > "$TMPDIR/persist/state/fixture/included-state"
      for file in ${lib.escapeShellArgs excludedFiles}; do
        path="$TMPDIR$file"
        mkdir -p "$(dirname "$path")"
        echo 'excluded application' > "$path"
      done
      sed "s|/persist/|$TMPDIR/persist/|g" ${exclusionFile} > "$TMPDIR/excludes"
      restic backup --exclude-file "$TMPDIR/excludes" "$TMPDIR/persist"
      restic ls --json latest > "$TMPDIR/files.jsonl"
      jq -s -e '
        [ .[] | select(.type == "file") | .path | split("/") | last ] | sort
        == ["included-data", "included-state"]
      ' "$TMPDIR/files.jsonl" >/dev/null
      echo 'WSL mounts and real Restic exclusion checks passed' > "$out"
    ''
