{config, lib, ...}: {
  sops.secrets.playit_secret = lib.mkIf config.yomi.playit.enable {
    sopsFile = ../secrets.yaml;
  };

  yomi.playit = {
    enable = true;
    secretPath = config.sops.secrets.playit_secret.path;
  };
}
