{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.windrose;
  serverDir = "/persist/data/windrose/server";
  dataDir = "/persist/data/windrose/data";
  steamAppId = "4129620";

  configHash = builtins.hashString "sha256" (builtins.toJSON cfg);
in {
  options.services.windrose = {
    enable = lib.mkEnableOption "Windrose dedicated server";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "Windrose Server";
      description = "Name of the Windrose server";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Server password";
    };

    maxPlayerCount = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Maximum number of connected users";
    };

    worldIslandId = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "World island id to load";
    };

    userSelectedRegion = lib.mkOption {
      type = lib.types.enum ["" "EU" "SEA" "CIS"];
      default = "";
      description = "Region override for connection service";
    };

    p2pProxyAddress = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "IP address used for listening sockets";
    };

    useDirectConnection = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to use direct connection mode";
    };

    directConnectionServerPort = lib.mkOption {
      type = lib.types.port;
      default = 7777;
      description = "Direct connection server port";
    };

    directConnectionProxyAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Direct connection proxy address";
    };

    autoLoadLatestBackupIfHasBroken = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to auto load latest backup for broken saves";
    };

    inviteCode = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional static invite code";
    };

    serviceConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional systemd serviceConfig entries";
    };
  };

  config = lib.mkIf cfg.enable {
    services.steamGameServers.windrose = {
      enable = true;
      serviceName = "windrose";
      description = "Windrose Dedicated Server";
      appId = steamAppId;
      steamPlatform = "windows";
      installDir = serverDir;
      dataDir = dataDir;
      restartTriggers = [
        configHash
      ];
      useXvfb = true;
      environment = {
        WINEDEBUG = "-all";
        WINEPREFIX = "${dataDir}/.wine";
      };
      preStart = ''
        mkdir -p ${serverDir}/R5

        cat > ${serverDir}/R5/ServerDescription.json <<EOF
        {
          "Version": 1,
          "DeploymentId": "",
          "ServerDescription_Persistent": {
            "PersistentServerId": "",
            "IsPasswordProtected": ${lib.boolToString (cfg.password != "")},
            "Password": ${builtins.toJSON cfg.password},
            "ServerName": ${builtins.toJSON cfg.serverName},
            "WorldIslandId": ${builtins.toJSON cfg.worldIslandId},
            "MaxPlayerCount": ${toString cfg.maxPlayerCount},
            "UserSelectedRegion": ${builtins.toJSON cfg.userSelectedRegion},
            "P2pProxyAddress": ${builtins.toJSON cfg.p2pProxyAddress},
            "UseDirectConnection": ${lib.boolToString cfg.useDirectConnection},
            "DirectConnectionServerAddress": "",
            "DirectConnectionServerPort": ${toString cfg.directConnectionServerPort},
            "DirectConnectionProxyAddress": ${builtins.toJSON cfg.directConnectionProxyAddress},
            "AutoLoadLatestBackupIfHasBroken": ${lib.boolToString cfg.autoLoadLatestBackupIfHasBroken}
          }
        }
        EOF
      '';
      script = ''
        mkdir -p ${serverDir}/R5/Saved/Logs
        touch ${serverDir}/R5/Saved/Logs/R5.log

        tail -n0 -F ${serverDir}/R5/Saved/Logs/R5.log | systemd-cat --identifier=windrose-r5 &
        LOG_TAIL_PID=$!

        ${pkgs.wineWowPackages.stable}/bin/wine64 ${serverDir}/R5/Binaries/Win64/WindroseServer-Win64-Shipping.exe -log -Server \
          > >(systemd-cat --identifier=windrose) 2>&1 &

        WINE_PID=$!

        trap "kill $WINE_PID $LOG_TAIL_PID; ${pkgs.wineWowPackages.stable}/bin/wineserver -k; wait" SIGTERM SIGINT

        wait $WINE_PID
        status=$?

        kill "$LOG_TAIL_PID" 2>/dev/null || true
        wait "$LOG_TAIL_PID" 2>/dev/null || true
        exit "$status"
      '';
      allowedTCPPorts = lib.optionals cfg.useDirectConnection [cfg.directConnectionServerPort];
      allowedUDPPorts = lib.optionals cfg.useDirectConnection [cfg.directConnectionServerPort];
      serviceConfig = cfg.serviceConfig;
    };
  };
}
