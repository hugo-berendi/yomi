{lib, ...}: {
  # An intentionally nonexistent target prevents formatting an assumed /dev/vda.
  # Replace this with the disk identified in the VPS rescue system.
  disko.devices.disk.system = {
    type = "disk";
    device = lib.mkDefault "/dev/disk/by-id/REPLACE_WITH_NETCUP_DISK";
    content = {
      type = "gpt";
      partitions = {
        bios = {
          size = "1M";
          type = "EF02";
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
