{
  lib,
  config,
  ...
}: let
  cfg = config.yomi.tailscale;
in {
  options.yomi.tailscale = {
    enable =
      lib.mkEnableOption "yomi's tailscale integration"
      // {
        default = true;
      };
    exitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Tailscale exit node functionality";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures =
        if cfg.exitNode
        then "both"
        else "client";
    };

    environment.persistence."/persist/state".directories = ["/var/lib/tailscale"];
  };
}
