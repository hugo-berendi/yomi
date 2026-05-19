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
    useDirectConnection = true; # Enable direct connection
    p2pProxyAddress = "0.0.0.0"; # Set P2P proxy address
    inviteCode = "YOUR_SECRET_CODE"; # Add invite code
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

