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
        publicReason = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "the personal website";
          description = ''
            Why this endpoint lets anyone on the internet in without a login.
            A Pangolin endpoint with `authentication = "none"` draws a warning
            until this says why; an nginx endpoint is private (LAN and
            Pangolin private resources) and needs no reason.
          '';
        };
        clientMaxBodySize = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "50M";
          description = "Largest request body nginx accepts (nginx transport only); null keeps nginx's 1M default.";
        };
        homepage = lib.mkOption {
          default = null;
          description = ''
            Tile linking to this endpoint on the host's homepage dashboard
            (`services.homepage-dashboard`); null leaves it off. The
            dashboard sorts tiles by name within their group.
          '';
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              group = lib.mkOption {
                type = lib.types.str;
                example = "Media";
                description = "Dashboard group; the dashboard rejects a group it does not lay out.";
              };
              name = lib.mkOption {
                type = lib.types.str;
                example = "Jellyfin";
                description = "Tile title.";
              };
              icon = lib.mkOption {
                type = lib.types.str;
                example = "jellyfin.svg";
                description = "Icon name as homepage-dashboard understands it (`<name>.svg`, `mdi-<name>`, `si-<name>`).";
              };
              description = lib.mkOption {
                type = lib.types.str;
                description = "Line under the tile title.";
              };
              widget = lib.mkOption {
                type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
                default = null;
                description = "homepage-dashboard service widget, passed through unchanged.";
              };
            };
          });
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
      {
        assertion = e.publicReason == null || (e.transport == "pangolin" && e.authentication == "none");
        message = "Web ${e.host}: publicReason only applies to a Pangolin endpoint with authentication = \"none\"; remove it.";
      }
    ]) (lib.attrValues endpoints);
    warnings = let
      unexplained = lib.attrNames (lib.filterAttrs (_: e: e.transport == "pangolin" && e.authentication == "none" && e.publicReason == null) endpoints);
      tiles = lib.attrNames (lib.filterAttrs (_: e: e.homepage != null) endpoints);
    in
      lib.optional (unexplained != [])
      "yomi.web.at: anyone on the internet can use ${lib.concatStringsSep ", " unexplained} without a login (Pangolin transport, authentication = \"none\"). Put a login in front, or say why with publicReason."
      # The tiles are read by the host's dashboard configuration (inari's
      # services/homepage); without a dashboard they would vanish silently.
      ++ lib.optional (tiles != [] && !config.services.homepage-dashboard.enable)
      "yomi.web.at: ${lib.concatStringsSep ", " tiles} ask for a homepage tile, but services.homepage-dashboard is not enabled on this host.";
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
