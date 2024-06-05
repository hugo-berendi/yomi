{lib, ...}: {
  imports = [
    (import ./partitions.nix {})
  ];

  # Mark a bunch of paths as needed for boot
  fileSystems =
    lib.attrsets.genAttrs
    ["/" "/nix" "/persist" "/boot"]
    (p: {neededForBoot = true;});
}
