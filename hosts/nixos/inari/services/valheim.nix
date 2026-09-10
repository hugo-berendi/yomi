{config, ...}: let
  gamePort = config.yomi.ports.valheim;
  dataDir = "/persist/data/valheim";
in {
  sops.secrets.valheim_server_password.sopsFile = ../secrets.yaml;

  sops.templates."valheim.env".content = ''
    SERVER_PASS=${config.sops.placeholder.valheim_server_password}
  '';

  systemd.tmpfiles.rules = [
    "d ${dataDir}        0755 1000 1000 -"
    "d ${dataDir}/config 0755 1000 1000 -"
    "d ${dataDir}/server 0755 1000 1000 -"
  ];

  virtualisation.oci-containers.containers.valheim = {
    image = "ghcr.io/lloesche/valheim-server:latest";
    autoStart = true;

    # Valheim speaks UDP only, and claims the query port right above the game
    # port. There is no reverse proxy in front of this.
    ports = [
      "${toString gamePort}:${toString gamePort}/udp"
      "${toString (gamePort + 1)}:${toString (gamePort + 1)}/udp"
    ];

    volumes = [
      # Worlds, admin lists and backups. The game files below are a 2 GB
      # download the container refreshes on its own.
      "${dataDir}/config:/config"
      "${dataDir}/server:/opt/valheim"
    ];

    environmentFiles = [config.sops.templates."valheim.env".path];

    environment = {
      SERVER_NAME = "Yomi";
      WORLD_NAME = "Yomi";
      SERVER_PORT = toString gamePort;

      # Joining happens through the crossplay join code the server prints on
      # startup, so it does not need to be listed publicly and the router needs
      # no port forward.
      CROSSPLAY = "true";
      SERVER_PUBLIC = "false";

      BACKUPS = "true";
      BACKUPS_CRON = "0 */6 * * *";
      BACKUPS_MAX_AGE = "30";
      BACKUPS_MAX_COUNT = "0";

      PUID = "1000";
      PGID = "1000";
      TZ = config.time.timeZone;
    };
  };
}
