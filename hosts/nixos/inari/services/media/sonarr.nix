{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    sonarr = 8989;
  };
  # }}}
  # {{{ reverse proxy
  yomi.nginx.at.sonarr.port = config.yomi.ports.sonarr;
  # }}}
  #{{{ settings
  nixarr.sonarr = {
    enable = true;
    vpn.enable = false;
  };
  # }}}
}
