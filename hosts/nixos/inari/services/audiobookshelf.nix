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
    inherit port;
    host = "127.0.0.1";
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/audiobookshelf";
      mode = "u=rwx,g=,o=";
      user = config.users.users.audiobookshelf.name;
      group = config.users.users.audiobookshelf.group;
    }
  ];
  # }}}
  # {{{ Hardening
  systemd.services.audiobookshelf.serviceConfig = lib.mkMerge [
    (lib.mapAttrs (_: lib.mkForce) config.yomi.hardening.presets.standard)
    {ReadWritePaths = ["/var/lib/audiobookshelf"];}
  ];
  # }}}
}
