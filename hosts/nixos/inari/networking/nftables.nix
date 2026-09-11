{
  config,
  lib,
  ...
}: let
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
            iifname {"docker0", "br-affine", "br-pelican", "br-changedet", "veth*"} accept comment "Allow Docker to router"
            iifname "wg-br" accept comment "Allow VPN namespace to router"
            iifname "tailscale0" accept comment "Allow Tailscale to router"

            # There is no eno1 on this machine any more -- the wired port is
            # enp4s0 and it is down. Inari sits behind the home router on br0,
            # so the three WAN rules that used to live here matched nothing.
            # Everything not accepted above is dropped by the chain policy.
            #
            # Note that br0 is accepted unconditionally, which trusts the whole
            # home LAN with every service port on this host.
          }

          chain forward {
            type filter hook forward priority filter; policy drop;

            # Internal networks (VLANs, WiFi, Docker, Tailscale) to upstream bridge (WAN toward home router)
            iifname { "vlan20", "vlan30", "br1", "docker0", "br-affine", "br-pelican", "br-changedet", "tailscale0" } oifname "br0" accept comment "internal to WAN"
            iifname "br0" oifname { "vlan20", "vlan30", "br1", "docker0", "br-affine", "br-pelican", "br-changedet", "tailscale0" } ct state { established, related } accept comment "WAN back to internal"

            # Affine's containers need database and cache access on their dedicated bridge.
            iifname "br-affine" oifname "br-affine" accept comment "Affine bridge traffic"

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
            iifname {"vlan20", "vlan30", "br1", "docker0", "br-affine", "br-pelican", "br-changedet", "tailscale0"} oifname "br0" masquerade comment "NAT towards WAN"
          }
        }
      '';
    };
  };
}
