{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.yomi.expose.mullvadExit;
  blueprint = (pkgs.formats.yaml {}).generate "mullvad-exit.yaml" {
    private-resources.inari-mullvad-exit = {
      name = "Mullvad exit";
      mode = "exit-node";
      users = [config.yomi.pilot.email];
      roles = [];
    };
  };
in {
  options.yomi.expose.mullvadExit = {
    enable = lib.mkEnableOption "a separate Pangolin exit site confined to Inari's existing Mullvad namespace";
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime NEWT_ID/NEWT_SECRET file for a separate Mullvad-only Pangolin site.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.nixarr.vpn.enable && cfg.environmentFile != null && lib.hasPrefix "/" cfg.environmentFile && !lib.hasPrefix "/nix/store/" cfg.environmentFile && cfg.environmentFile != config.yomi.expose.environmentFile;
        message = "Mullvad exit requires the killswitched wg namespace and separate runtime site credentials.";
      }
    ];
    systemd.services.newt-mullvad = {
      description = "Pangolin exit through the existing Mullvad tunnel";
      wantedBy = ["multi-user.target"];
      vpnConfinement = {
        enable = true;
        vpnNamespace = "wg";
      };
      environment.HOME = "/var/lib/private/newt-mullvad";
      serviceConfig = {
        ExecStart = "${lib.getExe config.services.newt.package} --endpoint ${lib.escapeShellArg config.yomi.expose.endpoint} --blueprint-file ${blueprint}";
        EnvironmentFile = cfg.environmentFile;
        DynamicUser = true;
        StateDirectory = "newt-mullvad";
        StateDirectoryMode = "0700";
        Restart = "always";
        RestartSec = "10s";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK"];
        UMask = "0077";
      };
    };
  };
}
