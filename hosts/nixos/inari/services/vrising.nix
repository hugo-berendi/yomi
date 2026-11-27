{
  config,
  lib,
  ...
}: {
  # Game clients connect to Ebisu. RCON gets no grant, so it is reached
  # through SSH: `ssh -L 25575:127.0.0.1:25575 inari.hugo-berendi.de`.
  yomi.expose.udp = lib.mkIf config.services.vrising.enable {
    vrising.port = config.services.vrising.gamePort;
    vrising-query.port = config.services.vrising.queryPort;
  };
  # nftables owns inari's firewall, so opening the ports here reaches nothing.
  services.steamGameServers.vrising.openFirewall = false;

  services.vrising = {
    enable = true;
    sopsFile = ../secrets.yaml;
    serverName = "FischGHGesicht";
    worldName = "Yomi";
    autosaveRetention = 6 * 60 * 60;
    gameSettings = {
      teleportBoundItems = false;
      batBoundItems = false;
      batBoundShards = false;
      dropTableModifierGeneral = 4.0;
      dropTableModifierMissions = 4.0;
      dropTableModifierStygianShards = 4.0;
      warEventInterval = "Minimum";
      castleHeartLevel1FloorLimit = 60;
      castleHeartLevel1HeightLimit = 3;
      castleHeartLevel1ServantLimit = 6;
      castleHeartLevel2FloorLimit = 160;
      castleHeartLevel2HeightLimit = 4;
      castleHeartLevel2ServantLimit = 10;
      castleHeartLevel3FloorLimit = 400;
      castleHeartLevel3HeightLimit = 7;
      castleHeartLevel3ServantLimit = 14;
      castleHeartLevel4FloorLimit = 600;
      castleHeartLevel4HeightLimit = 8;
      castleHeartLevel4ServantLimit = 18;
      castleHeartLevel5FloorLimit = 1000;
      castleHeartLevel5HeightLimit = 9;
      castleHeartLevel5ServantLimit = 24;
    };
  };

  systemd.services.vrising.serviceConfig = lib.mkIf config.services.vrising.enable (lib.mkMerge [
    {
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
    }
  ]);
}
