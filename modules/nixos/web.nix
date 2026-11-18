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
  forTransport = transport: lib.mapAttrs (_: e: common e // lib.optionalAttrs (transport == "cloudflare") {inherit (e) enableAnubis;}) (lib.filterAttrs (_: e: e.transport == transport) endpoints);
in {
  options.yomi.web.at = lib.mkOption {
    default = {};
    description = "HTTP endpoints with one selected transport and explicit authentication ownership.";
    type = lib.types.attrsOf (lib.types.submodule {
      imports = [
        (import ./lib/endpoint.nix {
          inherit lib;
          domain = config.yomi.dns.domain;
        })
      ];
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          description = "HTTP application port.";
        };
        transport = lib.mkOption {
          type = lib.types.enum ["nginx" "cloudflare" "pangolin"];
          description = "Transport responsible for this endpoint's publication and DNS.";
        };
        authentication = lib.mkOption {
          type = lib.types.enum ["application" "gateway" "none"];
          description = "Who authenticates requests; none deliberately permits anonymous access.";
        };
        enableAnubis = lib.mkEnableOption "Anubis protection on the selected tunnel";
        stagePangolin = lib.mkEnableOption "a Pangolin blueprint before enrolling the connector";
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
    });
  };

  config = {
    assertions = lib.concatMap (e: [
      {
        assertion = e.authentication != "gateway" || e.transport == "pangolin";
        message = "Web ${e.host}: gateway authentication requires the Pangolin transport.";
      }
      {
        assertion = !e.stagePangolin || !config.yomi.expose.enable || e.transport == "pangolin";
        message = "Web ${e.host}: select Pangolin explicitly before activating a staged connector.";
      }
      {
        assertion = !e.enableAnubis || e.transport != "nginx";
        message = "Web ${e.host}: Anubis requires a supported tunnel transport.";
      }
    ]) (lib.attrValues endpoints);
    yomi.nginx.at = forTransport "nginx";
    yomi.cloudflared.at = forTransport "cloudflare";
    yomi.expose.at = lib.mapAttrs (_: e:
      common e
      // e.pangolin
      // {
        inherit (e) enableAnubis;
        sso = e.authentication == "gateway";
      }) (lib.filterAttrs (_: e: e.transport == "pangolin" || e.stagePangolin) endpoints);
  };
}
