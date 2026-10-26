{
  pkgs,
  configuration,
}: let
  cfg = configuration.config;
  limit = cfg.boot.loader.systemd-boot.configurationLimit;
in
  pkgs.runCommand "${cfg.networking.hostName}-boot-space" {nativeBuildInputs = [pkgs.coreutils];} ''
    kernel=$(stat -Lc %s ${cfg.system.build.kernel}/bzImage)
    initrd=$(stat -Lc %s ${cfg.system.build.initialRamdisk}/initrd)
    # Both deployed ESPs are 512 MiB. Reserve one extra generation for
    # updates and 32 MiB for FAT overhead, the loader, and unlock material.
    # This is a conservative budget, not an inventory of historical initrds.
    limit=${toString limit}
    required=$(( (limit + 1) * (kernel + initrd) + 32 * 1024 * 1024 ))
    capacity=$((512 * 1024 * 1024))
    echo "${cfg.networking.hostName}: $limit entries require a budget of $required / $capacity bytes"
    if [ "$limit" -eq 0 ] || [ "$required" -gt "$capacity" ]; then
      echo "Boot artifacts exceed the 512 MiB ESP budget; lower configurationLimit or plan a partition expansion." >&2
      exit 1
    fi
    echo "$required" > "$out"
  ''
