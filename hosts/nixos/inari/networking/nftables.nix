{
  config,
  lib,
  ...
}: let
  grants = lib.attrValues config.yomi.network.exposure;
  portsFor = protocol: map (entry: entry.port) (lib.filter (entry: lib.elem protocol entry.protocols) grants);
  lanTcpServicePorts = portsFor "tcp";
  lanUdpServicePorts = portsFor "udp";
  # Only ports something on inari answers on. Samba (445), NFS (2049) and
  # Syncthing (21027, 22000) were listed here with nothing behind them, so a
  # service that later bound one would have been LAN-open without anyone
  # deciding it. 1900 and 5353 are Home Assistant's SSDP and zeroconf
  # discovery (ss -ulnpe, 2026-10-27).
  baseTcpPorts = [22 53 80 443];
  baseUdpPorts = [53 67 68 443 1900 5353];
  lanTcpPorts = lib.concatMapStringsSep ", " toString (
    lib.unique (baseTcpPorts ++ lanTcpServicePorts)
  );
  lanUdpPorts = lib.concatMapStringsSep ", " toString (
    lib.unique (baseUdpPorts ++ lanUdpServicePorts)
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
    lib.filter (p: !lib.elem p (baseTcpPorts ++ lanTcpServicePorts)) config.networking.firewall.allowedTCPPorts
    ++ lib.filter (p: !lib.elem p (baseUdpPorts ++ lanUdpServicePorts)) config.networking.firewall.allowedUDPPorts;
  exitNodeForwardRule = lib.optionalString config.yomi.tailscale.exitNode ''
    # Allow Tailscale exit node traffic
    iifname "tailscale0" oifname "br0" accept
  '';
in {
  yomi.network.exposure = {
    beszel = {interface = "br0";};
    home-assistant = {interface = "br0";};
    mqtt = {interface = "br0";};
    pelican-node1 = {
      interface = "br0";
      service = "wings";
    };
    windrose-direct = {
      interface = "br0";
      protocols = ["tcp" "udp"];
      service = "windrose";
    };
    windrose-rcon = {
      interface = "br0";
      service = "windrose";
    };
    valheim = {
      interface = "br0";
      protocols = ["udp"];
    };
    valheim-query = {
      interface = "br0";
      protocols = ["udp"];
      service = "valheim";
    };
  };
  assertions = [
    {
      assertion = lib.all (entry: entry.scope == "lan" && entry.interface == "br0") grants;
      message = "Inari's service grants support LAN access on br0 only; add a reviewed firewall rule for other scopes.";
    }
  ];
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
    A service setting openFirewall = true here has no effect. Add an explicit yomi.network.exposure grant in
    hosts/nixos/inari/networking/nftables.nix
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

            ${lib.optionalString config.yomi.t3codeVm.enable ''
          iifname "t3test0" ip saddr 10.231.0.2 ct state { established, related } accept
          iifname "t3test0" drop
        ''}
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

            ${lib.optionalString config.yomi.t3codeVm.enable ''
          # Guest egress may reach the internet, never private or host networks.
          iifname "t3test0" meta nfproto ipv6 drop
          iifname "t3test0" ip saddr != 10.231.0.2 drop
          iifname "t3test0" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 192.168.0.0/16, 198.18.0.0/15, 198.51.100.0/24, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4 } drop
          iifname "t3test0" oifname "br0" accept
          iifname "br0" oifname "t3test0" ip daddr 10.231.0.2 ct state { established, related } accept
        ''}
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

            ${lib.optionalString config.yomi.t3codeVm.enable ''
          iifname "t3test0" ip saddr 10.231.0.2 oifname "br0" masquerade
        ''}
            # Masquerade traffic from internal networks towards upstream bridge (WAN toward home router)
            iifname {"vlan20", "vlan30", "br1", "docker0", "br-pelican", "br-changedet", "tailscale0"} oifname "br0" masquerade comment "NAT towards WAN"
          }
        }
      '';
    };
  };
}
