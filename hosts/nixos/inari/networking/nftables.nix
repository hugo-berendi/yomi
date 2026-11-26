{
  config,
  pkgs,
  lib,
  ...
}: let
  grants = lib.attrValues config.yomi.network.exposure;
  portsFor = protocol: map (entry: entry.port) (lib.filter (entry: lib.elem protocol entry.protocols) grants);
  lanTcpServicePorts = portsFor "tcp";
  lanUdpServicePorts = portsFor "udp";
  # SSH and the web ingress are part of the host's LAN interface.
  baseTcpPorts = [22 80 443];
  baseUdpPorts = [443];
  lanTcpPorts = lib.concatMapStringsSep ", " toString (
    lib.unique (baseTcpPorts ++ lanTcpServicePorts)
  );
  lanUdpPorts = lib.concatMapStringsSep ", " toString (
    lib.unique (baseUdpPorts ++ lanUdpServicePorts)
  );

  # NetBird peers (services/netbird.nix) are devices signed in as the pilot
  # through ebisu's NetBird, so they get what the LAN gets, enforced in the
  # netbird-prerouting chain below. NetBird's policies decide which devices
  # are peers.
  netbird = config.services.netbird.enable;
  netbirdInterface = config.services.netbird.clients.default.interface;

  # networking.firewall is disabled below, so allowedTCPPorts and
  # allowedUDPPorts reach nothing: every `openFirewall = true` in modules/nixos
  # (pounce, windrose, steam-game-server, vrising) opens exactly nothing here.
  # Enabling a game server looks like it opened a port and did not.
  #
  # These are deliberately not folded into the lists above. The allowlist is
  # meant to be decided here rather than accumulated from whatever a module
  # asked for -- a torrent client's peer port, for one, may be requested but
  # reaches the internet through the VPN namespace, not br0. So say so instead, and
  # let whoever adds a service grant LAN access on purpose, with a
  # yomi.network.exposure entry in that service's own file.
  inertFirewallPorts =
    lib.filter (p: !lib.elem p (baseTcpPorts ++ lanTcpServicePorts)) config.networking.firewall.allowedTCPPorts
    ++ lib.filter (p: !lib.elem p (baseUdpPorts ++ lanUdpServicePorts)) config.networking.firewall.allowedUDPPorts;
