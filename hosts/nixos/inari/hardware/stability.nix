# Safety net, evidence collection and containment for recurring kernel-memory
# corruption. EFI-pstore shows the failures in unrelated kernel paths across
# ZFS 2.3/2.4 and Linux 6.12/6.18, but every archived panic ran on logical CPU
# 4 or 5 -- the two SMT threads of one physical core.
{lib, ...}: {
  # Reboot instead of hanging, so the headless server recovers on its own.
  #
  # Every archived panic from both the 6.12 and 6.18 kernel lines occurred on
  # logical CPU 4 or 5. They are the two SMT threads of the same physical Zen
  # 3+ core. Start with CPUs 0-3 only so that core can never execute during
  # early boot; the service below then brings the other known-good cores
  # online while deliberately leaving 4 and 5 disabled.
  boot.kernelParams = [
    "panic=30"
    "maxcpus=4"
  ];
  boot.kernel.sysctl."kernel.panic_on_oops" = 1;

  systemd.services.online-stable-cpus = {
    description = "Bring known-good Inari CPU cores online";
    wantedBy = ["sysinit.target"];
    before = ["basic.target"];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      for cpu in 6 7 8 9 10 11; do
        online="/sys/devices/system/cpu/cpu$cpu/online"
        if [[ -w "$online" ]]; then
          echo 1 > "$online"
        fi
      done
    '';
  };

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
    boot.kernelParams = lib.mkAfter ["maxcpus=1"];
    systemd.services.online-stable-cpus.wantedBy = lib.mkForce [];
  };

  # Offer memtest86+ straight from the boot menu, so a multi-hour memory test
  # needs no rescue USB stick.
  boot.loader.systemd-boot.memtest86.enable = true;
}
