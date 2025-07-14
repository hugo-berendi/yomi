{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.torrent.port = config.yomi.ports.transmission_ui;
  # }}}
  sops.secrets.transmission_credentialsFile.sopsFile = ../../secrets.yaml;
  #{{{ settings
  nixarr.transmission = {
    enable = true;
    uiPort = config.yomi.nginx.at.torrent.port;
    peerPort = config.yomi.ports.transmission_peer;
    flood.enable = true;
    credentialsFile = config.sops.secrets.transmission_credentialsFile.path;
    extraSettings = {};
    vpn.enable = true;
  };
  # }}}
}
