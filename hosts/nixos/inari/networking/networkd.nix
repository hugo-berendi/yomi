{
  config,
  lib,
  ...
}: {
  options.yomi.inari.lanInterface = lib.mkOption {
    type = lib.types.str;
    default = "eno1";
    description = "Physical LAN interface enslaved to br0 on the installed server.";
  };
  config = {
    # Forward packets (IPV4 only)
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = lib.mkForce false;
    };

    # We'll configure this manually per-interface
    networking.useDHCP = false;
    networking.useNetworkd = true;

    systemd.network = {
      enable = true;

      # Do not require all the interfaces to be up
      wait-online.anyInterface = true;

      netdevs."20-br0".netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };

      # Networks
      networks = {
        "30-eno1" = {
          matchConfig.Name = config.yomi.inari.lanInterface;
          networkConfig.Bridge = "br0";
          linkConfig.RequiredForOnline = "enslaved";
        };

        "40-br0" = {
          matchConfig.Name = "br0";
          linkConfig.RequiredForOnline = "carrier";
          networkConfig = {
            LinkLocalAddressing = "no";
            Address = "192.168.178.200/24";
            Gateway = "192.168.178.1";
          };
        };
      };
    };
  };
}
