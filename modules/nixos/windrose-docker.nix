{
  config,
  lib,
  ...
}: let
  cfg = config.services.windrose-docker;
  serverPort = config.yomi.ports.windrose-direct;
in {
  options.services.windrose-docker = {
    enable = lib.mkEnableOption "Windrose dedicated server (Docker)";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "Windrose Server";
      description = "Name of the Windrose server";
    };

    maxPlayerCount = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Maximum number of connected users";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist/data/windrose";
      description = "Host path for persistent server data";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "indifferentbroccoli/windrose-server-docker:latest";
      description = "Docker image URI for windrose server";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.windrose = {
      image = cfg.image;
      ports = [
        "${toString serverPort}:8489/tcp"
        "${toString serverPort}:8489/udp"
      ];
      volumes = [
        "${cfg.dataDir}:/home/steam/windrose-server"
      ];
      environment = {
        STEAM_APP_ID = "4129620";
        SERVER_NAME = cfg.serverName;
        MAX_PLAYERS = toString cfg.maxPlayerCount;
        PUID = "1000";
        PGID = "1000";
      };
    };

    networking.firewall.allowedTCPPorts = [serverPort];
    networking.firewall.allowedUDPPorts = [serverPort];
  };
}
