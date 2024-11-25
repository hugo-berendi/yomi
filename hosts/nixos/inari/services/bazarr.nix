{config, ...}: {
  # This is the default port, and can only be changed via the GUI
  yomi.nginx.at.bazarr.port = config.services.bazarr.listenPort;

  services.bazarr = {
    enable = true;
  };

  environment.persistence."/persist/state".directories = [
    {
      inherit (config.services.bazarr) user group;
      directory = "/var/lib/bazarr";
      mode = "u=rwx,g=r,o=r";
    }
  ];
}
