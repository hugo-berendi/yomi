{
  config,
  pkgs,
  ...
}: {
  users.groups.meilisearch = {};
  users.users.meilisearch = {
    isSystemUser = true;
    group = config.users.groups.meilisearch.name;
  };

  # {{{ Secrets
  sops.secrets.meilisearch_env = {
    sopsFile = ../../../inari/secrets.yaml;
    owner = config.users.users.meilisearch.name;
    group = config.users.groups.meilisearch.name;
  };
  # }}}

  # {{{ service config
  services.meilisearch = {
    enable = true;
    package = pkgs.meilisearch;
    listenPort = config.yomi.ports.meilisearch;
    masterKeyEnvironmentFile = config.sops.secrets.meilisearch_env.path;
    environment =
      if config.networking.hostName == "inari"
      then "production"
      else "development";
    dumplessUpgrade = true;
  };
  systemd.services.meilisearch.serviceConfig = {
    User = config.users.users.meilisearch.name;
    Group = config.users.groups.meilisearch.name;
  };
  # }}}
  # {{{ Storage
  # environment.persistence."/persist/state".directories = [
  #   {
  #     directory = "/var/lib/meilisearch";
  #     mode = "u=rwx,g=,o=";
  #     user = config.users.users.meilisearch.name;
  #     group = config.users.groups.meilisearch.name;
  #   }
  # ];
  # }}}
}
