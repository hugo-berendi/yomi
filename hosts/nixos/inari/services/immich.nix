{config, ...}: {
  sops.secrets.immich_secrets = {
    sopsFile = ../secrets.yaml;
    owner = config.services.immich.user;
    group = config.services.immich.group;
  };

  yomi.nginx.at.immich.port = config.yomi.ports.immich;

  services.immich = {
    enable = true;
    port = config.yomi.ports.immich;
    host = "0.0.0.0";
    mediaLocation = "/raid5pool/media/photos";
    secretsFile = config.sops.secrets.immich_secrets.path;
    settings = {
      server = {
        externalDomain = "https://immich.hugo-berendi.de/";
        loginPageMessage = "Hello traveler ^_^";
      };
    };
  };
}
