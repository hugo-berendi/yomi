{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.oci;
in {
  options.yomi.oci = {
    enable = lib.mkEnableOption "yomi's OCI containers integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "docker";

    environment.persistence = {
      "/persist/state".directories = [
        "/var/lib/containers/storage"
      ];

      "/persist/local/cache".directories = [
        "/var/lib/containers/cache"
      ];
    };
  };
}
