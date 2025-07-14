{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.readarr.port = config.yomi.ports.readarr;
  # }}}
  #{{{ settings
  nixarr.readarr = {
    enable = true;
    port = config.yomi.nginx.at.readarr.port;
    vpn.enable = false;
  };
  # }}}
}
