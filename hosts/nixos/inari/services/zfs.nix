{pkgs, ...}: {
  # {{{ Zfs config
  services.zfs = {
    trim.enable = true;
    autoScrub.enable = true;
    zed = {
      # enableMail = true;

      settings = {
        ZED_DEBUG_LOG = "/tmp/zed.debug.log";
        ZED_EMAIL_ADDR = ["root"];
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
  # {{{ Sanoid config
  # Sanoid allows me to configure snapshot frequency on a per-dataset basis.
  services.sanoid = {
    enable = true;

    # {{{ Data
    datasets."zroot/root/persist/data" = {
      autosnap = true;
      autoprune = true;
      recursive = true;
      yearly = 0;
      monthly = 12;
      weekly = 4;
      daily = 7;
      hourly = 24;
    };
    # }}}
    # {{{ State
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
    # }}}
  };
  # }}}
  # {{{ Syncoid
  # Automatically sync certain snapshot to rsync.net
  # services.syncoid = {
  #   enable = true;
  #   commands."zroot/root/persist/data".target = "root@rsync.net:zroot/root/persist/data";
  #   commands."zroot/root/persist/state".target = "root@rsync.net:zroot/root/persist/state";
  # };
  # }}}
}
