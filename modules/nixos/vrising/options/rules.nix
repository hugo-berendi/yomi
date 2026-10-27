{lib, ...}: {
  options.services.vrising.gameSettings = {
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
  };
}
