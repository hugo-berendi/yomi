# NetBird client: the home network away from home, through networks that
# block UDP too (hosts/nixos/ebisu/netbird.nix). Join once with
# `netbird up`, which signs in through the browser.
{config, ...}: {
  services.netbird = {
    enable = true;
    # Loose reverse-path filtering, so inari can be the exit node.
    useRoutingFeatures = "client";
    clients.default = {
      environment.NB_MANAGEMENT_URL = "https://netbird.${config.yomi.dns.domain}";
      # Without the key, NetBird reads the module's pre-created config.json
      # as a pre-0.26 config and allows its SSH server, which NetBird's
      # management could then use to open a shell here.
      config.ServerSSHAllowed = false;
    };
  };
  # The WireGuard key and the peer's registration.
  yomi.persistence.at.state.apps.netbird.directories = [
    {
      directory = "/var/lib/netbird";
      mode = "0700";
    }
  ];
}
