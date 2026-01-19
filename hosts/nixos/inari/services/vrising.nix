{
  config,
  lib,
  ...
}: {
  sops.secrets.vrising_rcon_password = {
    sopsFile = ../secrets.yaml;
  };

  services.vrising = {
    enable = true;
    serverName = "FischGHGesicht";
    worldName = "Yomi";
    autosaveRetention = 6 * 60 * 60;
    gameSettings = {
      teleportBoundItems = false;
      batBoundItems = false;
      batBoundShards = false;
      dropTableModifierGeneral = 2.0;
      dropTableModifierMissions = 2.0;
      dropTableModifierStygianShards = 2.0;
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

  systemd.services.vrising.serviceConfig = lib.mkMerge [
    config.yomi.hardening.presets.base
    {
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
    }
  ];
}
