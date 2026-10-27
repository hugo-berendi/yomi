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
  };
}
