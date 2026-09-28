_: {
  # Nix unpacks, compiles and links inside `build-dir`, which defaults to
  # TMPDIR and therefore to /tmp. On this host /tmp is not a tmpfs -- nothing
  # sets boot.tmp.useTmpfs -- so it is the ZFS root, on the NVMe.
  #
  # That drive is the constraint here. It reported 100.4 TB written against a
  # ~110 TBW rating at 15,277 hours, and build scratch is the one large write
  # stream on the box that is never read back: it exists for the length of a
  # build and is then deleted, so it leaves no trace in any dataset's `written`
  # property and is invisible to per-service IO accounting.
  #
  # Scratch first moved to /raid5pool, which saved the NVMe but made the
  # node builds unusable. n8n (unfree, so never in cache.nixos.org) and the
  # OIDC seerr fork build here, and pnpmConfigHook's patchShebangs reads the
  # head of every executable in node_modules. On raidz1 spinning disks that
  # random-read load sat at ~120 IOPS per disk with IO pressure 40% "full";
  # the flake-update check took 162 minutes against a 180 minute CI timeout,
  # with 7 minutes of CPU time.
  #
  # So scratch lives in RAM. The cap turns a runaway build into ENOSPC rather
  # than an OOM: swap is zram, already holding ~13 GB, and the ARC takes up
  # to 8 GiB. The largest local build, n8n, unpacks 2.1 GB of pnpm deps, so
  # 16G leaves room for two heavy builds side by side.
  #
  # If the mount fails, /nix/build is a plain directory on zroot and scratch
  # lands on the NVMe again -- slower wear, not a broken nix-daemon.
  fileSystems."/nix/build" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=16G" "mode=0755" "noatime"];
  };

  nix.settings.build-dir = "/nix/build";

  # /raid5pool itself is 1777 on disk -- world-writable with a sticky bit,
  # like /tmp -- leftover state from however the pool was first made. Nothing
  # needs that, and every directory under it is created by an explicit rule
  # with its own owner and mode. Group-writable trees like /raid5pool/media
  # (2775 root:media) keep their own modes.
  systemd.tmpfiles.rules = [
    "d /raid5pool 0755 root root -"
  ];
}
