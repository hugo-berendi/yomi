{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.nginx;
in {
  options.yomi.nginx = {
    domain = lib.mkOption {
      description = "Root domain to use as a default for configurations.";
      type = lib.types.str;
      default = config.yomi.dns.domain;
    };

    at = lib.mkOption {
      description = "Per-subdomain nginx configuration";
      type = lib.types.attrsOf (lib.types.submodule ({
        name,
        config,
        ...
      }: {
        options.subdomain = lib.mkOption {
          description = ''
            Subdomain to use for host generation.
            Only required if `host` is not set manually.
          '';
          type = lib.types.str;
          default = name;
        };

        options.host = lib.mkOption {
          description = "Host to route requests from";
          type = lib.types.str;
        };

        config.host = "${config.subdomain}.${cfg.domain}";

        options.url = lib.mkOption {
          description = "External https url used to access this host";
          type = lib.types.str;
        };

        config.url = "https://${config.host}";

        options.port = lib.mkOption {
          description = "Port to proxy requests to";
          type = lib.types.nullOr lib.types.port;
          default = null;
        };

        options.files = lib.mkOption {
          description = "Path to serve files from";
          type = lib.types.nullOr lib.types.path;
          default = null;
        };
      }));
      default = {};
    };
  };

  config = {
    assertions = let
      assertSingleTarget = config: {
        assertion = (config.port == null) == (config.files != null);
        message = ''
          Precisely one of the options 'yomi.nginx.at.${config.subdomain}.port'
          and 'yomi.nginx.at.${config.subdomain}.files' must be specified.
        '';
      };
    in
      lib.mapAttrsToList (_: assertSingleTarget) cfg.at;

    services.nginx.virtualHosts = let
      mkNginxConfig = {
        host,
        port,
        files,
        subdomain,
        ...
      }: {
        name = host;
        value = let
          extra =
            if port != null
            then {
              locations."/" = {
                proxyPass = "http://localhost:${toString (port + 200)}";
                proxyWebsockets = true;
              };
            }
            else {
              root = files;
            };
        in
          {
            enableACME = true;
            acmeRoot = null;
            forceSSL = true;
          }
          // extra;
      };
    in
      lib.attrsets.mapAttrs' (_: mkNginxConfig) cfg.at;

    services.anubis.instances = let
      mkAnubisInstance = {
        subdomain,
        port,
        ...
      }: {
        name = subdomain;
        value = {
          settings = {
            BIND_NETWORK = "tcp";
            BIND = ":${toString (port + 200)}";
            TARGET = "http://localhost:${toString port}";
          };
        };
      };
    in
      lib.attrsets.mapAttrs' (_: mkAnubisInstance) (lib.attrsets.filterAttrs (n: v: v.port != null) cfg.at);

    yomi.dns.records = let
      mkDnsRecord = {subdomain, ...}: {
        type = "CNAME";
        zone = cfg.domain;
        at = subdomain;
        to = config.networking.hostName;
      };
    in
      lib.attrsets.mapAttrsToList (_: mkDnsRecord) cfg.at;
  };
}
