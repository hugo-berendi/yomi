{config, ...}: {
  # This is the default port, and can only be changed via the GUI
  yomi.nginx.at.sonarr.port = 8989;

  services.sonarr = {
    enable = true;
  };

  environment.persistence."/persist/state".directories = [
    {
      inherit (config.services.sonarr) user group;
      directory = config.services.sonarr.dataDir;
      mode = "u=rwx,g=r,o=r";
    }
  ];
}
