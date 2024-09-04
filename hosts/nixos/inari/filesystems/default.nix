{lib, ...}: {
  imports = [
    # ./zfs.nix
    # (import ./partitions.nix {})
    (import ./partitions-safe.nix {})
  ];

  # Mark a bunch of paths as needed for boot
  fileSystems =
    lib.attrsets.genAttrs
    ["/" "/nix" "/persist/data" "/persist/state" "/persist/local/cache" "/boot"]
    (_p: {neededForBoot = true;});
}
