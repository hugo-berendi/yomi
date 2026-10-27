_: {
  imports = [
    (import ./partitions.nix {})
  ];

  yomi.filesystems.btrfs.enable = true;
}
