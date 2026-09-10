# Safety net and evidence collection, kept after the crash cause was traced to
# ZFS 2.4 (see ../filesystems/zfs.nix).
#
# The CPU and power workarounds that used to live here -- spec_rstack_overflow,
# nosmt, processor.max_cstate, idle=nomwait, amd_pstate=disable -- were aimed at
# the wrong culprit and are gone. This host ran for 22 months without any of
# them; each panic they were meant to fix was a downstream symptom of corrupted
# kernel memory.
{
  # Reboot instead of hanging, so the headless server recovers on its own.
  boot.kernelParams = ["panic=30"];
  boot.kernel.sysctl."kernel.panic_on_oops" = 1;

  # Record machine check exceptions and memory controller errors. Twenty-two
  # months of logs contain none, which is part of why the hardware theory was
  # dropped -- keep watching so that stays true.
  hardware.rasdaemon = {
    enable = true;
    record = true;
  };

  environment.persistence."/persist/state".directories = ["/var/lib/rasdaemon"];

  # A permanent rescue entry. Generation pruning eventually removes every older
  # boot entry, so the one configuration that survived hours of load needs to
  # live in the menu on its own terms.
  specialisation.rescue.configuration = {
    system.nixos.tags = ["rescue"];
    boot.kernelParams = ["maxcpus=1"];
  };

  # Offer memtest86+ straight from the boot menu, so a multi-hour memory test
  # needs no rescue USB stick.
  boot.loader.systemd-boot.memtest86.enable = true;
}
