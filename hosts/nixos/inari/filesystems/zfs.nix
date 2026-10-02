{
  config,
  lib,
  pkgs,
  ...
}: let
  root = config.yomi.inari.rootDataset;
in {
  options.yomi.inari.rootDataset = lib.mkOption {
    type = lib.types.enum ["zroot" "zroot/recovered"];
    default = "zroot";
    description = "Encryption root and dataset prefix, including raw ZFS recovery beneath a fresh pool.";
  };

  config = {
    # Raw encrypted replication cannot replace Disko's encrypted root dataset.
    # A received child retains its key, snapshots and rollback baseline.
    fileSystems = lib.mkIf (root != "zroot") (lib.mapAttrs (_: suffix: {
        device = lib.mkForce "${root}${suffix}";
      }) {
        "/" = "";
        "/nix" = "/root/local/nix";
        "/persist/local/cache" = "/root/local/cache";
        "/persist/data" = "/root/persist/data";
        "/persist/state" = "/root/persist/state";
      });
    # Configure ZFS
    boot.supportedFilesystems = ["zfs"];
    boot.zfs.forceImportRoot = false;
    # The first crashes coincided with the ZFS 2.4.2 upgrade and included faults
    # in ZFS code. Later EFI-pstore evidence showed the same corruption with ZFS
    # 2.3 across unrelated kernel paths, always on one physical CPU core. Keep
    # this conservative pairing while the hardware/firmware fault is isolated;
    # every pool feature in use is supported by 2.3.
    boot.kernelPackages = pkgs.linuxPackages_6_12;
    boot.zfs.package = pkgs.zfs_2_3;
    boot.zfs.extraPools = ["zroot" "raid5pool"];

    # Cap ARC to reduce memory pressure while the kernel crashes are investigated.
    boot.extraModprobeConfig = "options zfs zfs_arc_max=8589934592";

    # The rollback below wipes /etc on every boot, so systemd would generate a
    # fresh machine ID each time. That silently orphaned the journal into a new
    # per-boot directory, which is why crash logs never survived a reboot.
    environment.persistence."/persist/state".files = ["/etc/machine-id"];

    # {{{ Rollback
    boot.initrd.systemd.services.rollback = {
      path = [pkgs.zfs];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      unitConfig.DefaultDependencies = "no";
      wantedBy = ["initrd.target"];
      after = ["zfs-import.target"];
      before = ["sysroot.mount"];
      script = "zfs rollback -r ${root}@blank";
    };
    # }}}
  };
}
