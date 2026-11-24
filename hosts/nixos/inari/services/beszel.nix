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
  # The hub reaches inari's own agent over SSH at 127.0.0.1:45876. That
  # address is kept in the hub's database (system "inari"), not here: it was
  # inari's Tailscale address until Tailscale was retired on 2026-11-20, and
  # the hub showed inari as down until the address was changed on 2026-11-24.
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
    inherit port;
    transport = "nginx";
    # BESZEL_HUB_AUTO_LOGIN signs every request in as the pilot, API calls
    # included: an anonymous request reads and edits systems and alerts.
    authentication = "none";
    monitor.enable = true;
  };
  # }}}
}
