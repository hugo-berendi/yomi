{config, ...}: {
  # This is the default port, and can only be changed via the GUI
  yomi.nginx.at.readarr.port = 8787;

  services.readarr = {
    enable = true;
  };

  environment.persistence."/persist/state".directories = [
    {
      inherit (config.services.readarr) user group;
      directory = config.services.readarr.dataDir;
      mode = "u=rwx,g=r,o=r";
    }
  ];
}
