{
  pkgs,
  config,
}: let
  appState = config.systemd.services.restic-app-state;
in
  pkgs.testers.runNixOSTest {
    name = "inari-app-state-zfs";
    nodes.machine = {
      networking.hostId = "1234abcd";
      virtualisation = {
        memorySize = 2048;
        emptyDiskImages = [1024 512];
      };
      boot.supportedFilesystems = ["zfs"];
      boot.kernelPackages = pkgs.linuxPackages_6_12;
      boot.zfs.package = pkgs.zfs_2_3;
      boot.zfs.forceImportRoot = false;
      boot.extraModprobeConfig = "options zfs zfs_arc_max=134217728";
      environment.systemPackages = [pkgs.python3 pkgs.sqlite];
      systemd.services.restic-app-state = {
        inherit (appState) script path unitConfig;
        environment = builtins.removeAttrs appState.environment ["PATH"];
        serviceConfig = builtins.removeAttrs appState.serviceConfig ["ExecStart"];
      };
    };
    testScript = ''
      import json
      import shlex

      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("printf 'synthetic-disk-key' > /run/disk.key")
      machine.succeed("zpool create -f -O mountpoint=/zfs-root -O encryption=aes-256-gcm -O keyformat=passphrase -O keylocation=file:///run/disk.key zroot /dev/vdb")
      machine.succeed("zfs create -o mountpoint=/root zroot/root")
      machine.succeed("zfs create -o mountpoint=/root/persist zroot/root/persist")
      machine.succeed("zfs create -p -o mountpoint=/persist/state zroot/root/persist/state")
      machine.succeed("zpool create -f -O mountpoint=/raid5pool raid5pool /dev/vdc")
      machine.succeed("mkdir -p /persist/state/var/backup")
      manifest = json.loads(machine.succeed("cat ${appState.environment.APP_STATE_SOURCES}"))
      for name, app in manifest.items():
          source = app["source"].replace("/run/restic-app-state/state", "/persist/state").replace("/run/restic-app-state/raid", "/raid5pool")
          machine.succeed("mkdir -p " + shlex.quote(source))
          machine.succeed("printf 'synthetic state' > " + shlex.quote(source + "/sentinel"))
          for filename in app.get("sqlite", []):
              path = source + "/" + filename
              machine.succeed("mkdir -p " + shlex.quote(path.rsplit("/", 1)[0]))
              machine.succeed("sqlite3 " + shlex.quote(path) + " 'CREATE TABLE fixture (id int); INSERT INTO fixture VALUES (37);'")
          machine.succeed("chmod 0700 " + shlex.quote(source))

      for _ in range(2):
          machine.succeed("systemctl start restic-app-state.service", timeout=120)
          for name in manifest:
              machine.succeed("test -f /persist/state/var/backup/app-state/" + shlex.quote(name) + "/sentinel")
          machine.fail("zfs list -t snapshot zroot/root/persist/state@yomi-app-state-backup")
          machine.fail("zfs list -t snapshot raid5pool@yomi-app-state-backup")
          machine.fail("findmnt -rn -t zfs | grep /run/restic-app-state/")

      # Force snapshot automount access to fail in the sandbox. Staging must
      # still read the explicit read-only mounts and preserve all sources.
      machine.succeed("mkdir -p /run/systemd/system/restic-app-state.service.d")
      machine.succeed("printf '[Service]\\nInaccessiblePaths=/persist/state/.zfs /raid5pool/.zfs\\n' > /run/systemd/system/restic-app-state.service.d/no-automount.conf")
      machine.succeed("systemctl daemon-reload; systemctl start restic-app-state.service", timeout=120)
      machine.succeed("test -f /persist/state/var/backup/app-state/calendar-sync/sentinel")

      machine.succeed("mv /persist/state/var/lib/vdirsyncer /persist/state/var/lib/calendar-missing")
      machine.fail("systemctl start restic-app-state.service", timeout=120)
      machine.succeed("test -f /persist/state/var/backup/app-state/calendar-sync/sentinel")
      machine.fail("zfs list -t snapshot zroot/root/persist/state@yomi-app-state-backup")
      machine.fail("zfs list -t snapshot raid5pool@yomi-app-state-backup")
      machine.fail("findmnt -rn -t zfs | grep /run/restic-app-state/")
      machine.succeed("mv /persist/state/var/lib/calendar-missing /persist/state/var/lib/vdirsyncer")
      machine.succeed("systemctl reset-failed restic-app-state.service; systemctl start restic-app-state.service", timeout=120)

      machine.succeed("journalctl -u restic-app-state.service --no-pager")
    '';
  }
