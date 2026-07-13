{
  config,
  lib,
  ...
}: {
  options.yomi.filesystems = {
    persistPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/" "/nix" "/persist/data" "/persist/state" "/persist/local/cache" "/boot"];
      description = "Paths to mark as neededForBoot";
    };

    btrfs = {
      enable = lib.mkEnableOption "BTRFS rollback and autoScrub";

      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/mapper/crypted";
        description = "Decrypted device path for BTRFS rollback";
      };
    };
  };

  config = {
    fileSystems =
      lib.attrsets.genAttrs config.yomi.filesystems.persistPaths
      (_p: {neededForBoot = true;});

    boot.supportedFilesystems = lib.mkIf config.yomi.filesystems.btrfs.enable ["btrfs"];
    services.btrfs.autoScrub.enable = lib.mkIf config.yomi.filesystems.btrfs.enable true;

    boot.initrd.systemd.services.rollback = lib.mkIf config.yomi.filesystems.btrfs.enable {
      description = "Rollback BTRFS root subvolume to a pristine state";
      wantedBy = ["initrd.target"];
      after = ["systemd-cryptsetup@crypted.service"];
      before = ["sysroot.mount"];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt

        mount -o subvol=/ ${config.yomi.filesystems.btrfs.device} /mnt

        btrfs subvolume list -o /mnt/root |
          cut -f9 -d' ' |
          while read subvolume; do
            echo "deleting /$subvolume subvolume..."
            btrfs subvolume delete "/mnt/$subvolume"
          done &&
          echo "deleting /root subvolume..." &&
          btrfs subvolume delete /mnt/root

        echo "restoring blank /root subvolume..."
        btrfs subvolume snapshot /mnt/blank /mnt/root

        umount /mnt
      '';
    };
  };
}
