{
  config,
  lib,
  ...
}: let
  lanTcpServicePorts = map (name: config.yomi.ports.${name}) [
    "beszel"
    "home-assistant"
    "mqtt"
    "pelican-node1"
    "windrose-direct"
    "windrose-rcon"
  ];
  lanUdpServicePorts = map (name: config.yomi.ports.${name}) [
    "valheim"
    "valheim-query"
    "windrose-direct"
  ];
  lanTcpPorts = lib.concatMapStringsSep ", " toString (
    lib.unique ([22 53 80 443 445 2049 22000] ++ lanTcpServicePorts)
  );
  lanUdpPorts = lib.concatMapStringsSep ", " toString (
    lib.unique ([53 67 68 443 1900 5353 21027 22000] ++ lanUdpServicePorts)
  );

  # networking.firewall is disabled below, so allowedTCPPorts and
  # allowedUDPPorts reach nothing: every `openFirewall = true` in modules/nixos
  # (pounce, windrose, steam-game-server, vrising) opens exactly nothing here.
  # Enabling a game server looks like it opened a port and did not.
  #
  # These are deliberately not folded into the lists above. The allowlist is
  # meant to be decided here rather than accumulated from whatever a module
  # asked for -- transmission's peer port, for one, is requested but reaches
  # the internet through the VPN namespace, not br0. So say so instead, and
  # let whoever adds a service put the port in lanTcpServicePorts on purpose.
  inertFirewallPorts =
    lib.filter (p: !lib.elem p ([22 53 80 443 445 2049 22000] ++ lanTcpServicePorts)) config.networking.firewall.allowedTCPPorts
    ++ lib.filter (p: !lib.elem p ([53 67 68 443 1900 5353 21027 22000] ++ lanUdpServicePorts)) config.networking.firewall.allowedUDPPorts;
  exitNodeForwardRule = lib.optionalString config.yomi.tailscale.exitNode ''
    # Allow Tailscale exit node traffic
    iifname "tailscale0" oifname "br0" accept
  '';
in {
  # Reloading nftables flushes the rules docker installs for itself, and docker
  # only re-adds them at startup -- so this restart is required for container
  # networking to keep working. It does mean every ruleset change, down to a
  # comment, bounces every container on this host. Containers that need time to
  # shut down cleanly must set --stop-timeout; see services/valheim.nix.
  systemd.services.nftables = {
    postStart = ''
      ${lib.getExe' config.systemd.package "systemctl"} try-restart --no-block docker.service || true
    '';
    serviceConfig.ExecReload = lib.mkAfter [
      "-${lib.getExe' config.systemd.package "systemctl"} try-restart --no-block docker.service"
    ];
  };

  warnings = lib.optional (inertFirewallPorts != []) ''
    networking.firewall is disabled on this host, so these ports opened via
    allowedTCPPorts/allowedUDPPorts reach nothing: ${lib.concatMapStringsSep ", " toString (lib.unique inertFirewallPorts)}.
    A service setting openFirewall = true here has no effect. Add the port to
    lanTcpServicePorts/lanUdpServicePorts in hosts/nixos/inari/networking/nftables.nix
    if it really should be reachable from the LAN.
  '';

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
            iifname "br0" ct state { established, related } accept comment "Allow established LAN traffic"
            iifname "br0" meta l4proto tcp th dport { ${lanTcpPorts} } accept comment "Allow registered LAN TCP services"
            iifname "br0" meta l4proto udp th dport { ${lanUdpPorts} } accept comment "Allow registered LAN UDP services"
            iifname "br0" ip protocol icmp accept comment "Allow LAN IPv4 diagnostics"
            iifname "br0" ip6 nexthdr ipv6-icmp accept comment "Allow LAN IPv6 diagnostics"
            iifname {"docker0", "br-pelican", "br-changedet", "veth*"} accept comment "Allow Docker to router"
            iifname "wg-br" accept comment "Allow VPN namespace to router"
            iifname "tailscale0" accept comment "Allow Tailscale to router"

            # There is no eno1 on this machine any more -- the wired port is
            # enp4s0 and it is down. Inari sits behind the home router on br0,
            # so the three WAN rules that used to live here matched nothing.
            # Everything not accepted above is dropped by the chain policy.
            #
          }

          chain forward {
            type filter hook forward priority filter; policy drop;

            # Internal networks (VLANs, WiFi, Docker, Tailscale) to upstream bridge (WAN toward home router)
            iifname { "vlan20", "vlan30", "br1", "docker0", "br-pelican", "br-changedet", "tailscale0" } oifname "br0" accept comment "internal to WAN"
            iifname "br0" oifname { "vlan20", "vlan30", "br1", "docker0", "br-pelican", "br-changedet", "tailscale0" } ct state { established, related } accept comment "WAN back to internal"

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
            iifname {"vlan20", "vlan30", "br1", "docker0", "br-pelican", "br-changedet", "tailscale0"} oifname "br0" masquerade comment "NAT towards WAN"
          }
        }
      '';
    };
  };
}
