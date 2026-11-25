{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.audiobookshelf;
  # Episodes of the subscribed podcasts. Not backed up: every one of them can
  # be downloaded again from its feed.
  podcastDir = "/raid5pool/media/podcasts";
in {
  # {{{ Ports
  yomi.ports = {
    audiobookshelf = 8493;
  };
  # }}}
  # {{{ Reverse proxy
  yomi.web.at.audiobookshelf = {
    transport = "pangolin";
    authentication = "application";
    pangolin = {
      labels = ["media"];
      healthCheck = {
        enable = true;
        path = "/ping";
      };
    };
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
  yomi.persistence.at.state.apps.audiobookshelf.directories = [
    {
      directory = "/var/lib/audiobookshelf";
      mode = "u=rwx,g=,o=";
      user = config.users.users.audiobookshelf.name;
      group = config.users.users.audiobookshelf.group;
    }
  ];
  systemd.tmpfiles.settings.audiobookshelf.${podcastDir}.d = {
    mode = "0755";
    inherit (config.users.users.audiobookshelf) group;
    user = config.users.users.audiobookshelf.name;
  };
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
    # The podcast library is the only place outside its state it writes to.
    {ReadWritePaths = ["/var/lib/audiobookshelf" podcastDir];}
  ];
  # }}}
}
