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
    {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      PrivateMounts = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
    }
    {ReadWritePaths = ["/var/lib/audiobookshelf"];}
  ];
  # }}}
}
