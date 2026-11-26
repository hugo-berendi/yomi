# NetBird routing peer: devices signed in to NetBird reach inari, and through
# it the home network and the internet (exit node). The server runs on ebisu
# (hosts/nixos/ebisu/netbird.nix); routes, the exit node and policies are set
# in its dashboard. NetBird peers get the same ports as the LAN, through the
# rules for the client's interface in networking/nftables.nix.
#
# Endpoints served by nginx already resolve in public DNS to inari's LAN
# address, so a route to that one address is enough for them; a route to all
# of 192.168.178.0/24 would clash with every other FRITZ!Box network a client
# sits in.
{
  config,
  lib,
  ...
}: let
  # Created in NetBird's dashboard once the server runs, then stored with
  # `sops hosts/nixos/inari/secrets.yaml`. See ../lib/has-secret.nix.
  hasSetupKey = import ../lib/has-secret.nix "netbird_setup_key";
in {
  # {{{ Ports
  yomi.ports.netbird = 51820;
  # Direct WireGuard connections arrive through the FRITZ!Box on br0.
  yomi.network.exposure.netbird = {
    protocols = ["udp"];
    interface = "br0";
  };
  # }}}
  # {{{ Secrets
  sops.secrets.netbird_setup_key = lib.mkIf hasSetupKey {sopsFile = ../secrets.yaml;};
  warnings = lib.optional (!hasSetupKey) "netbird_setup_key is not in inari's secrets.yaml: the NetBird client runs but does not join, and NetBird devices cannot reach inari. Create a setup key in the dashboard at netbird.${config.yomi.dns.domain}.";
  # }}}
  # {{{ Service
  services.netbird = {
    enable = true;
    useRoutingFeatures = "server";
    clients.default = {
      port = config.yomi.ports.netbird;
      environment.NB_MANAGEMENT_URL = "https://netbird.${config.yomi.dns.domain}";
      login = lib.mkIf hasSetupKey {
        enable = true;
        setupKeyFile = config.sops.secrets.netbird_setup_key.path;
      };
      # networking.firewall is off here; nftables.nix decides.
      openFirewall = false;
      openInternalFirewall = false;
      config = {
        # inari resolves through dnsmasq and AdGuard; NetBird must not
        # rewrite its resolv.conf.
        DisableDNS = true;
        # The router routes for others and never through them.
        DisableClientRoutes = true;
        # The module creates config.json before the first start, and NetBird
        # reads a file without this key as a pre-0.26 config and allows its
        # SSH server (client/internal/profilemanager/config.go). Then whoever
        # runs NetBird's management could open a shell here.
        ServerSSHAllowed = false;
      };
    };
  };
  # }}}
  # {{{ State
  # The WireGuard key and the peer's registration.
  yomi.persistence.at.state.apps.netbird.directories = [
    {
      directory = "/var/lib/netbird";
      mode = "0700";
    }
  ];
  # }}}
}
