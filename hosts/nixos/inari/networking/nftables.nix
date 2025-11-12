{
  config,
  lib,
  ...
}: let
  publicPorts = lib.attrsets.mapAttrsToList (name: value: toString value.port) config.yomi.cloudflared.at;
  privatePorts = lib.attrsets.mapAttrsToList (name: value: toString value.port) config.yomi.nginx.at;

  publicPortsString = lib.strings.concatStringsSep ", " publicPorts;
  privatePortsString = lib.strings.concatStringsSep ", " privatePorts;
in {
  networking = {
    # No local firewall.
    nat.enable = false;
    firewall.enable = false;

    nftables = {
      enable = true;

      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            # Basic security hardening
            ct state invalid drop comment "Drop invalid packets"
            ct state { established, related } accept comment "Allow established and related connections"
            iifname "lo" accept comment "Accept all loopback traffic"

            # Rate limiting to prevent DoS attacks
            iifname "eno1" tcp dport { 80, 443 } meter flood { ip saddr limit rate 10/second burst 20 packets } accept

            # Jump to service chains
            iifname "eno1" jump public_services
            iifname { "br0", "br1", "tailscale0" } jump private_services

            # Drop all other traffic
            counter drop
          }

          chain forward {
            type filter hook forward priority 0; policy drop;

            # Allow forwarding from LAN to WAN
            iifname { "br0", "br1" } oifname "eno1" accept
            
            # Allow WiFi hotspot (br1) to access main LAN (br0)
            iifname "br1" oifname "br0" accept

            # Allow established and related connections back to LAN
            ct state { established, related } accept
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }

          chain public_services {
            # Public services
            tcp dport { ${publicPortsString} } accept
          }

          chain private_services {
            # Private services
            tcp dport { ${privatePortsString} } accept
            tcp dport { 22, 80, 443 } accept comment "SSH, HTTP and HTTPS"
            udp dport { 53, 67 } accept comment "DNS and DHCP"
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname { "eno1", "br0" } masquerade
          }
        }
      '';
    };
  };

  # oifname "enp0s25" ip saddr 192.168.10.0/24 masquerade
}