{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.steamGameServers;
in {
  # {{{ Options
  options.services.steamGameServers = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      options = {
        enable = lib.mkEnableOption "Steam game server ${name}";

        serviceName = lib.mkOption {
          type = lib.types.str;
          default = "steam-game-server-${name}";
          description = "Systemd service name for this Steam game server";
        };

        description = lib.mkOption {
          type = lib.types.str;
          default = "Steam game server ${name}";
          description = "Systemd service description";
        };

        appId = lib.mkOption {
          type = lib.types.str;
          description = "Steam app id for this server";
        };

        steamPlatform = lib.mkOption {
          type = lib.types.enum ["linux" "windows"];
          default = "windows";
          description = "Platform type passed to SteamCMD";
        };

        installDir = lib.mkOption {
          type = lib.types.str;
          default = "/persist/data/${name}/server";
          description = "Directory where SteamCMD installs server files";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/persist/data/${name}/data";
          description = "Persistent data directory used by the server";
        };

        updateOnStart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to run SteamCMD app_update during preStart";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "System user running the server";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "System group running the server";
        };

        environment = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Environment variables for the server service";
        };

        environmentFiles = lib.mkOption {
          type = lib.types.listOf lib.types.path;
          default = [];
          description = "Environment files loaded by systemd";
        };

        preStart = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Game-specific preStart script";
        };

        script = lib.mkOption {
          type = lib.types.lines;
          description = "Game server runtime script";
        };

        useXvfb = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to launch Xvfb before running the server";
        };

        xvfbDisplay = lib.mkOption {
          type = lib.types.str;
          default = ":0";
          description = "Display passed to Xvfb";
        };

        xvfbScreen = lib.mkOption {
          type = lib.types.str;
          default = "1024x768x16";
          description = "Screen geometry passed to Xvfb";
        };

        openFirewall = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to open configured firewall ports";
        };

        allowedTCPPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [];
          description = "TCP ports to open for this server";
        };

        allowedUDPPorts = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [];
          description = "UDP ports to open for this server";
        };

        tmpfilesRules = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "Additional tmpfiles rules for this server";
        };

        restartTriggers = lib.mkOption {
          type = lib.types.listOf lib.types.anything;
          default = [];
          description = "Restart triggers for this service";
        };

        wantedBy = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["multi-user.target"];
          description = "Systemd wantedBy targets";
        };

        after = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["network-online.target"];
          description = "Systemd after dependencies";
        };

        wants = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = ["network-online.target"];
          description = "Systemd wants dependencies";
        };

        serviceConfig = lib.mkOption {
          type = lib.types.attrs;
          default = {};
          description = "Additional systemd serviceConfig entries";
        };
      };
    }));
    default = {};
    description = "Multi-instance Steam game server runtime";
  };
  # }}}

  # {{{ Config
  config = {
    users.users = lib.mkMerge (lib.mapAttrsToList (
        name: serverCfg:
          lib.mkIf serverCfg.enable {
            "${serverCfg.user}" = {
              isSystemUser = true;
              group = serverCfg.group;
              home = serverCfg.installDir;
            };
          }
      )
      cfg);

    users.groups = lib.mkMerge (lib.mapAttrsToList (
        name: serverCfg:
          lib.mkIf serverCfg.enable {
            "${serverCfg.group}" = {};
          }
      )
      cfg);

    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (
        name: serverCfg:
          lib.optionals serverCfg.enable (
            [
              "d ${builtins.dirOf serverCfg.installDir} 0755 ${serverCfg.user} ${serverCfg.group} -"
              "d ${serverCfg.installDir} 0755 ${serverCfg.user} ${serverCfg.group} -"
              "d ${serverCfg.dataDir} 0755 ${serverCfg.user} ${serverCfg.group} -"
            ]
            ++ serverCfg.tmpfilesRules
          )
      )
      cfg);

    systemd.services = lib.mkMerge (lib.mapAttrsToList (
        name: serverCfg:
          lib.mkIf serverCfg.enable {
            "${serverCfg.serviceName}" = let
              serviceEnvironment =
                serverCfg.environment
                // (lib.optionalAttrs serverCfg.useXvfb {
                  DISPLAY = serverCfg.xvfbDisplay;
                });

              steamUpdateScript = lib.optionalString serverCfg.updateOnStart ''
                ${pkgs.steamcmd}/bin/steamcmd \
                  +@sSteamCmdForcePlatformType ${serverCfg.steamPlatform} \
                  +force_install_dir ${serverCfg.installDir} \
                  +login anonymous \
                  +app_update ${serverCfg.appId} validate \
                  +quit
              '';

              serviceScript =
                lib.optionalString serverCfg.useXvfb ''
                  rm -f /tmp/.X0-lock || true

                  ${pkgs.xorg.xorgserver}/bin/Xvfb ${serverCfg.xvfbDisplay} -screen 0 ${serverCfg.xvfbScreen} 2>/dev/null &
                  XVFB_PID=$!

                  sleep 2
                ''
                + serverCfg.script
                + lib.optionalString serverCfg.useXvfb ''

                  status=$?
                  kill "$XVFB_PID" 2>/dev/null || true
                  wait "$XVFB_PID" 2>/dev/null || true
                  exit "$status"
                '';
            in {
              description = serverCfg.description;
              wantedBy = serverCfg.wantedBy;
              after = serverCfg.after;
              wants = serverCfg.wants;
              restartTriggers = serverCfg.restartTriggers;

              environment = serviceEnvironment;

              preStart = steamUpdateScript + serverCfg.preStart;

              script = serviceScript;

              serviceConfig =
                {
                  Type = "simple";
                  Restart = "on-failure";
                  RestartSec = "10s";
                  User = serverCfg.user;
                  Group = serverCfg.group;
                  WorkingDirectory = serverCfg.installDir;
                  EnvironmentFile = serverCfg.environmentFiles;
                  ReadWritePaths = [serverCfg.installDir serverCfg.dataDir];
                }
                // serverCfg.serviceConfig;
            };
          }
      )
      cfg);

    networking.firewall.allowedTCPPorts = lib.flatten (lib.mapAttrsToList (
        name: serverCfg:
          lib.optionals (serverCfg.enable && serverCfg.openFirewall) serverCfg.allowedTCPPorts
      )
      cfg);

    networking.firewall.allowedUDPPorts = lib.flatten (lib.mapAttrsToList (
        name: serverCfg:
          lib.optionals (serverCfg.enable && serverCfg.openFirewall) serverCfg.allowedUDPPorts
      )
      cfg);
  };
  # }}}
}
