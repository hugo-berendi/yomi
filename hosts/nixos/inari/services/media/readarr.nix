{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.readarr.port = config.yomi.ports.readarr;
  # }}}
  #{{{ settings
  services.readarr = {
    enable = true;
    dataDir = "/var/lib/media/readarr";
    settings.server.port = config.yomi.nginx.at.readarr.port;
  };
  # }}}
}
