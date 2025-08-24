{config, ...}: {
  # {{{ reverse proxy
  yomi.cloudflared.at.request-media.port = config.yomi.ports.jellyseerr;
  # }}}
  #{{{ settings
  nixarr.jellyseerr = {
    enable = true;
    port = config.yomi.cloudflared.at.request-media.port;
    vpn.enable = false;
  };
  # }}}
}
