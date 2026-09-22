_: {
  # Nix unpacks, compiles and links inside `build-dir`, which defaults to
  # TMPDIR and therefore to /tmp. On this host /tmp is not a tmpfs -- nothing
  # sets boot.tmp.useTmpfs, so the NixOS default of `false` applies and /tmp is
  # the ZFS root, on the NVMe.
  #
  # That drive is the constraint here. It reported 100.4 TB written against a
  # ~110 TBW rating at 15,277 hours, and build scratch is the one large write
  # stream on the box that is never read back: it exists for the length of a
  # build and is then deleted, so it leaves no trace in any dataset's `written`
  # property and is invisible to per-service IO accounting.
  #
  # raid5pool takes it instead. The three IronWolf Pro drives idle at
  # 0.12 MiB/s with 13,727 hours, zero reallocated sectors and no media errors,
  # so they have both the headroom and the endurance to absorb it. Builds get
  # slower, because scratch is now on spinning disks and the finished result is
  # copied to the store across a filesystem boundary rather than renamed.
  #
  # Scratch is deliberately a plain directory rather than a dataset: it wants
  # no snapshots, no quota and no backup. yomi.restic.offsite.paths lists its
  # members one by one, so this cannot drift into a backup set by accident.
  #
  # The failure mode worth knowing: if raid5pool is not imported, tmpfiles
  # creates /raid5pool/nix-build on the root filesystem and scratch lands back
  # on the NVMe. That is exactly today's behaviour rather than a regression, so
  # this deliberately does not order nix-daemon after the mount -- needing nix
  # in order to repair a pool that nix refuses to run without is a worse trap
  # than a silent fallback to the status quo.
  systemd.tmpfiles.rules = ["d /raid5pool/nix-build 0755 root root -"];

  nix.settings.build-dir = "/raid5pool/nix-build";
}
