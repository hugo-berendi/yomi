{config, ...}: {
  # {{{ reverse proxy
  yomi.nginx.at.torrent = {
    port = config.yomi.ports.transmission_ui;
    proxyAddress = "192.168.15.1";
  };
  # }}}
  sops.secrets.transmission_credentialsFile.sopsFile = ../../secrets.yaml;
  #{{{ settings
  nixarr.transmission = {
    enable = true;
    uiPort = config.yomi.nginx.at.torrent.port;
    peerPort = config.yomi.ports.transmission_peer;
    flood.enable = true;
    credentialsFile = config.sops.secrets.transmission_credentialsFile.path;
    extraSettings = {
      "download-dir" = "/raid5pool/media/downloads";
      "incomplete-dir-enabled" = true;
      "incomplete-dir" = "/raid5pool/media/downloads/incomplete";
      "rpc-bind-address" = "0.0.0.0";
      # credentialsFile supplies rpc-username and rpc-password, but that alone
      # leaves authentication off: the RPC answered 409 rather than 401 with
      # no credentials, so anyone on the LAN or tailnet who reached
      # torrent.<domain> could add torrents and write into the media tree.
      "rpc-authentication-required" = true;
      # Fix UI not showing data behind reverse proxy
      # Allow requests from any Host header and disable IP whitelist
      "rpc-host-whitelist-enabled" = false;
      "rpc-whitelist-enabled" = false;
      # Ensure the expected RPC path works when proxied
      "rpc-url" = "/transmission/";
      # Keep RPC on the same port as the UI
      "rpc-port" = config.yomi.nginx.at.torrent.port;
    };
    vpn.enable = true;
  };
  # }}}

  # Ensure download directories exist with broad permissions
  systemd.tmpfiles.rules = [
    "d /raid5pool/media/downloads 2777 - - -"
    "d /raid5pool/media/downloads/incomplete 2777 - - -"
    "Z /raid5pool/media/downloads 2777 - - -"
  ];
}
