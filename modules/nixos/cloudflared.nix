{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.cloudflared;
  iocaineCfg = config.yomi.iocaine;
  enabled = lib.filterAttrs (_: e: e.enable) cfg.at;
  upstream = e: "${e.protocol}://${e.proxyAddress}:${toString e.port}";
  protected = e:
    if e.enableAnubis
    then "http://127.0.0.1:${toString e.anubis.port}"
    else upstream e;
in {
  options.yomi.cloudflared = {
    tunnel = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare tunnel id to use for the `yomi.cloudflared.at` helper";
    };

    domain = lib.mkOption {
      description = "Root domain to use as a default for configurations.";
      type = lib.types.str;
      default = config.yomi.dns.domain;
    };

    at = lib.mkOption {
      description = "List of hosts to set up ingress rules for";
      default = {};
      type = lib.types.attrsOf (
        lib.types.submodule (
          {config, ...}: {
            options = {
              port = lib.mkOption {
                type = lib.types.port;
                description = "Upstream application port.";
              };
              anubis.port = lib.mkOption {
                type = lib.types.port;
                default = config.port + 200;
                description = "Loopback Anubis listener; checked against the port registry.";
              };
              anubis.metricsPort = lib.mkOption {
                type = lib.types.port;
                default = config.port + 300;
                description = "Loopback Anubis metrics listener.";
              };
              proxyPort = lib.mkOption {
                type = lib.types.port;
                default = config.port + 400;
                description = "Loopback nginx listener when iocaine is enabled.";
              };
              enableAnubis = lib.mkOption {
                description = "Enable Anubis bot protection for this service";
                type = lib.types.bool;
                default = false;
              };

              enableIocaine = lib.mkOption {
                description = "Enable iocaine AI crawler trap for this service";
                type = lib.types.bool;
                default = false;
              };
            };
            imports = [
              (import ./lib/endpoint.nix {
                inherit lib;
                inherit (cfg) domain;
              })
            ];
          }
        )
      );
    };
  };

  config = lib.mkIf (enabled != {}) {
    services.cloudflared.tunnels.${cfg.tunnel}.ingress = lib.mapAttrs' (_: e:
      lib.nameValuePair e.host {
        service =
          if e.enableIocaine
          then "http://127.0.0.1:${toString e.proxyPort}"
          else protected e;
        originRequest.httpHostHeader = e.host;
      })
    enabled;

    services.anubis.instances = lib.mapAttrs' (name: e:
      lib.nameValuePair name {
        enable = true;
        settings = {
          BIND_NETWORK = "tcp";
          BIND = "127.0.0.1:${toString e.anubis.port}";
          METRICS_BIND_NETWORK = "tcp";
          METRICS_BIND = "127.0.0.1:${toString e.anubis.metricsPort}";
          TARGET = upstream e;
          USE_REMOTE_ADDRESS = "true";
        };
      }) (lib.filterAttrs (_: e: e.enableAnubis) enabled);

    yomi.iocaine.enable = lib.mkIf (lib.any (e: e.enableIocaine) (lib.attrValues enabled)) (lib.mkDefault true);
    services.nginx.enable = lib.mkIf (lib.any (e: e.enableIocaine) (lib.attrValues enabled)) true;
    assertions = [
      {
        assertion = !(lib.any (e: e.enableIocaine) (lib.attrValues enabled)) || iocaineCfg.enable;
        message = "Cloudflare iocaine endpoints require yomi.iocaine.enable.";
      }
    ];
    services.nginx.virtualHosts = lib.mapAttrs' (name: e:
      lib.nameValuePair "tunnel-${name}" {
        serverName = e.host;
        listen = [
          {
            addr = "127.0.0.1";
            port = e.proxyPort;
          }
        ];
        extraConfig = iocaineCfg.nginxExtraConfig;
        locations."/" = {
          proxyPass = protected e;
          proxyWebsockets = true;
        };
        locations."/.well-known/@iocaine" = {proxyPass = "http://127.0.0.1:${toString iocaineCfg.port}";};
      }) (lib.filterAttrs (_: e: e.enableIocaine) enabled);

    yomi.ports = lib.mkMerge (lib.mapAttrsToList (name: e:
      lib.mkMerge [
        (lib.mkIf e.enableAnubis {
          "anubis-${name}" = e.anubis.port;
          "anubis-metrics-${name}" = e.anubis.metricsPort;
        })
        (lib.mkIf e.enableIocaine {"tunnel-proxy-${name}" = e.proxyPort;})
      ])
    enabled);

    yomi.dns.records = lib.mapAttrsToList (_: e: {
      type = "CNAME";
      at = e.dns.name;
      zone = e.dns.zone;
      value = "${cfg.tunnel}.cfargotunnel.com.";
      enableCloudflareProxy = true;
    }) (lib.filterAttrs (_: e: e.dns.enable) enabled);
  };
}
