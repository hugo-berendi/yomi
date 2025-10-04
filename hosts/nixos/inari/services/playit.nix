{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [inputs.playit-nixos-module.nixosModules.default];

  sops.secrets.playit_secret = lib.mkIf config.services.playit.enable {
    sopsFile = ../secrets.yaml;
    owner = config.services.playit.user;
    group = config.services.playit.group;
  };

  services.playit = {
    enable = false;
    user = "playit";
    group = "playit";
    secretPath = config.sops.secrets.playit_secret.path;
  };
}
