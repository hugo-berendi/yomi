{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    radarr = 8467;
  };
  # }}}
  # {{{ reverse proxy
  yomi.nginx.at.radarr.port = config.yomi.ports.radarr;
  # }}}
  #{{{ settings
  nixarr.radarr = {
    enable = true;
    port = config.yomi.nginx.at.radarr.port;
    vpn.enable = false;
  };
  # }}}
}
