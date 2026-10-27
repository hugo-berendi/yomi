{lib, ...}: {
  options.services.vrising.gameSettings = {
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
  };
}
