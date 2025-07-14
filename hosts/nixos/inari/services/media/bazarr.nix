{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.bazarr.port = config.yomi.ports.bazarr;
  # }}}
  #{{{ settings
  nixarr.bazarr = {
    enable = true;
    port = config.yomi.nginx.at.bazarr.port;
    vpn.enable = false;
  };
  # }}}
}