in {
  assertions = [
    {
      assertion = lib.all (entry: entry.scope == "lan" && entry.interface == "br0") grants;
      message = "Inari's service grants support LAN access on br0 only; add a reviewed firewall rule for other scopes.";
    }
  ];
  # The old generated deletions file flushes every table once on migration.
  # Only that transition needs Docker to reinstall its own rules. Subsequent
  # reloads replace our named tables without touching Docker.
  systemd.services.nftables = let
    markLegacyFlush = pkgs.writeShellScript "nftables-mark-legacy-flush" ''
      set -eu
      marker=/run/nftables/legacy-flush
      if [ -f /var/lib/nftables/deletions.nft ] && ${lib.getExe pkgs.gnugrep} -Eq '^[[:space:]]*flush ruleset' /var/lib/nftables/deletions.nft; then
        touch "$marker"
      else
        rm -f "$marker"
      fi
    '';
    recoverDocker = pkgs.writeShellScript "nftables-recover-legacy-docker" ''
      set -eu
      marker=/run/nftables/legacy-flush
      if [ -e "$marker" ]; then
        ${lib.getExe' config.systemd.package "systemctl"} try-restart --no-block docker.service
        rm -f "$marker"
      fi
    '';
  in {
    serviceConfig = {
      RuntimeDirectory = "nftables";
      ExecStartPre = [markLegacyFlush];
      ExecStartPost = lib.mkAfter [recoverDocker];
      ExecReload = lib.mkMerge [
        (lib.mkBefore [markLegacyFlush])
        (lib.mkAfter [recoverDocker])
      ];
    };
  };

  warnings = lib.optional (inertFirewallPorts != []) ''
    networking.firewall is disabled on this host, so these ports opened via
    allowedTCPPorts/allowedUDPPorts reach nothing: ${lib.concatMapStringsSep ", " toString (lib.unique inertFirewallPorts)}.
    A service setting openFirewall = true here has no effect. If it really should be reachable from
    the LAN, grant it with yomi.network.exposure.<name> in the service's own file.
  '';

  networking = {
    nat.enable = false;
    firewall.enable = false;

    nftables = {
      enable = true;

      flushRuleset = false;
      tables.yomi-filter = {
        family = "inet";
        content = ''
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
            ${lib.optionalString netbird ''
            iifname "${netbirdInterface}" ct state { established, related } accept comment "Allow established NetBird traffic"
            iifname "${netbirdInterface}" meta l4proto tcp th dport { ${lanTcpPorts} } accept comment "NetBird peers get the LAN's TCP services"
            iifname "${netbirdInterface}" meta l4proto udp th dport { ${lanUdpPorts} } accept comment "NetBird peers get the LAN's UDP services"
            iifname "${netbirdInterface}" ip protocol icmp accept comment "Allow NetBird IPv4 diagnostics"
          ''}
            iifname {"docker0", "br-pelican", "br-changedet", "veth*"} accept comment "Allow Docker to router"
            iifname "wg-br" accept comment "Allow VPN namespace to router"
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
            # br0 reaches the home LAN and the upstream router.
            iifname { "docker0", "br-pelican", "br-changedet" } oifname "br0" accept comment "Docker to uplink"
            iifname "br0" oifname { "docker0", "br-pelican", "br-changedet" } ct state { established, related } accept comment "Replies from uplink"

            ${lib.optionalString netbird ''
            # NetBird peers reach the home network through inari's routes and
            # the internet through its exit node; NetBird masquerades both.
            iifname "${netbirdInterface}" oifname "br0" accept comment "NetBird peers to LAN and uplink"
            iifname "br0" oifname "${netbirdInterface}" ct state { established, related } accept comment "Replies to NetBird peers"
          ''}
            # VPN namespace bridge access
            iifname "wg-br" oifname "br0" accept comment "VPN namespace to WAN"
            iifname "br0" oifname "wg-br" ct state { established, related } accept comment "WAN back to VPN namespace"
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }
          ${lib.optionalString netbird ''
            # NetBird's client puts `iifname "${netbirdInterface}" accept` at the top of
            # every other table's input and forward chains, this one's included,
            # and restores it after reloads (client/firewall/nftables/
            # router_linux.go, acceptExternalChainsRules). The rules for its
            # interface in those chains therefore decide nothing, and without
            # this chain NetBird's policies alone would. Prerouting is a hook it
            # leaves alone: this runs after conntrack (-200) and before
            # NetBird's DNAT (-100).
            chain netbird-prerouting {
              type filter hook prerouting priority -150; policy accept;
              iifname != "${netbirdInterface}" accept
              ct state { established, related } accept
              fib daddr type local meta l4proto tcp th dport { ${lanTcpPorts} } accept comment "NetBird peers get the LAN's TCP services"
              fib daddr type local meta l4proto udp th dport { ${lanUdpPorts} } accept comment "NetBird peers get the LAN's UDP services"
              fib daddr type local ip protocol icmp accept comment "Allow NetBird IPv4 diagnostics"
              fib daddr type local drop
              fib daddr oifname "br0" accept comment "NetBird peers to LAN and uplink"
              drop
            }
          ''}
        '';
      };
      tables.yomi-nat = {
        family = "ip";
        content = ''
          chain postrouting {
            type nat hook postrouting priority 100; policy accept;

            ${lib.optionalString config.yomi.t3codeVm.enable ''
            iifname "t3test0" ip saddr 10.231.0.2 oifname "br0" masquerade
          ''}
            iifname {"docker0", "br-pelican", "br-changedet"} oifname "br0" masquerade comment "NAT towards home router"
          }
        '';
      };
    };
  };
}
