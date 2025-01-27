{config, ...}: {
  # This is the default port, and can only be changed via the GUI
  yomi.cloudflared.at.media.port = 8096;
  yomi.cloudflared.at.jellyseerr.port = config.yomi.ports.jellyseerr;

  services = {
    jellyfin.enable = true;
    jellyseerr = {
      enable = true;
      port = config.yomi.cloudflared.at.jellyseerr.port;
      openFirewall = true;
    };
  };

  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      inherit (config.services.jellyfin) user group;
      directory = "/var/lib/jellyfin";
      mode = "u=rwx,g=r,o=r";
    }
    {
      directory = "/var/lib/private/jellyseerr";
      defaultPerms.mode = "0700";
    }
  ];

  environment.persistence."/persist/local/cache".directories = [
    {
      inherit (config.services.jellyfin) user group;
      directory = "/var/cache/jellyfin";
      mode = "u=rwx,g=,o=";
    }
  ];
  # }}}
}
