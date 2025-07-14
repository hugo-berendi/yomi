{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.prowlarr.port = config.yomi.ports.prowlarr;
  # }}}
  #{{{ settings
  nixarr.prowlarr = {
    enable = true;
    port = config.yomi.nginx.at.prowlarr.port;
  };
  # }}}
}
