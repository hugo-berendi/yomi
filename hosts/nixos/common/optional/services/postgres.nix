{config, ...}: {
  services.postgresql = {
    enable = true;
  };

  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/postgresql";
      user = config.users.users.postgres.name;
      group = config.users.users.postgres.group;
    }
  ];
  # }}}
}
