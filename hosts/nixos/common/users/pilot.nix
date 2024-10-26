{
  pkgs,
  outputs,
  config,
  lib,
  ...
}: {
  yomi.pilot.name = lib.mkDefault "hugob";

  sops.secrets.pilot_password = {
    sopsFile = ../secrets.yaml;
    neededForUsers = true;
  };

  users = {
    # Configure users through nix only
    mutableUsers = false;

    # Sync up root and `pilot` shell
    users.root.shell = config.users.users.pilot.shell;

    users.pilot = {
      inherit (config.yomi.pilot) name;

      description = "Hugo Berendi";

      # Adds me to some default groups, and creates the home dir
      isNormalUser = true;

      # Picked up by our persistence module
      homeMode = "700";

      # Add user to the following groups
      extraGroups = [
        "wheel" # Access to sudo
        "lp" # Printers
        "audio" # Audio devices
        "video" # Webcam and the like
        "network" # wpa_supplicant
        "syncthing" # syncthing!
        "vboxusers"
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
    user = config.users.users.pilot;
    root = "/persist/state/${user.home}/ssh";
    etc_root = "/persist/state/etc/ssh";
  in [
    "d ${root}                 0755 ${user.name} ${user.group}"
    "d ${root}/.ssh            0755 ${user.name} ${user.group}"
    "z ${etc_root}/ssh*        0700 ${user.name} ${user.group}"
    "z ${etc_root}/ssh*.pu     0755 ${user.name} ${user.group}"
    "z ${root}/.ssh/id_*.pub   0755 ${user.name} ${user.group}"
    "z ${root}/.ssh/id_rsa     0700 ${user.name} ${user.group}"
    "z ${root}/.ssh/id_ed25519 0700 ${user.name} ${user.group}"
    "d /home/hugob/.gnupg      0755 ${user.name} ${user.group}"
  ];
  # }}}
}
