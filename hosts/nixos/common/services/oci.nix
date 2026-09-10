{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.containers;
in {
  options.yomi.containers = {
    enable = lib.mkEnableOption "yomi's OCI containers integration";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "docker";

    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };

    environment.persistence = {
      "/persist/state".directories = [
        # The backend above is docker, which keeps its image and layer store
        # here. Without this every boot started from an empty store and had to
        # re-pull every image.
        "/var/lib/docker"
        "/var/lib/containers/storage"
      ];
      "/persist/local/cache".directories = ["/var/lib/containers/cache"];
    };

    # Hosts that serve their own DNS cannot resolve a registry during early
    # boot. The default start limit turned that transient failure into a unit
    # that stayed dead until it was restarted by hand.
    systemd.services =
      lib.mapAttrs' (
        name: _:
          lib.nameValuePair "${config.virtualisation.oci-containers.backend}-${name}" {
            startLimitIntervalSec = 0;
            serviceConfig.RestartSec = lib.mkForce "30s";
          }
      )
      config.virtualisation.oci-containers.containers;
  };
}
