{
  pkgs,
  config,
  ...
}: {
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
  # {{{ remote ssh unlocking
  boot = {
    initrd.network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        hostKeys = config.users.users.pilot.openssh.authorizedKeys.keyFiles;
        authorizedKeys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDGmx53uNl4i1KIJ/VH8v02qlLc/tCIL0GMTfVWaZKXCEygHtPSktB3KBPUE5Cax7/GtJDlsiLtSHgHwUdaiaYs9HCQh42aN6wA4S3fms+gmd0ptRq4O6MODchVoF3Bf3B+Er59ScXJ9j9n0/3JxhAVJqaHML8BwolulJm2ItMV1N5kt6sGrZ7a
HRJNdSff9AxmeqZHgQAk//dJnIPyGjZCPf+4rmc3ZQWtOjIlX92ywknYtFnE9HsRsF8NMpqWQeTPw0zd6SFcMA9l0sSnfsliDfVhWlDKODMcxTDlnafgyCEpg6ahqOgbmJPxRA9+cpNK8hQiKPJaJffqNtNfEY4+rIfsRwdGStGG+A1dCjUcEWG/uoKu6OY3xz84OhShzqeZegrQU+f1iSmWclW9
Jc6qtzWXREoIQIoJNw02W7Pcudkoi6dgd5rfFTICNqa8Q+3RakcJ2zfA07OiTj/4mPo+3LpOY4U4CxkFlGq+sYuHPIbJTKgIeVJ9cj2HojljjzxxIwGVfZ7lV2X5gSY8BZkPGi3qBWVULdnlG8CbMyf9PjPaAiugA1eJgzEpRrlaeVCOQ5qkfSYP+UInbwXTCigJjwdHjh/5kMmAccfCHNHCiyVP
0phohHiBvKlqcJYFROG1jXUeB71rde7w1iDvikrOIwhhLt8/KEOZ2aujAtM+vQ== openpgp:0x5972AAD9"
        ];
      };
      # postCommands = ''
      #   # Import all pools
      #   zpool import -a
      #   # Add the load-key command to the .profile
      #   echo "zfs load-key -a; killall zfs" >> /root/.profile
      # '';
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
