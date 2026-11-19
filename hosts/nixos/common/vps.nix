{
  config,
  lib,
  outputs,
  pkgs,
  ...
}: {
  imports = [./default.nix];

  # A new VPS cannot decrypt the home fleet's password/monitoring secrets.
  # Bootstrap with keys only; enroll its real host key before adding secrets.
  disabledModules = [./users/pilot.nix];

  yomi.persistence.enable = false;
  yomi.filesystems.persistPaths = [];
  yomi.beszel-agent.enable = false;
  yomi.wireless.enable = false;
  programs._1password.enable = lib.mkForce false;
  stylix.enable = lib.mkForce false;

  users.mutableUsers = false;
  users.users.root.hashedPassword = "*";
  users.users.${config.yomi.pilot.name} = {
    isNormalUser = true;
    description = "Hugo Berendi";
    homeMode = "0700";
    shell = pkgs.fish;
    hashedPassword = "*";
    extraGroups = ["wheel" "systemd-journal"];
    openssh.authorizedKeys.keyFiles =
      (import ./users/common.nix).authorizedKeys {inherit outputs lib;};
  };

  # The VPS profile starts with a locked pilot password, so sudo must work
  # after an SSH key login.
  security.sudo.extraRules = [
    {
      users = [config.yomi.pilot.name];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedTCPPorts = [22];
  };

  environment.systemPackages = with pkgs; [git curl];
  services.journald.extraConfig = "SystemMaxUse=128M";
  nix.settings = {
    # Leave memory for the tunnel on the 2 GiB plan; build larger closures elsewhere.
    max-jobs = lib.mkDefault 1;
    cores = lib.mkDefault 1;
  };
}
