{
  inputs,
  config,
  ...
}: {
  imports = [inputs.playit-nixos-module.nixosModules.default];

  sops.secrets.playit_secret = {
    sopsFile = ../secrets.yaml;
    owner = config.services.playit.user;
    group = config.services.playit.group;
  };

  services.playit = {
    enable = true;
    user = "playit";
    group = "playit";
    secretPath = config.sops.secrets.playit_secret.path;
  };
}
