{config, ...}: {
  # This is the default port, and can only be changed via the GUI
  yomi.nginx.at.media.port = 8096;
  services.jellyfin.enable = true;

  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      inherit (config.services.jellyfin) user group;
      directory = "/var/lib/jellyfin";
      mode = "u=rwx,g=r,o=r";
    }
    {
      directory = "/var/lib/media";
      mode = "u=rwx,g=rwx,o=rwx";
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
