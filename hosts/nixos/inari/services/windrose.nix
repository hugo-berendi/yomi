{config, ...}: let
  serverPort = config.yomi.ports.windrose-direct;
  rconPort = config.yomi.ports.windrose-rcon;
  dataDir = "/persist/data/windrose";
in {
  config = {
    virtualisation.oci-containers.containers.windrose = {
      image = "indifferentbroccoli/windrose-server-docker:latest@sha256:644cc3901250d14a10bcd58ffdfe7b88eb2cf6c7d6ff90d6ef01b8ce0dcfa51d";
      ports = ["${toString serverPort}:8489/tcp" "${toString serverPort}:8489/udp" "${toString rconPort}:${toString rconPort}/tcp"];
      volumes = ["${dataDir}/server:/home/steam/server-files"];
      environment = {
        PUID = "1000";
        PGID = "1000";
        STEAM_APP_ID = "4129620";
        SERVER_NAME = "SuckDuck 67 Looksgay";
        MAX_PLAYERS = "4";
        INVITE_CODE = "IAMVERYGAY";
        UPDATE_ON_START = "true";
        USER_SELECTED_REGION = "EU";
        WINDROSE_PLUS_DASHBOARD_PORT = toString rconPort;
        WINDROSE_PLUS_ENABLED = "true";
        WINDROSE_PLUS_VERSION = "1.3.17";
      };
      autoStart = true;
    };

    # Inari runs nftables with networking.firewall disabled, so allowedTCPPorts
    # here would do nothing. Reachability is governed by ../networking/nftables.nix.

    yomi.nginx.at.windrose.port = rconPort;
  };
}
