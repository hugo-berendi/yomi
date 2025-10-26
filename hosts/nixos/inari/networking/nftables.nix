{
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
            iifname "enp4s0" tcp dport { 80, 443 } meter flood { ip saddr limit rate 10/second burst 20 packets } accept

            # Jump to service chains
            iifname "enp4s0" jump public_services
            iifname { "br0", "br1" } jump private_services

            # Drop all other traffic
            counter drop
          }

          chain forward {
            type filter hook forward priority 0; policy drop;

            # Allow forwarding from LAN to WAN
            iifname { "br0", "br1" } oifname "enp4s0" accept

            # Allow established and related connections back to LAN
            ct state { established, related } accept
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }

          chain public_services {
            # Public services
            tcp dport { 8432, 8420, 8442, 8427, 8436, 8419, 8418, 8431, 8415, 8441, 8456, 8426 } accept
          }

          chain private_services {
            # Private services
            tcp dport { 8416, 8407, 8437, 8414, 8410, 8459, 8449, 8434, 8458, 8460, 8474, 8409, 8445, 8461, 8435, 8421, 8123, 8473, 8408, 8447, 8455, 8438, 8439, 8989, 8453, 8454, 8452, 8450, 8451 } accept
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;
            oifname "enp4s0" masquerade
          }
        }
      '';
    };
  };

  # oifname "enp0s25" ip saddr 192.168.10.0/24 masquerade
}