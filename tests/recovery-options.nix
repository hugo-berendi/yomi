{
  pkgs,
  configuration,
}: let
  migrated =
    (configuration.extendModules {
      modules = [
        {
          yomi.inari = {
            rootDataset = "zroot/recovered";
            beelinkWorkarounds = false;
            tpmUnlock = true;
            lanInterface = "enp1s0";
            wifiInterface = null;
          };
        }
      ];
    }).config;
  manual =
    (configuration.extendModules {
      modules = [{yomi.inari.tpmUnlock = false;}];
    }).config;
  report = {
    root = migrated.fileSystems."/".device;
    state = migrated.fileSystems."/persist/state".device;
    rollback = migrated.boot.initrd.systemd.services.rollback.script;
    clevis = builtins.attrNames migrated.boot.initrd.clevis.devices;
    manualClevis = builtins.attrNames manual.boot.initrd.clevis.devices;
    lan = migrated.systemd.network.networks."30-eno1".matchConfig.Name;
    wifi = migrated.services.hostapd.enable;
    cpuWorkaround = builtins.hasAttr "online-stable-cpus" migrated.systemd.services;
    snapshots = builtins.attrNames migrated.services.sanoid.datasets;
  };
in
  assert report.root == "zroot/recovered";
  assert report.state == "zroot/recovered/root/persist/state";
  assert report.rollback == "zfs rollback -r zroot/recovered@blank";
  assert report.clevis == ["zroot/recovered"];
  assert report.manualClevis == [];
  assert report.lan == "enp1s0";
  assert !report.wifi;
  assert !report.cpuWorkaround;
  assert builtins.elem "zroot/recovered/root/persist/data" report.snapshots;
  assert builtins.elem "zroot/recovered/root/persist/state" report.snapshots;
    pkgs.writeText "yomi-recovery-options.json" (builtins.toJSON report)
