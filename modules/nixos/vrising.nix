{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vrising;
  serverDir = "/persist/data/vrising/server";
  dataDir = "/persist/data/vrising/data";
  steamAppId = "1829350";

  configHash = builtins.hashString "sha256" (builtins.toJSON cfg);

  gameDifficultyToInt = {
    "Relaxed" = 0;
    "Normal" = 1;
    "Hard" = 2;
  };

  gameModeTypeToInt = {
    "PvE" = 0;
    "PvP" = 1;
  };

  castleDamageModeToInt = {
    "Never" = 0;
    "Always" = 1;
    "TimeRestricted" = 2;
  };

  playerDamageModeToInt = {
    "Always" = 0;
    "TimeRestricted" = 1;
  };

  siegeWeaponHealthToInt = {
    "VeryLow" = 0;
    "Low" = 1;
    "Normal" = 2;
    "High" = 3;
    "VeryHigh" = 4;
    "MegaHigh" = 5;
    "UltraHigh" = 6;
    "CrazyHigh" = 7;
    "Max" = 8;
  };

  castleHeartDamageModeToInt = {
    "CanBeDestroyedOnlyWhenDecaying" = 0;
    "CanBeDestroyedByPlayers" = 1;
    "CanBeSeizedOrDestroyedByPlayers" = 2;
  };

  pvpProtectionModeToInt = {
    "Disabled" = 0;
    "VeryShort" = 1;
    "Short" = 2;
    "Medium" = 3;
    "Long" = 4;
  };

  deathContainerPermissionToInt = {
    "Anyone" = 0;
    "ClanMembers" = 1;
    "OnlySelf" = 2;
  };

  relicSpawnTypeToInt = {
    "Unique" = 0;
    "Plentiful" = 1;
  };
in {
  options.services.vrising = {
    enable = lib.mkEnableOption "V Rising dedicated server";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "V Rising Server";
      description = "Name of the V Rising server";
    };

    worldName = lib.mkOption {
      type = lib.types.str;
      default = "World";
      description = "World name";
    };

    maxConnectedUsers = lib.mkOption {
      type = lib.types.int;
      default = 10;
      description = "Maximum number of connected users";
    };

    gamePort = lib.mkOption {
      type = lib.types.port;
      default = 9876;
      description = "Game port (UDP)";
    };

    queryPort = lib.mkOption {
      type = lib.types.port;
      default = 9877;
      description = "Query port (UDP)";
    };

    rconPort = lib.mkOption {
      type = lib.types.port;
      default = 25575;
      description = "RCON port (TCP)";
    };

    saveInterval = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Save interval in seconds";
    };

    autosaveRetention = lib.mkOption {
      type = lib.types.int;
      default = 604800;
      description = "Number of seconds to keep autosave files";
    };

    preset = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Game preset";
    };

    gameSettings = {
      gameDifficulty = lib.mkOption {
        type = lib.types.enum ["Relaxed" "Normal" "Hard"];
        default = "Normal";
        description = "Game difficulty preset";
      };

      gameModeType = lib.mkOption {
        type = lib.types.enum ["PvE" "PvP"];
        default = "PvE";
        description = "Game mode type";
      };

      castleDamageMode = lib.mkOption {
        type = lib.types.enum ["Never" "Always" "TimeRestricted"];
        default = "Never";
        description = "When castles can be damaged";
      };

      playerDamageMode = lib.mkOption {
        type = lib.types.enum ["Always" "TimeRestricted"];
        default = "Always";
        description = "When players can damage each other";
      };

      siegeWeaponHealth = lib.mkOption {
        type = lib.types.enum ["VeryLow" "Low" "Normal" "High" "VeryHigh" "MegaHigh" "UltraHigh" "CrazyHigh" "Max"];
        default = "VeryHigh";
        description = "Health of siege weapons";
      };

      castleHeartDamageMode = lib.mkOption {
        type = lib.types.enum ["CanBeDestroyedOnlyWhenDecaying" "CanBeDestroyedByPlayers" "CanBeSeizedOrDestroyedByPlayers"];
        default = "CanBeDestroyedOnlyWhenDecaying";
        description = "When castle hearts can be damaged";
      };

      pvpProtectionMode = lib.mkOption {
        type = lib.types.enum ["Disabled" "VeryShort" "Short" "Medium" "Long"];
        default = "Short";
        description = "PvP protection duration after spawning";
      };

      deathContainerPermission = lib.mkOption {
        type = lib.types.enum ["Anyone" "ClanMembers" "OnlySelf"];
        default = "ClanMembers";
        description = "Who can loot death containers";
      };

      relicSpawnType = lib.mkOption {
        type = lib.types.enum ["Unique" "Plentiful"];
        default = "Plentiful";
        description = "Relic spawn type";
      };

      canLootEnemyContainers = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether players can loot enemy containers";
      };

      bloodBoundEquipment = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether equipment remains on death";
      };

      teleportBoundItems = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether resource items prevent teleportation";
      };

      batBoundItems = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether resource items prevent bat form";
      };

      batBoundShards = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether soul shards prevent bat form";
      };

      allowGlobalChat = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable global chat";
      };

      allWaypointsUnlocked = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "All waygates unlocked from start";
      };

      freeCastleRaid = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Free castle raiding";
      };

      freeCastleClaim = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "No resource cost for castle claims";
      };

      freeCastleDestroy = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "No resource cost for castle destruction";
      };

      castleRelocationEnabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable castle relocation feature";
      };

      inactivityKillEnabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable killing inactive players";
      };

      inactivityKillTimeMin = lib.mkOption {
        type = lib.types.int;
        default = 3600;
        description = "Minimum inactivity time in seconds before kill";
      };

      inactivityKillTimeMax = lib.mkOption {
        type = lib.types.int;
        default = 86400;
        description = "Maximum inactivity time in seconds before kill";
      };

      inactivityKillTimerMaxItemLevel = lib.mkOption {
        type = lib.types.int;
        default = 84;
        description = "Item level at which max inactivity time applies";
      };

      inactivityKillSafeTimeAddition = lib.mkOption {
        type = lib.types.int;
        default = 1800;
        description = "Additional safe time when logged out in castle";
      };

      disableDisconnectedDeadEnabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Keep disconnected player vulnerable";
      };

      disableDisconnectedDeadTimer = lib.mkOption {
        type = lib.types.int;
        default = 600;
        description = "Timer before disconnected player becomes invulnerable";
      };

      disconnectedSunImmunityTime = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Sun immunity duration after disconnect in seconds";
      };

      inventoryStacksModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Stack size multiplier";
      };

      dropTableModifierGeneral = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "General loot drop rate multiplier";
      };

      dropTableModifierMissions = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Mission loot drop rate multiplier";
      };

      dropTableModifierStygianShards = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Stygian shard drop rate multiplier";
      };

      soulShardDurabilityLossRate = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Soul shard durability loss rate";
      };

      materialYieldModifierGlobal = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Resource harvesting yield multiplier";
      };

      bloodEssenceYieldModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Blood essence yield multiplier";
      };

      pvpVampireRespawnModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "PvP respawn time multiplier";
      };

      clanSize = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Maximum clan size";
      };

      bloodDrainModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Blood drain rate multiplier";
      };

      durabilityDrainModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Durability drain rate multiplier";
      };

      garlicAreaStrengthModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Garlic area effect strength multiplier";
      };

      holyAreaStrengthModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Holy area effect strength multiplier";
      };

      silverStrengthModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Silver damage strength multiplier";
      };

      sunDamageModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Sun damage multiplier";
      };

      castleDecayRateModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Castle decay rate multiplier";
      };

      castleBloodEssenceDrainModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Castle blood essence drain multiplier";
      };

      castleSiegeTimer = lib.mkOption {
        type = lib.types.int;
        default = 420;
        description = "Castle siege duration in seconds";
      };

      castleUnderAttackTimer = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Castle under attack timer in seconds";
      };

      castleRaidTimer = lib.mkOption {
        type = lib.types.int;
        default = 600;
        description = "Castle raid timer in seconds";
      };

      castleRaidProtectionTime = lib.mkOption {
        type = lib.types.int;
        default = 1800;
        description = "Castle raid protection time in seconds";
      };

      castleExposedFreeClaimTimer = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Free claim timer for exposed castles in seconds";
      };

      castleRelocationCooldown = lib.mkOption {
        type = lib.types.int;
        default = 259200;
        description = "Castle relocation cooldown in seconds";
      };

      announceSiegeWeaponSpawn = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Announce siege weapon spawns";
      };

      showSiegeWeaponMapIcon = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show siege weapons on map";
      };

      buildCostModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Building cost multiplier";
      };

      recipeCostModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Recipe cost multiplier";
      };

      craftRateModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Crafting speed multiplier";
      };

      refinementCostModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Refinement cost multiplier";
      };

      refinementRateModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Refinement speed multiplier";
      };

      researchCostModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Research cost multiplier";
      };

      dismantleResourceModifier = lib.mkOption {
        type = lib.types.float;
        default = 0.75;
        description = "Resource return on dismantle multiplier";
      };

      servantConvertRateModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Servant conversion speed multiplier";
      };

      repairCostModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Repair cost multiplier";
      };

      deathDurabilityFactorLoss = lib.mkOption {
        type = lib.types.float;
        default = 0.125;
        description = "Durability loss on death";
      };

      deathDurabilityLossFactorAsResources = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Percentage of durability lost as resources";
      };

      dayDurationInSeconds = lib.mkOption {
        type = lib.types.int;
        default = 1080;
        description = "Day/night cycle duration in seconds";
      };

      dayStartHour = lib.mkOption {
        type = lib.types.int;
        default = 9;
        description = "Hour when day starts (0-23)";
      };

      dayStartMinute = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Minute when day starts (0-59)";
      };

      dayEndHour = lib.mkOption {
        type = lib.types.int;
        default = 17;
        description = "Hour when day ends (0-23)";
      };

      dayEndMinute = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Minute when day ends (0-59)";
      };

      bloodMoonFrequencyMin = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Minimum days between blood moons";
      };

      bloodMoonFrequencyMax = lib.mkOption {
        type = lib.types.int;
        default = 18;
        description = "Maximum days between blood moons";
      };

      bloodMoonBuff = lib.mkOption {
        type = lib.types.float;
        default = 0.2;
        description = "Blood moon stat buff multiplier";
      };

      vampireMaxHealthModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Vampire max health multiplier";
      };

      vampirePhysicalPowerModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Vampire physical power multiplier";
      };

      vampireSpellPowerModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Vampire spell power multiplier";
      };

      vampireResourcePowerModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Vampire resource harvesting power multiplier";
      };

      vampireDamageReceivedModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Vampire damage received multiplier";
      };

      vampireReviveCancelDelay = lib.mkOption {
        type = lib.types.float;
        default = 5.0;
        description = "Delay before revive can be cancelled (seconds)";
      };

      unitMaxHealthModifierGlobal = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Global enemy max health multiplier";
      };

      unitPowerModifierGlobal = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Global enemy power multiplier";
      };

      unitLevelIncreaseGlobal = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Global enemy level increase";
      };

      unitMaxHealthModifierVBlood = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "V Blood enemy max health multiplier";
      };

      unitPowerModifierVBlood = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "V Blood enemy power multiplier";
      };

      unitLevelIncreaseVBlood = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "V Blood enemy level increase";
      };

      equipmentMaxHealthModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Equipment max health bonus multiplier";
      };

      equipmentResourceYieldModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Equipment resource yield bonus multiplier";
      };

      equipmentPhysicalPowerModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Equipment physical power bonus multiplier";
      };

      equipmentSpellPowerModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Equipment spell power bonus multiplier";
      };

      equipmentSiegePowerModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Equipment siege power bonus multiplier";
      };

      castleTickPeriod = lib.mkOption {
        type = lib.types.float;
        default = 5.0;
        description = "How often castle checks run (seconds)";
      };

      castleSafetyBoxLimit = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Maximum vampire lockboxes per castle";
      };

      castleTombLimit = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Maximum tombs per castle";
      };

      castleVerminNestLimit = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Maximum vermin nests per castle";
      };

      castleNetherGateLimit = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Maximum Stygian summoning circles per castle";
      };

      castlePrisonCellLimit = lib.mkOption {
        type = lib.types.int;
        default = 16;
        description = "Maximum prison cells per castle";
      };

      castleEyeStructuresLimit = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Maximum Eye of Twilight structures per castle";
      };

      castleLimit = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Maximum number of castles per user/clan";
      };

      castleThroneOfDarknessLimit = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Maximum Throne of Darkness structures per castle";
      };

      castleHeartLevel1FloorLimit = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Floor limit for castle heart level 1";
      };

      castleHeartLevel1ServantLimit = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Servant limit for castle heart level 1";
      };

      castleHeartLevel1HeightLimit = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Height limit for castle heart level 1";
      };

      castleHeartLevel2FloorLimit = lib.mkOption {
        type = lib.types.int;
        default = 80;
        description = "Floor limit for castle heart level 2";
      };

      castleHeartLevel2ServantLimit = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Servant limit for castle heart level 2";
      };

      castleHeartLevel2HeightLimit = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Height limit for castle heart level 2";
      };

      castleHeartLevel3FloorLimit = lib.mkOption {
        type = lib.types.int;
        default = 150;
        description = "Floor limit for castle heart level 3";
      };

      castleHeartLevel3ServantLimit = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "Servant limit for castle heart level 3";
      };

      castleHeartLevel3HeightLimit = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Height limit for castle heart level 3";
      };

      castleHeartLevel4FloorLimit = lib.mkOption {
        type = lib.types.int;
        default = 250;
        description = "Floor limit for castle heart level 4";
      };

      castleHeartLevel4ServantLimit = lib.mkOption {
        type = lib.types.int;
        default = 9;
        description = "Servant limit for castle heart level 4";
      };

      castleHeartLevel4HeightLimit = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Height limit for castle heart level 4";
      };

      castleHeartLevel5FloorLimit = lib.mkOption {
        type = lib.types.int;
        default = 400;
        description = "Floor limit for castle heart level 5";
      };

      castleHeartLevel5ServantLimit = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Servant limit for castle heart level 5";
      };

      castleHeartLevel5HeightLimit = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Height limit for castle heart level 5";
      };

      traderStockModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Trader stock quantity multiplier";
      };

      traderPriceModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Trader price multiplier";
      };

      traderRestockTimerModifier = lib.mkOption {
        type = lib.types.float;
        default = 1.0;
        description = "Trader restock speed multiplier";
      };

      warEventInterval = lib.mkOption {
        type = lib.types.enum ["Minimum" "VeryShort" "Short" "Medium" "Long" "VeryLong" "Extensive" "Maximum"];
        default = "Medium";
        description = "Time between war events (Rift Incursions)";
      };

      warEventMajorDuration = lib.mkOption {
        type = lib.types.enum ["Minimum" "VeryShort" "Short" "Medium" "Long" "VeryLong" "Extensive" "Maximum"];
        default = "Medium";
        description = "Duration of major war events";
      };

      warEventMinorDuration = lib.mkOption {
        type = lib.types.enum ["Minimum" "VeryShort" "Short" "Medium" "Long" "VeryLong" "Extensive" "Maximum"];
        default = "Medium";
        description = "Duration of minor war events";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # assertions = [
    #   {
    #     assertion = (cfg.preset != "" || cfg.preset != null) && cfg.gameSettings == config._module.config.services.vrising.gameSettings;
    #     message = "When preset is set, all gameSettings must remain at their default values. Use either preset or custom gameSettings, not both.";
    #   }
    # ];

    sops.secrets.vrising_rcon_password = {
      sopsFile = ../../hosts/nixos/inari/secrets.yaml;
    };

    systemd.services.vrising = {
      description = "V Rising Dedicated Server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      restartTriggers = [
        configHash
      ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "vrising";
        Group = "vrising";
        WorkingDirectory = serverDir;
        EnvironmentFile = config.sops.secrets.vrising_rcon_password.path;
      };

      environment = {
        WINEDEBUG = "-all";
        WINEPREFIX = "${dataDir}/.wine";
        DISPLAY = ":0";
      };

      preStart = ''
        ${pkgs.steamcmd}/bin/steamcmd \
          +@sSteamCmdForcePlatformType windows \
          +force_install_dir ${serverDir} \
          +login anonymous \
          +app_update ${steamAppId} validate \
          +quit

        mkdir -p ${dataDir}/Settings
        if [ ! -f ${dataDir}/Settings/ServerHostSettings.json ]; then
          cp ${serverDir}/VRisingServer_Data/StreamingAssets/Settings/ServerHostSettings.json ${dataDir}/Settings/
        fi
        if [ ! -f ${dataDir}/Settings/ServerGameSettings.json ]; then
          cp ${serverDir}/VRisingServer_Data/StreamingAssets/Settings/ServerGameSettings.json ${dataDir}/Settings/
        fi

        cat > ${dataDir}/Settings/ServerHostSettings.json <<EOF
        {
          "Name": "${cfg.serverName}",
          "Description": "",
          "Port": ${toString cfg.gamePort},
          "QueryPort": ${toString cfg.queryPort},
          "MaxConnectedUsers": ${toString cfg.maxConnectedUsers},
          "MaxConnectedAdmins": 4,
          "ServerFps": 30,
          "SaveName": "${cfg.worldName}",
          "Password": "",
          "Secure": true,
          "ListOnMasterServer": false,
          "ListOnSteam": false,
          "ListOnEOS": false,
          "AutoSaveCount": 20,
          "AutoSaveInterval": ${toString cfg.saveInterval},
          "CompressSaveFiles": true,
          "GameSettingsPreset": "${cfg.preset}",
          "GameDifficultyPreset": "",
          "AdminOnlyDebugEvents": true,
          "DisableDebugEvents": false,
          "API": {
            "Enabled": false
          },
          "Rcon": {
            "Enabled": ${
          if cfg.rconPort != 0
          then "true"
          else "false"
        },
            "Port": ${toString cfg.rconPort},
            "Password": "\$RCON_PASSWORD"
          }
        }
        EOF

        ${lib.optionalString (cfg.preset == "") ''
          cat > ${dataDir}/Settings/ServerGameSettings.json <<EOF
          {
            "GameDifficulty": ${toString gameDifficultyToInt.${cfg.gameSettings.gameDifficulty}},
            "GameModeType": ${toString gameModeTypeToInt.${cfg.gameSettings.gameModeType}},
            "CastleDamageMode": ${toString castleDamageModeToInt.${cfg.gameSettings.castleDamageMode}},
            "PlayerDamageMode": ${toString playerDamageModeToInt.${cfg.gameSettings.playerDamageMode}},
            "SiegeWeaponHealth": ${toString siegeWeaponHealthToInt.${cfg.gameSettings.siegeWeaponHealth}},
            "CastleHeartDamageMode": ${toString castleHeartDamageModeToInt.${cfg.gameSettings.castleHeartDamageMode}},
            "PvPProtectionMode": ${toString pvpProtectionModeToInt.${cfg.gameSettings.pvpProtectionMode}},
            "DeathContainerPermission": ${toString deathContainerPermissionToInt.${cfg.gameSettings.deathContainerPermission}},
            "RelicSpawnType": ${toString relicSpawnTypeToInt.${cfg.gameSettings.relicSpawnType}},
            "CanLootEnemyContainers": ${lib.boolToString cfg.gameSettings.canLootEnemyContainers},
            "BloodBoundEquipment": ${lib.boolToString cfg.gameSettings.bloodBoundEquipment},
            "TeleportBoundItems": ${lib.boolToString cfg.gameSettings.teleportBoundItems},
            "BatBoundItems": ${lib.boolToString cfg.gameSettings.batBoundItems},
            "BatBoundShards": ${lib.boolToString cfg.gameSettings.batBoundShards},
            "AllowGlobalChat": ${lib.boolToString cfg.gameSettings.allowGlobalChat},
            "AllWaypointsUnlocked": ${lib.boolToString cfg.gameSettings.allWaypointsUnlocked},
            "FreeCastleRaid": ${lib.boolToString cfg.gameSettings.freeCastleRaid},
            "FreeCastleClaim": ${lib.boolToString cfg.gameSettings.freeCastleClaim},
            "FreeCastleDestroy": ${lib.boolToString cfg.gameSettings.freeCastleDestroy},
            "CastleRelocationEnabled": ${lib.boolToString cfg.gameSettings.castleRelocationEnabled},
            "InactivityKillEnabled": ${lib.boolToString cfg.gameSettings.inactivityKillEnabled},
            "InactivityKillTimeMin": ${toString cfg.gameSettings.inactivityKillTimeMin},
            "InactivityKillTimeMax": ${toString cfg.gameSettings.inactivityKillTimeMax},
            "InactivityKillTimerMaxItemLevel": ${toString cfg.gameSettings.inactivityKillTimerMaxItemLevel},
            "InactivityKillSafeTimeAddition": ${toString cfg.gameSettings.inactivityKillSafeTimeAddition},
            "DisableDisconnectedDeadEnabled": ${lib.boolToString cfg.gameSettings.disableDisconnectedDeadEnabled},
            "DisableDisconnectedDeadTimer": ${toString cfg.gameSettings.disableDisconnectedDeadTimer},
            "DisconnectedSunImmunityTime": ${toString cfg.gameSettings.disconnectedSunImmunityTime},
            "InventoryStacksModifier": ${toString cfg.gameSettings.inventoryStacksModifier},
            "DropTableModifier_General": ${toString cfg.gameSettings.dropTableModifierGeneral},
            "DropTableModifier_Missions": ${toString cfg.gameSettings.dropTableModifierMissions},
            "DropTableModifier_StygianShards": ${toString cfg.gameSettings.dropTableModifierStygianShards},
            "SoulShard_DurabilityLossRate": ${toString cfg.gameSettings.soulShardDurabilityLossRate},
            "MaterialYieldModifier_Global": ${toString cfg.gameSettings.materialYieldModifierGlobal},
            "BloodEssenceYieldModifier": ${toString cfg.gameSettings.bloodEssenceYieldModifier},
            "PvPVampireRespawnModifier": ${toString cfg.gameSettings.pvpVampireRespawnModifier},
            "ClanSize": ${toString cfg.gameSettings.clanSize},
            "BloodDrainModifier": ${toString cfg.gameSettings.bloodDrainModifier},
            "DurabilityDrainModifier": ${toString cfg.gameSettings.durabilityDrainModifier},
            "GarlicAreaStrengthModifier": ${toString cfg.gameSettings.garlicAreaStrengthModifier},
            "HolyAreaStrengthModifier": ${toString cfg.gameSettings.holyAreaStrengthModifier},
            "SilverStrengthModifier": ${toString cfg.gameSettings.silverStrengthModifier},
            "SunDamageModifier": ${toString cfg.gameSettings.sunDamageModifier},
            "CastleDecayRateModifier": ${toString cfg.gameSettings.castleDecayRateModifier},
            "CastleBloodEssenceDrainModifier": ${toString cfg.gameSettings.castleBloodEssenceDrainModifier},
            "CastleSiegeTimer": ${toString cfg.gameSettings.castleSiegeTimer},
            "CastleUnderAttackTimer": ${toString cfg.gameSettings.castleUnderAttackTimer},
            "CastleRaidTimer": ${toString cfg.gameSettings.castleRaidTimer},
            "CastleRaidProtectionTime": ${toString cfg.gameSettings.castleRaidProtectionTime},
            "CastleExposedFreeClaimTimer": ${toString cfg.gameSettings.castleExposedFreeClaimTimer},
            "CastleRelocationCooldown": ${toString cfg.gameSettings.castleRelocationCooldown},
            "AnnounceSiegeWeaponSpawn": ${lib.boolToString cfg.gameSettings.announceSiegeWeaponSpawn},
            "ShowSiegeWeaponMapIcon": ${lib.boolToString cfg.gameSettings.showSiegeWeaponMapIcon},
            "BuildCostModifier": ${toString cfg.gameSettings.buildCostModifier},
            "RecipeCostModifier": ${toString cfg.gameSettings.recipeCostModifier},
            "CraftRateModifier": ${toString cfg.gameSettings.craftRateModifier},
            "RefinementCostModifier": ${toString cfg.gameSettings.refinementCostModifier},
            "RefinementRateModifier": ${toString cfg.gameSettings.refinementRateModifier},
            "ResearchCostModifier": ${toString cfg.gameSettings.researchCostModifier},
            "DismantleResourceModifier": ${toString cfg.gameSettings.dismantleResourceModifier},
            "ServantConvertRateModifier": ${toString cfg.gameSettings.servantConvertRateModifier},
            "RepairCostModifier": ${toString cfg.gameSettings.repairCostModifier},
            "Death_DurabilityFactorLoss": ${toString cfg.gameSettings.deathDurabilityFactorLoss},
            "Death_DurabilityLossFactorAsResources": ${toString cfg.gameSettings.deathDurabilityLossFactorAsResources},
            "VampireStatModifiers": {
              "MaxHealth": ${toString cfg.gameSettings.vampireMaxHealthModifier},
              "PhysicalPower": ${toString cfg.gameSettings.vampirePhysicalPowerModifier},
              "SpellPower": ${toString cfg.gameSettings.vampireSpellPowerModifier},
              "ResourcePower": ${toString cfg.gameSettings.vampireResourcePowerModifier},
              "DamageReceived": ${toString cfg.gameSettings.vampireDamageReceivedModifier},
              "ReviveCancelDelay": ${toString cfg.gameSettings.vampireReviveCancelDelay}
            },
            "UnitStatModifiers_Global": {
              "MaxHealth": ${toString cfg.gameSettings.unitMaxHealthModifierGlobal},
              "Power": ${toString cfg.gameSettings.unitPowerModifierGlobal},
              "LevelIncrease": ${toString cfg.gameSettings.unitLevelIncreaseGlobal}
            },
            "UnitStatModifiers_VBlood": {
              "MaxHealth": ${toString cfg.gameSettings.unitMaxHealthModifierVBlood},
              "Power": ${toString cfg.gameSettings.unitPowerModifierVBlood},
              "LevelIncrease": ${toString cfg.gameSettings.unitLevelIncreaseVBlood}
            },
            "EquipmentStatModifiers_Global": {
              "MaxHealth": ${toString cfg.gameSettings.equipmentMaxHealthModifier},
              "ResourceYield": ${toString cfg.gameSettings.equipmentResourceYieldModifier},
              "PhysicalPower": ${toString cfg.gameSettings.equipmentPhysicalPowerModifier},
              "SpellPower": ${toString cfg.gameSettings.equipmentSpellPowerModifier},
              "SiegePower": ${toString cfg.gameSettings.equipmentSiegePowerModifier}
            },
            "CastleStatModifiers_Global": {
              "TickPeriod": ${toString cfg.gameSettings.castleTickPeriod},
              "SafetyBoxLimit": ${toString cfg.gameSettings.castleSafetyBoxLimit},
              "TombLimit": ${toString cfg.gameSettings.castleTombLimit},
              "VerminNestLimit": ${toString cfg.gameSettings.castleVerminNestLimit},
              "NetherGateLimit": ${toString cfg.gameSettings.castleNetherGateLimit},
              "PrisonCellLimit": ${toString cfg.gameSettings.castlePrisonCellLimit},
              "EyeStructuresLimit": ${toString cfg.gameSettings.castleEyeStructuresLimit},
              "CastleLimit": ${toString cfg.gameSettings.castleLimit},
              "ThroneOfDarknessLimit": ${toString cfg.gameSettings.castleThroneOfDarknessLimit},
              "HeartLimits": {
                "Level1": {
                  "FloorLimit": ${toString cfg.gameSettings.castleHeartLevel1FloorLimit},
                  "ServantLimit": ${toString cfg.gameSettings.castleHeartLevel1ServantLimit},
                  "HeightLimit": ${toString cfg.gameSettings.castleHeartLevel1HeightLimit}
                },
                "Level2": {
                  "FloorLimit": ${toString cfg.gameSettings.castleHeartLevel2FloorLimit},
                  "ServantLimit": ${toString cfg.gameSettings.castleHeartLevel2ServantLimit},
                  "HeightLimit": ${toString cfg.gameSettings.castleHeartLevel2HeightLimit}
                },
                "Level3": {
                  "FloorLimit": ${toString cfg.gameSettings.castleHeartLevel3FloorLimit},
                  "ServantLimit": ${toString cfg.gameSettings.castleHeartLevel3ServantLimit},
                  "HeightLimit": ${toString cfg.gameSettings.castleHeartLevel3HeightLimit}
                },
                "Level4": {
                  "FloorLimit": ${toString cfg.gameSettings.castleHeartLevel4FloorLimit},
                  "ServantLimit": ${toString cfg.gameSettings.castleHeartLevel4ServantLimit},
                  "HeightLimit": ${toString cfg.gameSettings.castleHeartLevel4HeightLimit}
                },
                "Level5": {
                  "FloorLimit": ${toString cfg.gameSettings.castleHeartLevel5FloorLimit},
                  "ServantLimit": ${toString cfg.gameSettings.castleHeartLevel5ServantLimit},
                  "HeightLimit": ${toString cfg.gameSettings.castleHeartLevel5HeightLimit}
                }
              }
            },
            "TraderModifiers": {
              "StockModifier": ${toString cfg.gameSettings.traderStockModifier},
              "PriceModifier": ${toString cfg.gameSettings.traderPriceModifier},
              "RestockTimerModifier": ${toString cfg.gameSettings.traderRestockTimerModifier}
            },
            "WarEventGameSettings": {
              "Interval": "${cfg.gameSettings.warEventInterval}",
              "MajorDuration": "${cfg.gameSettings.warEventMajorDuration}",
              "MinorDuration": "${cfg.gameSettings.warEventMinorDuration}"
            },
            "GameTimeModifiers": {
              "DayDurationInSeconds": ${toString cfg.gameSettings.dayDurationInSeconds},
              "DayStartHour": ${toString cfg.gameSettings.dayStartHour},
              "DayStartMinute": ${toString cfg.gameSettings.dayStartMinute},
              "DayEndHour": ${toString cfg.gameSettings.dayEndHour},
              "DayEndMinute": ${toString cfg.gameSettings.dayEndMinute},
              "BloodMoonFrequency_Min": ${toString cfg.gameSettings.bloodMoonFrequencyMin},
              "BloodMoonFrequency_Max": ${toString cfg.gameSettings.bloodMoonFrequencyMax},
              "BloodMoonBuff": ${toString cfg.gameSettings.bloodMoonBuff}
            }
          }
          EOF
        ''}
      '';

      script = ''
        rm -f /tmp/.X0-lock || true

        ${pkgs.xorg.xorgserver}/bin/Xvfb :0 -screen 0 1024x768x16 2>/dev/null &
        XVFB_PID=$!

        sleep 2

        ${pkgs.wineWowPackages.stable}/bin/wine64 ${serverDir}/VRisingServer.exe \
          -persistentDataPath ${dataDir} \
          -logFile ${dataDir}/VRisingServer.log 2>&1 | grep -v "XKEYBOARD\|keysym" &

        WINE_PID=$!

        trap "kill $WINE_PID $XVFB_PID; ${pkgs.wineWowPackages.stable}/bin/wineserver -k; wait" SIGTERM SIGINT

        wait $WINE_PID
        kill $XVFB_PID
      '';
    };

    users.users.vrising = {
      isSystemUser = true;
      group = "vrising";
      home = serverDir;
    };

    users.groups.vrising = {};

    systemd.tmpfiles.rules = [
      "d /persist/data/vrising 0755 vrising vrising -"
      "d ${serverDir} 0755 vrising vrising -"
      "d ${dataDir} 0755 vrising vrising -"
      "e ${dataDir}/Saves/v4/${cfg.worldName}/AutoSave_* - - - ${toString cfg.autosaveRetention}s -"
    ];

    networking.firewall.allowedUDPPorts = [cfg.gamePort cfg.queryPort];
  };
}
