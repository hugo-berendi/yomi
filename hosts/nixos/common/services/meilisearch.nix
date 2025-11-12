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
    sops.secrets.meilisearch_env.sopsFile = ../../inari/secrets.yaml;

    services.meilisearch = {
      enable = true;
      package = pkgs.meilisearch;
      listenPort = config.yomi.ports.meilisearch;
      masterKeyFile = config.sops.secrets.meilisearch_env.path;
      settings = {
        db_path = "/var/lib/private/meilisearch/data.ms";
        env =
          if config.networking.hostName == "inari"
          then "production"
          else "development";
        experimental_dumpless_upgrade = true;
      };
    };
  };
}
