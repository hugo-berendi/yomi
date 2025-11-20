{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.octodns-ddns;
in {
  options.services.octodns-ddns = {
    enable = lib.mkEnableOption "OctoDNS DDNS synchronization";

    interval = lib.mkOption {
      type = lib.types.str;
      default = "12h";
      description = "How often to sync DDNS records";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.octodns-ddns-sync = {
      description = "OctoDNS DDNS synchronization";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.bash} -c 'cd /etc/nixos && ${pkgs.octodns-sync}/bin/octodns-sync'";
        User = "root";
      };
    };

    systemd.timers.octodns-ddns-sync = {
      description = "OctoDNS DDNS synchronization timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = cfg.interval;
        AccuracySec = "5m";
        Persistent = true;
      };
    };
  };
}
