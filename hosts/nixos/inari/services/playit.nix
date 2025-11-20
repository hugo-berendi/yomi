{config, lib, ...}: {
  sops.secrets.playit_secret = lib.mkIf config.yomi.playit.enable {
    sopsFile = ../secrets.yaml;
    owner = config.yomi.playit.user;
    group = config.yomi.playit.group;
  };

  yomi.playit = {
    enable = true;
    user = "playit";
    group = "playit";
    secretPath = config.sops.secrets.playit_secret.path;
  };
}
