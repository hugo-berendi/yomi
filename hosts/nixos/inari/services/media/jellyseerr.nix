{config, ...}: {
  # {{{ reverse proxy
  yomi.cloudflared.at.media-request.port = config.yomi.ports.jellyseerr;
  # }}}
  #{{{ settings
  nixarr.jellyseerr = {
    enable = true;
    port = config.yomi.cloudflared.at.media-request.port;
    vpn.enable = false;
  };
  # }}}
}
