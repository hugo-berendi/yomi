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
        options =
          access
          // {
            enable = lib.mkEnableOption "this private resource" // {default = true;};
            mode = mkOption {
              type = types.enum ["host" "cidr" "exit-node"];
              default = "host";
              description = "Single host, network range or an explicit full-tunnel exit node.";
            };
            destination = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Destination address or CIDR; unused for exit nodes.";
            };
            alias = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Private client DNS name for a host resource; required for hostname destinations and useful for loopback backends.";
            };
            tcpPorts = mkOption {
              type = types.listOf types.port;
              default = [];
              description = "Allowed TCP ports; none by default. Exit nodes always carry all traffic.";
            };
            udpPorts = mkOption {
              type = types.listOf types.port;
              default = [];
              description = "Allowed UDP ports; none by default. Exit nodes always carry all traffic.";
            };
            allowICMP = lib.mkEnableOption "ICMP to this private resource";
          };
      });
    };
  };
}
