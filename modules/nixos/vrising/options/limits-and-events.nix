{lib, ...}: {
  options.services.vrising.gameSettings = {
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
}
