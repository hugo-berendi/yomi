{
  config,
  lib,
  ...
}: let
  cfg = config.yomi.expose;
  inherit (lib) mkOption types;
  access = {
    users = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Pangolin users explicitly permitted to access the resource.";
    };
    roles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Pangolin roles permitted to access the resource; Admin is implicit and must not be listed.";
    };
  };
  raw = types.attrsOf (types.submodule ({config, ...}: {
    options = {
      enable = lib.mkEnableOption "publishing this raw public port" // {default = true;};
      port = mkOption {
        type = types.port;
        description = "Backend port reached by the site connector.";
      };
      publicPort = mkOption {
        type = types.port;
        default = config.port;
        description = "Public gateway port; raw traffic has no Pangolin authentication.";
      };
      proxyAddress = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Backend address as seen from the site connector.";
      };
    };
  }));
in {
  options.yomi.expose = {
    at = mkOption {
      default = {};
      description = "Public HTTP(S) tunnels, declared alongside their backend services.";
      type = types.attrsOf (types.submodule ({config, ...}: {
        imports = [
          (import ../lib/endpoint.nix {
            inherit lib;
            inherit (cfg) domain;
          })
        ];
        options =
          access
          // (import ./web-options.nix {
            inherit lib;
            inherit (cfg) allowedCountries;
          })
          // {
            port = mkOption {
              type = types.port;
              description = "Upstream HTTP service port.";
            };
            enableAnubis = lib.mkEnableOption "Anubis browser bot challenges before this Web application";
            anubis = {
              port = mkOption {
                type = types.port;
                default = config.port + 500;
                description = "Loopback Anubis listener; override if it conflicts with another port.";
              };
              metricsPort = mkOption {
                type = types.port;
                default = config.port + 600;
                description = "Loopback Anubis metrics listener.";
              };
            };
            sso = mkOption {
              type = types.bool;
              default = true;
              description = "Require Pangolin SSO; false explicitly publishes a service using its own authentication.";
            };
          };
      }));
    };
    tcp = mkOption {
      type = raw;
      default = {};
      description = "Unauthenticated public TCP port forwards through the site connector.";
    };
    udp = mkOption {
      type = raw;
      default = {};
      description = "Unauthenticated public UDP port forwards, for example game and query ports.";
    };
    private = mkOption {
      default = {};
      description = "Client-only resources; no public listener is created.";
      type = types.attrsOf (types.submodule {
        options = access // import ./private-options.nix {inherit lib;};
      });
    };
  };
}
