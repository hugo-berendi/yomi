{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.yomi.meilisearch;
in {
  options.yomi.meilisearch = {
    enable = lib.mkEnableOption "yomi's meilisearch integration";
  };

  config = lib.mkIf cfg.enable {
    users.groups.meilisearch = {};
    users.users.meilisearch = {
      isSystemUser = true;
      group = "meilisearch";
    };

    sops.secrets.meilisearch_env.sopsFile = ../../../inari/secrets.yaml;

    services.meilisearch = {
      enable = true;
      package = pkgs.meilisearch;
      listenPort = config.yomi.ports.meilisearch;
      masterKeyFile = config.sops.secrets.meilisearch_env.path;
      settings = {
        db_path = "/var/lib/meilisearch/data.ms";
        env =
          if config.networking.hostName == "inari"
          then "production"
          else "development";
        experimental_dumpless_upgrade = true;
      };
    };
    
    systemd.services.meilisearch.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "meilisearch";
      Group = "meilisearch";
      PrivateMounts = lib.mkForce false;
    };
    
    environment.persistence."/persist/state".directories = [
      {
        directory = "/var/lib/meilisearch";
        user = "meilisearch";
        group = "meilisearch";
        mode = "0700";
      }
    ];
  };
}
