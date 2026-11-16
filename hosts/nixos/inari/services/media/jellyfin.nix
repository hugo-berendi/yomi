{
  config,
  lib,
  pkgs,
  ...
}: {
  # {{{ Reverse proxy
  yomi.cloudflared.at.media.port = config.yomi.ports.jellyfin;
  # Staged until the Pangolin connector is enrolled; native apps use Jellyfin auth.
  yomi.expose.at.media = {
    port = config.yomi.ports.jellyfin;
    sso = false;
    labels = ["media"];
    monitor = {
      enable = true;
      name = "jellyfin";
    };
    healthCheck = {
      enable = true;
      path = "/health";
    };
  };
  yomi.expose.private.media = {
    destination = "127.0.0.1";
    alias = "media.inari.internal";
    tcpPorts = [config.yomi.ports.jellyfin];
    users = [config.yomi.pilot.email];
  };
  # }}}
  # {{{ Secrets
  sops.secrets.jellyfin_oidc_secret = {
    sopsFile = ../../secrets.yaml;
    owner = config.services.jellyfin.user;
    group = config.services.jellyfin.group;
  };

  # }}}
  # {{{ Jellyfin service
  services.jellyfin = {
    enable = true;
    openFirewall = false;
  };
  systemd.services.jellyfin = lib.mkIf config.services.jellyfin.enable {
    preStart = let
      port = toString config.yomi.ports.jellyfin;
      networkXml = "${config.services.jellyfin.configDir}/network.xml";
    in ''
      if [ -f "${networkXml}" ]; then
        ${lib.getExe pkgs.gnused} -i 's|<InternalHttpPort>[0-9]*</InternalHttpPort>|<InternalHttpPort>${port}</InternalHttpPort>|' "${networkXml}"
      fi
    '';
  };
  # }}}
  # {{{ Persistence
  yomi.persistence.at.state.apps.jellyfin.directories = [
    {
      directory = config.services.jellyfin.dataDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.jellyfin.user;
      group = config.services.jellyfin.group;
    }
    {
      directory = config.services.jellyfin.cacheDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.jellyfin.user;
      group = config.services.jellyfin.group;
    }
  ];
  # }}}
}
