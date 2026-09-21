{
  config,
  pkgs,
  ...
}: let
  gamePort = config.yomi.ports.valheim;
  queryPort = config.yomi.ports.valheim-query;
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

  # The crossplay join code is regenerated on every server restart and is only
  # ever printed to the container log, so make looking it up a one-liner.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "valheim-join-code" ''
      ${config.virtualisation.docker.package}/bin/docker logs valheim 2>&1 \
        | grep -oE 'join code [0-9]+' \
        | tail -1 \
        | grep -oE '[0-9]+'
    '')
  ];

  virtualisation.oci-containers.containers.valheim = {
    image = "ghcr.io/lloesche/valheim-server:latest@sha256:c885aa902faf885ceb8f69a34663b90519e65aa65fbd9f893451f0640e218a4f";
    autoStart = true;

    # Valheim speaks UDP only, and claims the query port right above the game
    # port. There is no reverse proxy in front of this.
    ports = [
      "${toString gamePort}:${toString gamePort}/udp"
      "${toString queryPort}:${toString queryPort}/udp"
    ];

    volumes = [
      # Worlds, admin lists and backups. The game files below are a 2 GB
      # download the container refreshes on its own.
      "${dataDir}/config:/config"
      "${dataDir}/server:/opt/valheim"
    ];

    environmentFiles = [config.sops.templates."valheim.env".path];

    # Valheim writes the world on SIGTERM. Docker's ten second default killed
    # it mid-save whenever the daemon was restarted, which cost a session on
    # 2026-09-10.
    extraOptions = ["--stop-timeout=120"];

    environment = {
      SERVER_NAME = "SuckDuck";

      # Must match the directory name under config/worlds_local.
      WORLD_NAME = "suckduck";
      SERVER_PORT = toString gamePort;

      # Joining happens through the crossplay join code the server prints on
      # startup, so it does not need to be listed publicly and the router needs
      # no port forward.
      CROSSPLAY = "true";
      SERVER_PUBLIC = "false";

      # World modifiers, spelled out rather than hidden behind a preset so the
      # active rules are readable here. resources=muchmore is the 2x tier;
      # portals=casual lets metals through.
      # -saveinterval bounds how much progress a crash can cost. The default
      # is long enough that a restart between saves loses a whole session.
      SERVER_ARGS = "-saveinterval 300 -modifier combat hard -modifier resources muchmore -modifier portals casual";

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
