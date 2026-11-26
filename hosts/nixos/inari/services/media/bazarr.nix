{config, ...}: {
  # {{{ Ports
  yomi.ports = {
    bazarr = 8405;
  };
  # }}}
  # {{{ reverse proxy
  yomi.web.at.bazarr = {
    transport = "nginx";
    authentication = "application";
    monitor.enable = true;
  };
  # }}}
  #{{{ settings
  nixarr.bazarr = {
    enable = true;
    port = config.yomi.web.at.bazarr.port;
    vpn.enable = false;
  };
  # }}}
}
