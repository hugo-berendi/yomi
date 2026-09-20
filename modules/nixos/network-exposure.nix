{
  config,
  lib,
  ...
}: {
  options.yomi.network.exposure = lib.mkOption {
    default = {};
    description = "Explicit service reachability grants. A firewall backend must consume the requested scope and interface.";
    type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          default = config.yomi.ports.${name};
          description = "Port to expose; defaults to the matching registry entry.";
        };
        protocols = lib.mkOption {
          type = lib.types.listOf (lib.types.enum ["tcp" "udp"]);
          default = ["tcp"];
          description = "Transport protocols allowed by this grant.";
        };
        interface = lib.mkOption {
          type = lib.types.str;
          description = "Ingress interface on which this grant applies.";
        };
        scope = lib.mkOption {
          type = lib.types.enum ["lan" "vpn" "wan"];
          default = "lan";
          description = "Trust boundary receiving access; never inferred from upstream openFirewall.";
        };
        service = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Service owning the listener, for review and inventory.";
        };
      };
    }));
  };
}
