{pkgs, ...}: {
  # Configure ZFS
  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;
  # This host ran without a single kernel BUG from 2024-10 to 2026-08-05 on the
  # 6.12 line with ZFS 2.3.x. The crashes started on the day it moved to ZFS
  # 2.4.2, beginning with a page fault inside zfs_lz4_compress and a "Bad page
  # state in process z_rd_int_1" -- ZFS corrupting page state, after which the
  # kernel died wherever it next touched the damage. Both are pinned back to
  # that known-good pairing; every pool feature in use is supported by 2.3.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.zfs.package = pkgs.zfs_2_3;
  boot.zfs.extraPools = ["zroot" "raid5pool"];

  # Cap ARC so ZFS memory pressure doesn't churn against cgroup v2 memory
  # accounting (root cause of the recurring memcg-path kernel panics)
  boot.extraModprobeConfig = "options zfs zfs_arc_max=8589934592";

  # The rollback below wipes /etc on every boot, so systemd would generate a
  # fresh machine ID each time. That silently orphaned the journal into a new
  # per-boot directory, which is why crash logs never survived a reboot.
  environment.persistence."/persist/state".files = ["/etc/machine-id"];

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
