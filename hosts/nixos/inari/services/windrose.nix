{
  config,
  lib,
  pkgs,
  ...
}: let
  serverPort = config.yomi.ports.windrose-direct;
  dataDir = "/persist/data/windrose";
in {
  config = {
    virtualisation.oci-containers.containers.windrose = {
      image = "indifferentbroccoli/windrose-server-docker:latest";
      ports = [ "${toString serverPort}:8489/tcp" "${toString serverPort}:8489/udp" ];
      volumes = [ "${dataDir}/server:/home/steam/server-files" ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        STEAM_APP_ID = "4129620";
        SERVER_NAME = "SuckDuck 67 Looksgay";
        MAX_PLAYERS = "4";
        INVITE_CODE = "9974f9b2";
        UPDATE_ON_START = "true";
        WINDROSE_PLUS_ENABLED = "true";
        WINDROSE_PLUS_VERSION = "latest";
      };
      autoStart = true;
    };

    networking.firewall.allowedTCPPorts = [ serverPort ];
    networking.firewall.allowedUDPPorts = [ serverPort ];
  };
}
