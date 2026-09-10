# Stability workarounds for Inari's AMD Rembrandt platform.
#
# Kernel panics have been observed in completely unrelated subsystems
# (srso_alias_safe_ret, __nf_conntrack_find_get, start_secondary via
# pv_native_safe_halt, avl_walk in zfs) across both Linux 6.12 and 6.18.
# Only maxcpus=1 ever survived hours of sustained load, which points at the
# platform rather than at a single kernel bug.
{
  boot.kernelParams = [
    # AMD's Safe-RET SRSO mitigation crashed reproducibly here; IBPB is an
    # equally complete mitigation without that code path.
    "spec_rstack_overflow=ibpb"

    # Halve the parallel memory pressure while the fault is being isolated.
    "nosmt"

    # Conservative AMD power management.
    "processor.max_cstate=1"
    "idle=nomwait"
    "amd_pstate=disable"

    # Reboot instead of hanging, so the headless server recovers without a
    # physical reset.
    "panic=30"
  ];

  boot.kernel.sysctl."kernel.panic_on_oops" = 1;

  # Record machine check exceptions and memory controller errors so hardware
  # faults show up as data instead of as random kernel panics.
  hardware.rasdaemon = {
    enable = true;
    record = true;
  };

  environment.persistence."/persist/state".directories = ["/var/lib/rasdaemon"];

  # Offer memtest86+ straight from the boot menu, so a multi-hour memory test
  # needs no rescue USB stick.
  boot.loader.systemd-boot.memtest86.enable = true;
}
