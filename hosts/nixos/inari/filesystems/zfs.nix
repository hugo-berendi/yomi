{pkgs, ...}: {
  # Configure ZFS
  boot.supportedFilesystems = ["zfs"];
  # 6.12.102 contains the Safe-RET interrupt-injection fix and is used instead
  # of 6.18 while diagnosing the Rembrandt secondary-CPU startup panics.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.zfs.extraPools = ["zroot" "raid5pool"];
  boot.kernelParams = [
    "nohibernate"
    "spec_rstack_overflow=ibpb"
    "processor.max_cstate=1"
    "idle=nomwait"
    "amd_pstate=disable"
  ];

  # Cap ARC so ZFS memory pressure doesn't churn against cgroup v2 memory
  # accounting (root cause of the recurring memcg-path kernel panics)
  boot.extraModprobeConfig = "options zfs zfs_arc_max=8589934592";

  # {{{ Rollback
  boot.initrd.systemd.services.rollback = {
    path = [pkgs.zfs];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    unitConfig.DefaultDependencies = "no";
    wantedBy = ["initrd.target"];
    after = ["zfs-import.target"];
    before = ["sysroot.mount"];
    script = "zfs rollback -r zroot@blank";
  };
  # }}}
}
