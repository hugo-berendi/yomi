{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.cloudflared;
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
          {
            name,
            config,
            ...
          }: {
            options = {
              subdomain = lib.mkOption {
                description = ''
                  Subdomain to use for host generation.
                  Only required if `host` is not set manually.
                '';
                type = lib.types.str;
                default = name;
              };

              port = lib.mkOption {
                description = "Localhost port to point the tunnel at";
                type = lib.types.port;
              };

              host = lib.mkOption {
                description = "Host to direct traffic from";
                type = lib.types.str;
                default = "${config.subdomain}.${cfg.domain}";
              };

              protocol = lib.mkOption {
                description = "The protocol to redirect traffic through";
                type = lib.types.str;
                default = "http";
              };

              enableAnubis = lib.mkOption {
                description = "Enable Anubis bot protection for this service";
                type = lib.types.bool;
                default = true;
              };

              url = lib.mkOption {
                description = "External https url used to access this host";
                type = lib.types.str;
              };
            };

            config.url = "https://${config.host}";
          }
        )
      );
    };
  };

  config.services.cloudflared.tunnels.${cfg.tunnel}.ingress =
    lib.attrsets.mapAttrs' (
      name: {
        host,
        subdomain,
        port,
        protocol,
        enableAnubis,
        ...
      }: let
        anubisPort = port + 200;
        targetPort = if enableAnubis then anubisPort else port;
      in {
        name = host;
        value = {
          service = "${protocol}://localhost:${toString targetPort}";
          originRequest = {
            noTLSVerify = protocol != "https";
            httpHostHeader = host;
          };
        };
      }
    )
    cfg.at;

  config.services.anubis.instances = let
    mkAnubisInstance = name: {
      subdomain,
      port,
      protocol,
      enableAnubis,
      ...
    }: let
      anubisPort = port + 200;
      metricsPort = port + 300;
    in {
      name = subdomain;
      value = {
        settings = {
          BIND_NETWORK = "tcp";
          BIND = "127.0.0.1:${toString anubisPort}";
          METRICS_BIND_NETWORK = "tcp";
          METRICS_BIND = "127.0.0.1:${toString metricsPort}";
          TARGET = "${protocol}://localhost:${toString port}";
          USE_REMOTE_ADDRESS = "true";
        };
      };
    };
  in
    lib.attrsets.mapAttrs' mkAnubisInstance (lib.attrsets.filterAttrs (_: cfg: cfg.enableAnubis) cfg.at);

  config.yomi.dns.records = let
    mkDnsRecord = {subdomain, ...}: {
      type = "CNAME";
      at = subdomain;
      zone = cfg.domain;
      value = "${cfg.tunnel}.cfargotunnel.com.";
      enableCloudflareProxy = true;
    };
  in
    lib.attrsets.mapAttrsToList (_: mkDnsRecord) cfg.at;
}
