_: {
  disko.devices = {
    disk.x = {
      type = "disk";
      device = "/dev/yomi-recovery-disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            label = "yomi-recovery-ESP";
            device = "/dev/yomi-recovery-esp";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          zfs = {
            size = "100%";
            label = "yomi-recovery-zfs";
            device = "/dev/yomi-recovery-zfs";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
        };
      };
    };
    zpool.zroot = {
      type = "zpool";
      options = {
        ashift = "12";
        compatibility = "openzfs-2.3-linux";
      };
      rootFsOptions.mountpoint = "none";
    };
  };
}
