{
  pkgs,
  config,
  lib,
  ...
}:
{
  # {{{ ZFS config
  services.zfs = {
    trim = {
      # Temporarily disabled while investigating kernel panics observed during
      # ZFS I/O. Re-enable after the system is stable without rescue settings.
      enable = false;
    };
    autoScrub = {
      enable = true;
      interval = "weekly";
    };
    zed = {
      settings = {
        ZED_DEBUG_LOG = "/tmp/zed.debug.log";
        ZED_EMAIL_ADDR = [ "alert@hugo-berendi.de" ];
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
  boot.kernelParams = [ "ip=dhcp" ];
  boot.initrd = {
    availableKernelModules = [ "r8169" ];
    # Unlock the encrypted root pool using a random key sealed to Inari's TPM.
    # The JWE contains no plaintext key and is only usable with this TPM.
    clevis = {
      enable = true;
      devices.zroot.secretFile = ../filesystems/zroot-key.jwe;
    };
    network = {
      enable = true;
      ssh = {
        enable = true;
        port = 2222;
        authorizedKeys = lib.map (
          path: toString path
        ) config.users.users.${config.yomi.pilot.name}.openssh.authorizedKeys.keyFiles;
        hostKeys = [ "/etc/secrets/initrd/ssh_host_rsa_key" ];
      };
    };
  };
  # Keep the normal credential request enabled as a recovery fallback if TPM
  # unlocking fails. The active ZFS key is backed up, Age-encrypted, next to
  # the TPM JWE as zroot-recovery-key.age.
  boot.zfs.requestEncryptionCredentials = true;
  environment.persistence."/persist/state".directories = [ "/etc/secrets/initrd" ];
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

    # Snapshots for system state on zroot (includes databases like Immich)
    datasets."zroot/root/persist/state" = {
      autosnap = true;
      autoprune = true;
      recursive = true;
      yearly = 0;
      monthly = 6;
      weekly = 4;
      daily = 7;
      hourly = 24;
    };
  };
  # }}}
}
