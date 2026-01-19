{
  config,
  lib,
  ...
}: let
  publicPorts = lib.attrsets.mapAttrsToList (name: value: toString value.port) config.yomi.cloudflared.at;
  privatePorts = lib.attrsets.mapAttrsToList (name: value: toString value.port) config.yomi.nginx.at;

  publicPortsString = lib.strings.concatStringsSep ", " publicPorts;
  privatePortsString = lib.strings.concatStringsSep ", " privatePorts;

  exitNodeForwardRule = lib.optionalString config.yomi.tailscale.exitNode ''
    # Allow Tailscale exit node traffic
    iifname "tailscale0" oifname "br0" accept
  '';
in {
  systemd.services.nftables = {
    postStart = ''
      ${lib.getExe' config.systemd.package "systemctl"} restart docker.service
    '';
    serviceConfig.ExecReload = lib.mkAfter [
      "${lib.getExe' config.systemd.package "systemctl"} restart docker.service"
    ];
  };

  networking = {
    nat.enable = false;
    firewall.enable = false;

    nftables = {
      enable = true;

      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            iifname "lo" accept comment "Accept loopback"
            iifname "br0" accept comment "Allow LAN to router"
            iifname {"docker0", "veth*"} accept comment "Allow Docker to router"
            iifname "wg-br" accept comment "Allow VPN namespace to router"
            iifname "tailscale0" accept comment "Allow Tailscale to router"

            iifname "eno1" ct state { established, related } accept comment "Allow established from WAN"
            iifname "eno1" icmp type { echo-request, destination-unreachable, time-exceeded } counter accept comment "Allow select ICMP from WAN"
            iifname "eno1" counter drop comment "Drop other unsolicited WAN traffic"
          }

          chain forward {
            type filter hook forward priority filter; policy drop;

            # Internal networks (VLANs, WiFi, Docker, Tailscale) to upstream bridge (WAN toward home router)
            iifname { "vlan20", "vlan30", "br1", "docker0", "tailscale0" } oifname "br0" accept comment "internal to WAN"
            iifname "br0" oifname { "vlan20", "vlan30", "br1", "docker0", "tailscale0" } ct state { established, related } accept comment "WAN back to internal"

            # WiFi hotspot access to main LAN address space
            iifname "br1" oifname "br0" accept comment "WiFi to LAN"

            # VPN namespace bridge access
            iifname "wg-br" oifname "br0" accept comment "VPN namespace to WAN"
            iifname "br0" oifname "wg-br" ct state { established, related } accept comment "WAN back to VPN namespace"

            # Explicit Tailscale exit node rule (in addition to internal set)
            ${exitNodeForwardRule}
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }
        }

        table ip nat {
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            # Masquerade traffic from internal networks towards upstream bridge (WAN toward home router)
            iifname {"vlan20", "vlan30", "br1", "docker0", "tailscale0"} oifname "br0" masquerade comment "NAT towards WAN"
          }
        }
      '';
    };
  };
}
