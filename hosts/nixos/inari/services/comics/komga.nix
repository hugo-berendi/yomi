{config, ...}: {
  yomi.nginx.at.komga.port = config.yomi.ports.komga;

  services.komga = {
    enable = true;
    settings.server.port = config.yomi.nginx.at.komga.port;
  };

  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.komga.stateDir;
      mode = "u=rwx,g=rx,o=";
      user = config.services.komga.user;
      group = config.services.komga.group;
    }
  ];
}
