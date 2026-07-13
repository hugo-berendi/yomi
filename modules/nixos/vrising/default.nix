{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vrising;
  data = import ./game-data.nix;
  gs = cfg.gameSettings;
  serverDir = "/persist/data/vrising/server";
  dataDir = "/persist/data/vrising/data";
  steamAppId = "1829350";
  configHash = builtins.hashString "sha256" (builtins.toJSON cfg);

  hostSettingsJson = pkgs.writeText "ServerHostSettings.json" (builtins.toJSON {
    Name = cfg.serverName;
    Description = "";
    Port = cfg.gamePort;
    QueryPort = cfg.queryPort;
    MaxConnectedUsers = cfg.maxConnectedUsers;
    MaxConnectedAdmins = 4;
    ServerFps = 30;
    SaveName = cfg.worldName;
    Password = "";
    Secure = true;
    ListOnMasterServer = false;
    ListOnSteam = false;
    ListOnEOS = false;
    AutoSaveCount = 20;
    AutoSaveInterval = cfg.saveInterval;
    CompressSaveFiles = true;
    GameSettingsPreset = cfg.preset;
    GameDifficultyPreset = "";
    AdminOnlyDebugEvents = true;
    DisableDebugEvents = false;
    API.Enabled = false;
    Rcon = {
      Enabled = cfg.rconPort != 0;
      Port = cfg.rconPort;
      Password = "$RCON_PASSWORD";
    };
  });

  gameSettingsJson = pkgs.writeText "ServerGameSettings.json" (builtins.toJSON {
    GameDifficulty = data.gameDifficultyToInt.${gs.gameDifficulty};
    GameModeType = data.gameModeTypeToInt.${gs.gameModeType};
    CastleDamageMode = data.castleDamageModeToInt.${gs.castleDamageMode};
    PlayerDamageMode = data.playerDamageModeToInt.${gs.playerDamageMode};
    SiegeWeaponHealth = data.siegeWeaponHealthToInt.${gs.siegeWeaponHealth};
    CastleHeartDamageMode = data.castleHeartDamageModeToInt.${gs.castleHeartDamageMode};
    PvPProtectionMode = data.pvpProtectionModeToInt.${gs.pvpProtectionMode};
    DeathContainerPermission = data.deathContainerPermissionToInt.${gs.deathContainerPermission};
    RelicSpawnType = data.relicSpawnTypeToInt.${gs.relicSpawnType};
    CanLootEnemyContainers = gs.canLootEnemyContainers;
    BloodBoundEquipment = gs.bloodBoundEquipment;
    TeleportBoundItems = gs.teleportBoundItems;
    BatBoundItems = gs.batBoundItems;
    BatBoundShards = gs.batBoundShards;
    AllowGlobalChat = gs.allowGlobalChat;
    AllWaypointsUnlocked = gs.allWaypointsUnlocked;
    FreeCastleRaid = gs.freeCastleRaid;
    FreeCastleClaim = gs.freeCastleClaim;
    FreeCastleDestroy = gs.freeCastleDestroy;
    CastleRelocationEnabled = gs.castleRelocationEnabled;
    InactivityKillEnabled = gs.inactivityKillEnabled;
    InactivityKillTimeMin = gs.inactivityKillTimeMin;
    InactivityKillTimeMax = gs.inactivityKillTimeMax;
    InactivityKillTimerMaxItemLevel = gs.inactivityKillTimerMaxItemLevel;
    InactivityKillSafeTimeAddition = gs.inactivityKillSafeTimeAddition;
    DisableDisconnectedDeadEnabled = gs.disableDisconnectedDeadEnabled;
    DisableDisconnectedDeadTimer = gs.disableDisconnectedDeadTimer;
    DisconnectedSunImmunityTime = gs.disconnectedSunImmunityTime;
    InventoryStacksModifier = gs.inventoryStacksModifier;
    DropTableModifier_General = gs.dropTableModifierGeneral;
    DropTableModifier_Missions = gs.dropTableModifierMissions;
    DropTableModifier_StygianShards = gs.dropTableModifierStygianShards;
    SoulShard_DurabilityLossRate = gs.soulShardDurabilityLossRate;
    MaterialYieldModifier_Global = gs.materialYieldModifierGlobal;
    BloodEssenceYieldModifier = gs.bloodEssenceYieldModifier;
    PvPVampireRespawnModifier = gs.pvpVampireRespawnModifier;
    ClanSize = gs.clanSize;
    BloodDrainModifier = gs.bloodDrainModifier;
    DurabilityDrainModifier = gs.durabilityDrainModifier;
    GarlicAreaStrengthModifier = gs.garlicAreaStrengthModifier;
    HolyAreaStrengthModifier = gs.holyAreaStrengthModifier;
    SilverStrengthModifier = gs.silverStrengthModifier;
    SunDamageModifier = gs.sunDamageModifier;
    CastleDecayRateModifier = gs.castleDecayRateModifier;
    CastleBloodEssenceDrainModifier = gs.castleBloodEssenceDrainModifier;
    CastleSiegeTimer = gs.castleSiegeTimer;
    CastleUnderAttackTimer = gs.castleUnderAttackTimer;
    CastleRaidTimer = gs.castleRaidTimer;
    CastleRaidProtectionTime = gs.castleRaidProtectionTime;
    CastleExposedFreeClaimTimer = gs.castleExposedFreeClaimTimer;
    CastleRelocationCooldown = gs.castleRelocationCooldown;
    AnnounceSiegeWeaponSpawn = gs.announceSiegeWeaponSpawn;
    ShowSiegeWeaponMapIcon = gs.showSiegeWeaponMapIcon;
    BuildCostModifier = gs.buildCostModifier;
    RecipeCostModifier = gs.recipeCostModifier;
    CraftRateModifier = gs.craftRateModifier;
    RefinementCostModifier = gs.refinementCostModifier;
    RefinementRateModifier = gs.refinementRateModifier;
    ResearchCostModifier = gs.researchCostModifier;
    DismantleResourceModifier = gs.dismantleResourceModifier;
    ServantConvertRateModifier = gs.servantConvertRateModifier;
    RepairCostModifier = gs.repairCostModifier;
    Death_DurabilityFactorLoss = gs.deathDurabilityFactorLoss;
    Death_DurabilityLossFactorAsResources = gs.deathDurabilityLossFactorAsResources;
    VampireStatModifiers = {
      MaxHealth = gs.vampireMaxHealthModifier;
      PhysicalPower = gs.vampirePhysicalPowerModifier;
      SpellPower = gs.vampireSpellPowerModifier;
      ResourcePower = gs.vampireResourcePowerModifier;
      DamageReceived = gs.vampireDamageReceivedModifier;
      ReviveCancelDelay = gs.vampireReviveCancelDelay;
    };
    UnitStatModifiers_Global = {
      MaxHealth = gs.unitMaxHealthModifierGlobal;
      Power = gs.unitPowerModifierGlobal;
      LevelIncrease = gs.unitLevelIncreaseGlobal;
    };
    UnitStatModifiers_VBlood = {
      MaxHealth = gs.unitMaxHealthModifierVBlood;
      Power = gs.unitPowerModifierVBlood;
      LevelIncrease = gs.unitLevelIncreaseVBlood;
    };
    EquipmentStatModifiers_Global = {
      MaxHealth = gs.equipmentMaxHealthModifier;
      ResourceYield = gs.equipmentResourceYieldModifier;
      PhysicalPower = gs.equipmentPhysicalPowerModifier;
      SpellPower = gs.equipmentSpellPowerModifier;
      SiegePower = gs.equipmentSiegePowerModifier;
    };
    CastleStatModifiers_Global = {
      TickPeriod = gs.castleTickPeriod;
      SafetyBoxLimit = gs.castleSafetyBoxLimit;
      TombLimit = gs.castleTombLimit;
      VerminNestLimit = gs.castleVerminNestLimit;
      NetherGateLimit = gs.castleNetherGateLimit;
      PrisonCellLimit = gs.castlePrisonCellLimit;
      EyeStructuresLimit = gs.castleEyeStructuresLimit;
      CastleLimit = gs.castleLimit;
      ThroneOfDarknessLimit = gs.castleThroneOfDarknessLimit;
      HeartLimits = {
        Level1 = {
          FloorLimit = gs.castleHeartLevel1FloorLimit;
          ServantLimit = gs.castleHeartLevel1ServantLimit;
          HeightLimit = gs.castleHeartLevel1HeightLimit;
        };
        Level2 = {
          FloorLimit = gs.castleHeartLevel2FloorLimit;
          ServantLimit = gs.castleHeartLevel2ServantLimit;
          HeightLimit = gs.castleHeartLevel2HeightLimit;
        };
        Level3 = {
          FloorLimit = gs.castleHeartLevel3FloorLimit;
          ServantLimit = gs.castleHeartLevel3ServantLimit;
          HeightLimit = gs.castleHeartLevel3HeightLimit;
        };
        Level4 = {
          FloorLimit = gs.castleHeartLevel4FloorLimit;
          ServantLimit = gs.castleHeartLevel4ServantLimit;
          HeightLimit = gs.castleHeartLevel4HeightLimit;
        };
        Level5 = {
          FloorLimit = gs.castleHeartLevel5FloorLimit;
          ServantLimit = gs.castleHeartLevel5ServantLimit;
          HeightLimit = gs.castleHeartLevel5HeightLimit;
        };
      };
    };
    TraderModifiers = {
      StockModifier = gs.traderStockModifier;
      PriceModifier = gs.traderPriceModifier;
      RestockTimerModifier = gs.traderRestockTimerModifier;
    };
    WarEventGameSettings = {
      Interval = gs.warEventInterval;
      MajorDuration = gs.warEventMajorDuration;
      MinorDuration = gs.warEventMinorDuration;
    };
    GameTimeModifiers = {
      DayDurationInSeconds = gs.dayDurationInSeconds;
      DayStartHour = gs.dayStartHour;
      DayStartMinute = gs.dayStartMinute;
      DayEndHour = gs.dayEndHour;
      DayEndMinute = gs.dayEndMinute;
      BloodMoonFrequency_Min = gs.bloodMoonFrequencyMin;
      BloodMoonFrequency_Max = gs.bloodMoonFrequencyMax;
      BloodMoonBuff = gs.bloodMoonBuff;
    };
  });
in {
  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    sops.secrets.vrising_rcon_password = {
      sopsFile =
        lib.throwIf (cfg.sopsFile == null)
        "services.vrising.sopsFile must be set when services.vrising.enable is true"
        cfg.sopsFile;
    };

    services.steamGameServers.vrising = {
      enable = true;
      serviceName = "vrising";
      description = "V Rising Dedicated Server";
      appId = steamAppId;
      steamPlatform = "windows";
      installDir = serverDir;
      dataDir = dataDir;
      restartTriggers = [configHash];
      useXvfb = true;
      environment = {
        WINEDEBUG = "-all";
        WINEPREFIX = "${dataDir}/.wine";
      };
      environmentFiles = [config.sops.secrets.vrising_rcon_password.path];
      preStart = ''
        mkdir -p ${dataDir}/Settings
        if [ ! -f ${dataDir}/Settings/ServerHostSettings.json ]; then
          cp ${serverDir}/VRisingServer_Data/StreamingAssets/Settings/ServerHostSettings.json ${dataDir}/Settings/
        fi
        if [ ! -f ${dataDir}/Settings/ServerGameSettings.json ]; then
          cp ${serverDir}/VRisingServer_Data/StreamingAssets/Settings/ServerGameSettings.json ${dataDir}/Settings/
        fi

        cp ${hostSettingsJson} ${dataDir}/Settings/ServerHostSettings.json

        ${lib.optionalString (cfg.preset == "")
          "cp ${gameSettingsJson} ${dataDir}/Settings/ServerGameSettings.json"}
      '';
      script = ''
        ${pkgs.wineWowPackages.stable}/bin/wine64 ${serverDir}/VRisingServer.exe \
          -persistentDataPath ${dataDir} \
          -logFile ${dataDir}/VRisingServer.log 2>&1 | grep -v "XKEYBOARD\|keysym" &

        WINE_PID=$!

        trap "kill $WINE_PID; ${pkgs.wineWowPackages.stable}/bin/wineserver -k; wait" SIGTERM SIGINT

        wait $WINE_PID
      '';
      tmpfilesRules = [
        "e ${dataDir}/Saves/v4/${cfg.worldName}/AutoSave_* - - - ${toString cfg.autosaveRetention}s -"
      ];
      allowedUDPPorts = [cfg.gamePort cfg.queryPort];
    };
  };
}
