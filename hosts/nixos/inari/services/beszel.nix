{config, ...}: let
  port = config.yomi.ports.beszel;
in {
  # {{{ Service
  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1";
    port = port;
    dataDir = "/var/lib/beszel-hub";
    environment = {
      BESZEL_HUB_APP_URL = "https://monitoring.hugo-berendi.de";
      BESZEL_HUB_AUTO_LOGIN = "personal@hugo-berendi.de";
    };
  };
  # }}
  # {{{ Networking
  yomi.nginx.at.monitoring.port = port;
  # }}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/beszel-hub";
      user = "beszel";
      group = "beszel";
    }
  ];
  # }}
}
