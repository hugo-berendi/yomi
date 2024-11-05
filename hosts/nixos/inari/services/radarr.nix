{config, ...}: {
  # This is the default port, and can only be changed via the GUI
  yomi.nginx.at.radarr.port = 7878;

  services.radarr = {
    enable = true;
  };

  environment.persistence."/persist/state".directories = [
    {
      inherit (config.services.radarr) user group;
      directory = config.services.radarr.dataDir;
      mode = "u=rwx,g=r,o=r";
    }
  ];
}
