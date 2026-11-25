{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.web;
  endpoints = lib.filterAttrs (_: e: e.enable) cfg.at;
  common = e: {
    inherit (e) host subdomain port protocol proxyAddress dns;
    monitor = lib.mkDefault e.monitor;
  };
in {
  options.yomi.web.at = lib.mkOption {
    default = {};
    description = "HTTP endpoints with one selected transport and explicit authentication ownership.";
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      imports = [
        (import ./lib/endpoint.nix {
          inherit lib;
          domain = config.yomi.dns.domain;
        })
      ];
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          default = config.yomi.ports.${name};
          defaultText = lib.literalExpression "config.yomi.ports.<name>";
          description = "HTTP application port; defaults to the registry entry of the same name.";
        };
        transport = lib.mkOption {
          type = lib.types.enum ["nginx" "pangolin"];
          description = "Transport responsible for this endpoint's publication and DNS.";
        };
        authentication = lib.mkOption {
          type = lib.types.enum ["application" "gateway" "none"];
          description = "Who authenticates requests; none deliberately permits anonymous access.";
        };
        clientMaxBodySize = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "50M";
          description = "Largest request body nginx accepts (nginx transport only); null keeps nginx's 1M default.";
        };
        enableAnubis = lib.mkEnableOption "Anubis protection on Pangolin";
        stagePangolin = lib.mkEnableOption "previewing this endpoint in the blueprint while the connector is disabled";
        pangolin = lib.mkOption {
          default = {};
          description = "Pangolin-specific access and backend policy.";
          type = lib.types.submodule {
            options =
              (import ./expose/web-options.nix {
                inherit lib;
                inherit (config.yomi.expose) allowedCountries;
              })
              // {
                users = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = "Users permitted by gateway authentication.";
                };
                roles = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = "Roles permitted by gateway authentication.";
                };
              };
          };
        };
      };
    }));
  };

  config = {
    assertions = lib.concatMap (e: [
      {
        assertion = e.authentication != "gateway" || e.transport == "pangolin";
        message = "Web ${e.host}: gateway authentication requires the Pangolin transport.";
      }
      {
        assertion = !e.enableAnubis || e.transport == "pangolin";
        message = "Web ${e.host}: Anubis requires the Pangolin transport.";
      }
      {
        assertion = e.clientMaxBodySize == null || e.transport == "nginx";
        message = "Web ${e.host}: clientMaxBodySize only applies to the nginx transport.";
      }
    ]) (lib.attrValues endpoints);
    yomi.nginx.at = lib.mapAttrs (_: e: common e // {inherit (e) clientMaxBodySize;}) (lib.filterAttrs (_: e: e.transport == "nginx") endpoints);
    yomi.expose.at = lib.mapAttrs (_: e:
      common e
      // e.pangolin
      // {
        inherit (e) enableAnubis;
        sso = e.authentication == "gateway";
      }) (lib.filterAttrs (_: e: e.transport == "pangolin" || (e.stagePangolin && !config.yomi.expose.enable)) endpoints);
  };
}
