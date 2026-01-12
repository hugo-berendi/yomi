{disks ? ["/dev/nvme0n1"], ...}: {
  disko.devices.disk.main = {
    type = "disk";
    device = builtins.elemAt disks 0;
    content = {
      type = "gpt";
      partitions = {
        # {{{ Boot
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "defaults"
              "umask=077"
            ];
          };
        };
        # }}}
        # {{{ Luks
        luks = {
          size = "100%"; # The remaining space is left for windows
          content = {
            type = "luks";
            name = "crypted";
            passwordFile = "/tmp/disk.key";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = ["-f"];

              subvolumes = {
                # {{{ /
                "root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # }}}
                # {{{ /blank
                "blank" = {
                  mountpoint = "/blank";
                  # should we reuse the `root` options here?
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # }}}
                # {{{ /swap
                "swap" = {
                  mountpoint = "/.swapvol";
                  swap.swapfile.size = "16G";
                };
                # }}}
                # {{{ /persist/data
                "persist-data" = {
                  mountpoint = "/persist/data";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # }}}
                # {{{ /persist/state
                "persist-state" = {
                  mountpoint = "/persist/state";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # }}}
                # {{{ /local/nix
                "local-nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # }}}
                # {{{ /local/cache
                "local-cache" = {
                  mountpoint = "/persist/local/cache";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # }}}
              };
            };
          };
        };
        # }}}
      };
    };
  };
}
