{config, ...}: {
  yomi.nginx.at.komga.port = config.yomi.ports.komga;
  # {{{ General config
  services.komga = {
    enable = true;

    settings = {
      server = {
        port = config.yomi.nginx.at.komga.port;
        address = "127.0.0.1";
      };

      servlet = {
        context-path = config.yomi.nginx.at.komga.url;
        session.timeout = "7d";
      };

      oauth2-account-creation = true;
    };
  };
  # }}}
  # {{{ Storage
  environment.persistence."/persist/state".directories = [
    {
      directory = config.services.komga.stateDir;
      mode = "u=rwx,g=rx,o=";
      user = config.users.users.komga.name;
      group = config.users.users.komga.group;
    }
  ];
  # }}}
}
