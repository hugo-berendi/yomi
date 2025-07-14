{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.lidarr.port = config.yomi.ports.lidarr;
  # }}}
  #{{{ settings
  nixarr.lidarr = {
    enable = true;
    port = config.yomi.nginx.at.lidarr.port;
    vpn.enable = false;
  };
  # }}}
}
