{disks ? ["/dev/nvme0n1"], ...}: {
  disko.devices = {
    # {{{ Disks
    disk = {
      x = {
        type = "disk";
        device = builtins.elemAt disks 0;
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            # {{{ Boot
            {
              name = "ESP";
              size = "512MiB";
              fs-type = "fat32";
              bootable = true;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            }
            # }}}
            # {{{ Swap
            {
              name = "swap";
              size = "16GiB";
              content = {
                type = "swap";
                resumeDevice = true;
              };
            }
            # }}}
            # {{{ Main
            {
              name = "zfs";
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            }
            # }}}
          ];
        };
      };
    };
    # }}}
    # {{{ zpools
    zpool = {
      zroot = {
        type = "zpool";
        mountpoint = "/";

        postCreateHook = ''
          zfs snapshot zroot@blank
          zfs set keylocation="prompt" "zroot";
        '';

        rootFsOptions = {
          compression = "lz4";
          "com.sun:auto-snapshot" = "false";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "file:///hermes/secrets/amaterasu/disk.key";
        };

        # {{{ Datasets
        datasets = {
          "root/persist/data" = {
            type = "zfs_fs";
            mountpoint = "/persist/data";
            options."com.sun:auto-snapshot" = "true";
          };
          "root/persist/state" = {
            type = "zfs_fs";
            mountpoint = "/persist/state";
            options."com.sun:auto-snapshot" = "true";
          };
          "root/local/nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
          };
          "root/local/cache" = {
            type = "zfs_fs";
            mountpoint = "/persist/local/cache";
          };
        };
        # }}}
      };
    };
    # }}}
  };
}
