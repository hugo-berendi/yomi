{lib, ...}: {
  options.services.vrising = {
    enable = lib.mkEnableOption "V Rising dedicated server";

    sopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Sops file containing the vrising_rcon_password secret. Must be set when enable is true.";
    };

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
}
