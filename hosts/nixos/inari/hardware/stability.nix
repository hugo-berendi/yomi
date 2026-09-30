# Safety net, evidence collection and containment for recurring kernel-memory
# corruption. EFI-pstore shows the failures in unrelated kernel paths across
# ZFS 2.3/2.4 and Linux 6.12/6.18, but every archived panic ran on logical CPU
# 4 or 5 -- the two SMT threads of one physical core.
{lib, ...}: {
  # Reboot instead of hanging, so the headless server recovers on its own.
  #
  # Every archived panic from both the 6.12 and 6.18 kernel lines occurred on
  # logical CPU 4 or 5. They are the two SMT threads of the same physical Zen
  # 3+ core. maxcpus limits a count, not logical CPU IDs: maxcpus=4 booted
  # with CPU 4 online. Start with only the boot CPU, then explicitly bring
  # up the safe threads. This keeps the suspect core out of early boot too.
  boot.kernelParams = [
    "panic=30"
    "maxcpus=1"
  ];
  boot.kernel.sysctl."kernel.panic_on_oops" = 1;

  systemd.services.online-stable-cpus = {
    description = "Bring known-good Inari CPU cores online";
    wantedBy = ["sysinit.target"];
    before = ["basic.target"];
    # CPU hotplug is boot containment. Applying a configuration while this
    # server is running must not change the CPUs underneath its services.
    restartIfChanged = false;
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      # Reconcile an unexpected starting state before enabling safe threads.
      for cpu in 4 5; do
        online="/sys/devices/system/cpu/cpu$cpu/online"
        state=$(cat "$online")
        if [[ "$state" != 0 ]]; then
          echo 0 > "$online"
        fi
        test "$(cat "$online")" = 0
      done
      for cpu in 1 2 3 6 7 8 9 10 11; do
        online="/sys/devices/system/cpu/cpu$cpu/online"
        state=$(cat "$online")
        if [[ "$state" != 1 ]]; then
          echo 1 > "$online"
        fi
        test "$(cat "$online")" = 1
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
    systemd.services.online-stable-cpus.enable = lib.mkForce false;
  };

  # Offer memtest86+ straight from the boot menu, so a multi-hour memory test
  # needs no rescue USB stick.
  boot.loader.systemd-boot.memtest86.enable = true;
}
