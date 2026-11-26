{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    radarr = 8467;
  };
  # }}}
  # {{{ reverse proxy
  # Authentication is off: /initialize.json hands the API key to anyone on
  # the LAN.
  yomi.web.at.radarr = {
    transport = "nginx";
    authentication = "none";
    monitor.enable = true;
  };
  # }}}
  #{{{ settings
  nixarr.radarr = {
    enable = true;
    port = config.yomi.web.at.radarr.port;
    vpn.enable = false;
  };
  # }}}
}
