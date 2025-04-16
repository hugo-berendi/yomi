{config, ...}: {
  services.postgresql = {
    enable = true;
  };

  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/postgresql";
      user = config.users.users.postgres.name;
      group = config.users.users.postgres.group;
    }
  ];
}
