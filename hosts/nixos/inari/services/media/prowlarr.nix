{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    prowlarr = 8465;
  };
  # }}}
  # {{{ reverse proxy
  yomi.web.at.prowlarr = {
    port = config.yomi.ports.prowlarr;
    transport = "nginx";
    authentication = "application";
    monitor.enable = true;
  };
  # }}}
  #{{{ settings
  nixarr.prowlarr = {
    enable = true;
    port = config.yomi.web.at.prowlarr.port;
  };
  # }}}
}
