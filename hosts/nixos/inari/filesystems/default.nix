_: {
  imports = [
    ./zfs.nix
    (import ./partitions.nix {})
  ];
}
