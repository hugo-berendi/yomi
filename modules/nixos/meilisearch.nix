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

    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Sops file containing the meilisearch_env secret. Must be set when enable is true.";
    };

    environment = lib.mkOption {
      type = lib.types.enum ["production" "development"];
      default = "development";
      description = "Meilisearch environment mode";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.meilisearch_env.sopsFile =
      lib.throwIf (cfg.sopsFile == null)
      "yomi.meilisearch.sopsFile must be set when yomi.meilisearch.enable is true"
      cfg.sopsFile;

    services.meilisearch = {
      enable = true;
      package = pkgs.meilisearch;
      listenPort = config.yomi.ports.meilisearch;
      masterKeyFile = config.sops.secrets.meilisearch_env.path;
      settings = {
        db_path = "/var/lib/private/meilisearch/data.ms";
        env = cfg.environment;
        experimental_dumpless_upgrade = true;
      };
    };
  };
}
