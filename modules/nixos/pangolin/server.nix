{
  config,
  lib,
  outputs,
  ...
}: let
  cfg = config.yomi.pangolin.server;
  sites = map (name: outputs.nixosConfigurations.${name}.config.yomi.pangolin) cfg.sourceHosts;
  listeners = lib.concatMap (site: site.listeners) sites;
  listenerKey = e: "${e.protocol}-${toString e.port}";
  ports = protocol: map (e: e.port) (lib.filter (e: e.protocol == protocol) listeners);
  webHosts = lib.concatMap (site: map (e: e.host) (lib.attrValues (lib.filterAttrs (_: e: e.enable) site.at))) sites;
in {
  options.yomi.pangolin.server = {
    enable = lib.mkEnableOption "the public Pangolin gateway";
    sourceHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Yomi hosts whose resource definitions determine public listeners.";
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime SERVER_SECRET environment file for Pangolin.";
    };
    listeners = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      default = listeners;
      description = "Aggregated public TCP/UDP listeners, including staged sites.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.environmentFile != null && lib.hasPrefix "/" cfg.environmentFile && !lib.hasPrefix "/nix/store/" cfg.environmentFile;
        message = "Pangolin gateway requires a runtime environmentFile with SERVER_SECRET.";
      }
      {
        assertion = builtins.length listeners == builtins.length (lib.unique (map listenerKey listeners));
        message = "Pangolin public ports must be unique per protocol across all sites.";
      }
      {
        assertion = !lib.any (port: lib.elem port [22 80 443 3000 3001 3002 3003 3004 3005]) (ports "tcp") && !lib.any (port: lib.elem port [21820 51820]) (ports "udp");
        message = "Pangolin raw ports must not collide with SSH, Web or gateway control/tunnel ports.";
      }
      {
        assertion = builtins.length webHosts == builtins.length (lib.unique webHosts) && !lib.elem config.services.pangolin.dashboardDomain webHosts;
        message = "Pangolin public domains must be unique across sites and distinct from its dashboard.";
      }
    ];

    services.pangolin = {
      enable = true;
      baseDomain = config.yomi.pangolin.domain;
      letsEncryptEmail = config.yomi.pilot.email;
      inherit (cfg) environmentFile;
      openFirewall = true;
      settings = {
        flags = {
          allow_raw_resources = listeners != [];
          disable_signup_without_invite = true;
          disable_user_create_org = true;
        };
        app = {
          telemetry.anonymous_usage = false;
          save_logs = false;
        };
      };
    };
    services.traefik.staticConfigOptions.entryPoints = builtins.listToAttrs (map (e:
      lib.nameValuePair (listenerKey e) {
        address = ":${toString e.port}/${e.protocol}";
      })
    listeners);
    networking.firewall = {
      allowedTCPPorts = ports "tcp";
      allowedUDPPorts = [21820] ++ ports "udp";
    };
  };
}
