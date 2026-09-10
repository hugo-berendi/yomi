{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.audiobookshelf;
in {
  # {{{ Reverse proxy
  yomi.cloudflared.at.audiobookshelf = {
    inherit port;
    enableAnubis = false;
  };
  # }}}
  # {{{ Service
  services.audiobookshelf = {
    enable = true;
    port = port;
    host = "127.0.0.1";
    dataDir = "/raid5pool/data/audiobookshelf";
  };
  # }}}
  # {{{ Hardening
  systemd.services.audiobookshelf.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    {ReadWritePaths = [config.services.audiobookshelf.dataDir];}
  ];
  # }}}
}
