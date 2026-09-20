{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.nginx;
  enabled = lib.filterAttrs (_: e: e.enable) cfg.at;

  mkNginxConfig = {
    host,
    port,
    proxyAddress,
    protocol,
    files,
    clientMaxBodySize,
    ...
  }: {
    name = host;
    value = let
      extra =
        if port != null
        then {
          locations."/" = {
            proxyPass = "${protocol}://${proxyAddress}:${toString port}";
            proxyWebsockets = true;
          };
        }
        else {
          root = files;
        };
      bodySize = lib.optionalAttrs (clientMaxBodySize != null) {
        extraConfig = "client_max_body_size ${clientMaxBodySize};";
      };
    in
      {
        enableACME = true;
        acmeRoot = null;
        forceSSL = true;
      }
      // extra
      // bodySize;
  };

  mkDnsRecord = {dns, ...}: {
    type = "CNAME";
    inherit (dns) zone;
    at = dns.name;
    value = "${config.networking.hostName}.${config.yomi.dns.domain}.";
  };
in {
  options.yomi.nginx = {
    enable =
      lib.mkEnableOption "yomi's nginx integration"
      // {
        default = enabled != {};
      };

    domain = lib.mkOption {
      description = "Root domain to use as a default for configurations.";
      type = lib.types.str;
      default = config.yomi.dns.domain;
    };

    at = lib.mkOption {
      description = "Per-subdomain nginx configuration";
      default = {};

      type = lib.types.attrsOf (lib.types.submodule ({...}: {
        imports = [
          (import ./lib/endpoint.nix {
            inherit lib;
            inherit (cfg) domain;
          })
        ];

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

        options.clientMaxBodySize = lib.mkOption {
          description = "Maximum allowed size of the client request body for this host";
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "50000M";
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
      enabled;

    yomi.acme.enable = true;
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      statusPage = true;
      virtualHosts = lib.attrsets.mapAttrs' (_: mkNginxConfig) enabled;
    };

    yomi.dns.records = lib.attrsets.mapAttrsToList (_: mkDnsRecord) (lib.filterAttrs (_: e: e.dns.enable) enabled);
  };
}
