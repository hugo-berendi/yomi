{lib, ...}: {
  # The VPS disk has no serial/by-id link. Use its verified virtio PCI path.
  disko.devices.disk.system = {
    type = "disk";
    device = lib.mkDefault "/dev/disk/by-path/virtio-pci-0000:00:10.0";
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
