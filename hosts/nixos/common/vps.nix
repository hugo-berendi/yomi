{
  config,
  lib,
  outputs,
  pkgs,
  ...
}: {
  # Only the shared base: no desktop, theming, 1Password, monitoring agent or
  # the fleet's pilot user. A new VPS cannot decrypt the home fleet's
  # password/monitoring secrets, so it bootstraps with keys only; enroll its
  # real host key before adding secrets.
  imports = [./base.nix];

  # The yomi modules default these on for the home fleet's impermanence and
  # Wi-Fi; a VPS has neither.
  yomi.persistence.enable = false;
  yomi.filesystems.persistPaths = [];
  yomi.wireless.enable = false;

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
