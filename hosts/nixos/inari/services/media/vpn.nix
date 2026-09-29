{
  config,
  lib,
  ...
}: {
  sops.secrets.wireguard_conf.sopsFile = ../../secrets.yaml;
  nixarr.vpn = {
    enable = true;
    wgConf = config.sops.secrets.wireguard_conf.path;
  };

  # nixarr's exposeOnLAN list routes all of 10.0.0.0/8 back out of the
  # namespace over the bridge, and that includes Mullvad's resolver,
  # 10.64.0.1. DNS inside the namespace never reached the tunnel: queries
  # went to the host, which has no route to 10.64.0.1. `ip netns exec`
  # hid this for a long time because glibc asked the host's nscd socket
  # instead; SearXNG's sandbox blocks that socket and failed every lookup.
  # Transmission's "Could not connect to tracker" had the same cause.
  #
  # No network here uses 10/8 (LAN and VLANs are 192.168/16, Docker is
  # 172.16/12, Tailscale is 100.64/10), so drop it rather than add routes.
  vpnNamespaces.wg.accessibleFrom = lib.mkForce [
    "172.16.0.0/12"
    "192.168.0.0/16"
    "127.0.0.1"
  ];
}
