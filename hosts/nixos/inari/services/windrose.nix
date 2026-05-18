{
  config,
  lib,
  ...
}: {
  services.windrose = {
    enable = true;
    serverName = "SuckDuck 67 Looksgay";
    maxPlayerCount = 4;
    directConnectionServerPort = config.yomi.ports.windrose-direct;
    useDirectConnection = false;
    serviceConfig = lib.mkMerge [
      config.yomi.hardening.presets.base
      {
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
      }
    ];
  };
}

