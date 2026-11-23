{config, ...}: let
  port = config.yomi.ports.beszel;
in {
  # {{{ Ports and reachability
  yomi.ports = {
    beszel = 8406;
  };
  yomi.network.exposure.beszel.interface = "br0";
  # }}}
  # {{{ Service
  services.beszel.hub = {
    enable = true;
    host = "127.0.0.1";
    inherit port;
    dataDir = "/var/lib/beszel-hub";
    environment = {
      BESZEL_HUB_APP_URL = "https://monitoring.hugo-berendi.de";
      BESZEL_HUB_AUTO_LOGIN = "personal@hugo-berendi.de";
      DISABLE_PASSWORD_AUTH = "true";
      USER_CREATION = "true";
    };
  };
  # }}}
  # {{{ Networking
  yomi.web.at.monitoring = {
    port = port;
    transport = "nginx";
    authentication = "application";
    monitor.enable = true;
  };
  # }}}
}
