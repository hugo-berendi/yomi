{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.wireless;
in {
  config = lib.mkIf (cfg.enable && cfg.backend == "iwd") {
    networking.wireless.iwd = {
      enable = true;

      settings = {
        IPv6.Enabled = true;
        Settings.AutoConnect = true;
      };
    };

    environment.persistence."/persist/state".directories = ["/var/lib/iwd"];
  };
}
