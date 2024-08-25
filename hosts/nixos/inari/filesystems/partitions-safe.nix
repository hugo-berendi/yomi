{disks ? ["/dev/sda"], ...}: {
  disko.devices = {
    # {{{ Disks
    disk = {
      x = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "gpt";
          partitions = {
            # {{{ Boot
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "128M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            # }}}
            # {{{ Root
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/rootfs" = {
                    mountpoint = "/";
                  };
                  "root/persist/data" = {
                    mountpoint = "/persist/data";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "root/persist/state" = {
                    mountpoint = "/persist/state";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "root/local/nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                  "root/local/cache" = {
                    mountpoint = "/persist/local/cache";
                    mountOptions = ["compress=zstd" "noatime"];
                  };
                };

                mountpoint = "/partition-root";
              };
            };
            # }}}
          };
        };
      };
    };
    # }}}
  };
}
