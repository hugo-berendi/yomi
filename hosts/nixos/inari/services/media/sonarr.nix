{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    sonarr = 8989;
  };
  # }}}
  # {{{ reverse proxy
  # Authentication is off: /initialize.json hands the API key to anyone on
  # the LAN.
  yomi.web.at.sonarr = {
    port = config.yomi.ports.sonarr;
    transport = "nginx";
    authentication = "none";
    monitor.enable = true;
  };
  # }}}
  #{{{ settings
  nixarr.sonarr = {
    enable = true;
    vpn.enable = false;
  };
  # }}}
}
