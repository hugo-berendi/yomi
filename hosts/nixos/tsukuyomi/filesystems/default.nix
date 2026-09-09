_: {
  imports = [
    ../../common/filesystems
    (import ./partitions.nix {})
  ];

  yomi.filesystems.btrfs.enable = true;
}
