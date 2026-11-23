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
    type = lib.types.attrsOf (lib.types.submodule (import ./instance-options.nix {inherit lib;}));
    default = {};
    description = "Multi-instance Steam game server runtime";
  };
  # }}}

  # {{{ Config
  config = {
    users.users = lib.mkMerge (lib.mapAttrsToList (
        _name: serverCfg:
          lib.mkIf serverCfg.enable {
            "${serverCfg.user}" = {
              isSystemUser = true;
              inherit (serverCfg) group;
              home = serverCfg.installDir;
            };
          }
      )
      cfg);

    users.groups = lib.mkMerge (lib.mapAttrsToList (
        _name: serverCfg:
          lib.mkIf serverCfg.enable {
            "${serverCfg.group}" = {};
          }
      )
      cfg);

    systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList (
        _name: serverCfg:
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
        _name: serverCfg:
          lib.mkIf serverCfg.enable {
            "${serverCfg.serviceName}" = let
              serviceEnvironment =
                serverCfg.environment
                // (lib.optionalAttrs (serverCfg.wine != null) {
                  WINEPREFIX = serverCfg.winePrefix;
                })
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

              # Wine updates a prefix only when .update-timestamp differs from
              # wine.inf's mtime, and everything in the store has mtime 1 - so
              # after a wine bump the prefix keeps the old DLLs forever. Wine 11
              # then aborted V Rising: advapi32 forwards SystemFunction036 to a
              # cryptbase.dll the January prefix never got. `wineboot -u` is no
              # way out: it needs the same DLL, and crash-loops spawning winedbg.
              # The servers keep their state outside the prefix, so a prefix
              # built by another wine is moved aside and recreated on start.
              winePrefixScript = lib.optionalString (serverCfg.wine != null) ''
                prefix=${serverCfg.winePrefix}
                if [ -d "$prefix" ] && [ "$(cat "$prefix/.nix-wine" 2>/dev/null)" != ${serverCfg.wine} ]; then
                  echo "$prefix was built by another wine, moving it to $prefix.stale"
                  rm -rf "$prefix.stale"
                  mv "$prefix" "$prefix.stale"
                fi
                if [ ! -d "$prefix" ]; then
                  ${serverCfg.wine}/bin/wineboot -i
                  ${serverCfg.wine}/bin/wineserver -w
                  echo ${serverCfg.wine} > "$prefix/.nix-wine"
                fi
              '';

              serviceScript =
                lib.optionalString serverCfg.useXvfb ''
                  rm -f /tmp/.X0-lock || true

                  ${pkgs.xorg-server}/bin/Xvfb ${serverCfg.xvfbDisplay} -screen 0 ${serverCfg.xvfbScreen} 2>/dev/null &
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
              inherit (serverCfg) description;
              inherit (serverCfg) wantedBy;
              inherit (serverCfg) after;
              inherit (serverCfg) wants;
              inherit (serverCfg) restartTriggers;

              environment = serviceEnvironment;

              preStart = steamUpdateScript + winePrefixScript + serverCfg.preStart;

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
        _name: serverCfg:
          lib.optionals (serverCfg.enable && serverCfg.openFirewall) serverCfg.allowedTCPPorts
      )
      cfg);

    networking.firewall.allowedUDPPorts = lib.flatten (lib.mapAttrsToList (
        _name: serverCfg:
          lib.optionals (serverCfg.enable && serverCfg.openFirewall) serverCfg.allowedUDPPorts
      )
      cfg);
  };
  # }}}
}
