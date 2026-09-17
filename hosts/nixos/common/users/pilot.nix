{
  pkgs,
  outputs,
  config,
  lib,
  ...
}: {
  sops.secrets.pilot_password = {
    sopsFile = ../secrets.yaml;
    neededForUsers = true;
  };

  users = {
    # Configure users through nix only
    mutableUsers = false;

    # Sync up root and `pilot` shell
    users.root = {
      shell = config.users.users.${config.yomi.pilot.name}.shell;
      hashedPasswordFile = config.sops.secrets.pilot_password.path;
    };

    users.${config.yomi.pilot.name} = {
      inherit (config.yomi.pilot) name;

      description = "Hugo Berendi";

      # Adds me to some default groups, and creates the home dir
      isNormalUser = true;

      # Picked up by our persistence module
      homeMode = "0700";

      # Add user to the following groups
      extraGroups = [
        "wheel" # Access to sudo
        "lp" # Printers
        "audio" # Audio devices
        "video" # Webcam and the like
        "network" # wpa_supplicant
        "syncthing" # syncthing!
        "vboxusers"

        # Read the system journal without sudo. wheelNeedsPassword is on, so
        # every `journalctl -u <service>` otherwise needs a password, which
        # makes reading logs the slowest part of diagnosing anything. Grants no
        # privilege this user does not already have through wheel -- but note
        # it also gives log access to everything running as this user, and logs
        # carry tokens and request data.
        "systemd-journal"
      ];

      hashedPasswordFile = config.sops.secrets.pilot_password.path;
      shell = pkgs.fish;

      openssh.authorizedKeys.keyFiles =
        (import ./common.nix).authorizedKeys {inherit outputs lib;};
    };
  };

  programs.nix-ld.enable = true;

  # {{{ Set user-specific ssh permissions
  # This is mainly useful because home-manager can often fail if the perms on
  # `~/.ssh` are incorrect.
  systemd.tmpfiles.rules = let
    user = config.users.users.${config.yomi.pilot.name};
    root = "/persist/state/${user.home}/ssh";
  in [
    "d ${root}                 0755 ${user.name} ${user.group}"
    "d ${root}/.ssh            0755 ${user.name} ${user.group}"
    "z ${root}/.ssh/id_*.pub   0755 ${user.name} ${user.group}"
    "z ${root}/.ssh/id_rsa     0700 ${user.name} ${user.group}"
    "z ${root}/.ssh/id_ed25519 0700 ${user.name} ${user.group}"
  ];
  # }}}
}
