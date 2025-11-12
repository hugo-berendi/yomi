{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.nginx;

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
            proxyPass = "http://localhost:${toString port}";
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

  mkDnsRecord = {subdomain, ...}: {
    type = "CNAME";
    zone = cfg.domain;
    at = subdomain;
    to = config.networking.hostName;
  };
in {
  options.yomi.nginx = {
    enable =
      lib.mkEnableOption "yomi's nginx integration"
      // {
        default = true;
      };

    domain = lib.mkOption {
      description = "Root domain to use as a default for configurations.";
      type = lib.types.str;
      default = config.yomi.dns.domain;
    };

    at = lib.mkOption {
      description = "Per-subdomain nginx configuration";
      default = {};

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
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (_: config: {
        assertion = (config.port == null) == (config.files != null);
        message = ''
          Precisely one of the options
            'yomi.nginx.at.${config.subdomain}.port'
          and
            'yomi.nginx.at.${config.subdomain}.files'
          must be specified.
        '';
      })
      cfg.at;

    yomi.acme.enable = true;
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      statusPage = true;
      virtualHosts = lib.attrsets.mapAttrs' (_: mkNginxConfig) cfg.at;
    };

    yomi.dns.records = lib.attrsets.mapAttrsToList (_: mkDnsRecord) cfg.at;
  };
}
