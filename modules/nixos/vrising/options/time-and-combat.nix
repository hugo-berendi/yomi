{lib, ...}: {
  options.services.vrising.gameSettings = {
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
  };
}
