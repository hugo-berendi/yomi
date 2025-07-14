{config, ...}: {
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
