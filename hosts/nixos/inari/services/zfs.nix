{
  pkgs,
  config,
  lib,
  ...
}: {
  # {{{ ZFS config
  services.zfs = {
    trim = {
      enable = true;
    };
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    zed = {
      settings = {
        ZED_DEBUG_LOG = "/tmp/zed.debug.log";
        ZED_EMAIL_ADDR = ["alert@hugo-berendi.de"];
        ZED_EMAIL_PROG = "${pkgs.msmtp}/bin/msmtp";
        ZED_EMAIL_OPTS = "@ADDRESS@";

        ZED_NOTIFY_INTERVAL_SECS = 3600;
        ZED_NOTIFY_VERBOSE = true;

        ZED_USE_ENCLOSURE_LEDS = true;
        ZED_SCRUB_AFTER_RESILVER = true;
      };
    };
  };
  # }}}
  # {{{ Remote SSH unlocking
  boot.kernelParams = ["ip=dhcp"];
  boot.initrd = {
    availableKernelModules = ["r8169"];
    systemd.users.root.shell = "/bin/cryptsetup-askpass";
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        authorizedKeys = lib.map (path: toString path) config.users.users.pilot.openssh.authorizedKeys.keyFiles;
        hostKeys = ["/etc/secrets/initrd/ssh_host_rsa_key"];
      };
    };
  };
  environment.persistence."/persist/state".directories = ["/etc/secrets/initrd"];
  # }}}
  # {{{ Sanoid
  services.sanoid = {
    enable = true;

    # Snapshot actual data on raid5pool
    datasets."raid5pool" = {
      autosnap = true;
      autoprune = true;
      recursive = true;
      yearly = 0;
      monthly = 12;
      weekly = 4;
      daily = 7;
      hourly = 24;
    };

    # Minimal snapshots for system state on zroot
    datasets."zroot/root/persist/state" = {
      autosnap = true;
      autoprune = true;
      recursive = true;
      yearly = 0;
      monthly = 1;
      weekly = 1;
      daily = 3;
      hourly = 6;
    };
  };
  # }}}
}
