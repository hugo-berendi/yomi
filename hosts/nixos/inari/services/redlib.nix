{
  config,
  lib,
  ...
}: let
  port = config.yomi.ports.redlib;
in {
  services.redlib = {
    enable = false;
    inherit port;
  };

  yomi.nginx.at.redlib = lib.mkIf config.services.redlib.enable {
    inherit port;
  };

  systemd.services.redlib.serviceConfig = lib.mkIf config.services.redlib.enable {
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateDevices = true;
    PrivateMounts = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    RestrictNamespaces = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
  };
}
