{config, ...}: {
  services.resolved.enable = false;
  services.dnsmasq = {
    enable = true;
    settings = {
      # upstream DNS servers
      server = [
        "127.0.0.1#${toString config.yomi.ports.adguard-dns}" # AdGuard Home
        # Fallback when AdGuard is down. Not Quad9: plain UDP to 9.9.9.9 lost
        # over half its queries (9/20) while 1.1.1.1 answered 20/20.
        "1.1.1.1" # Cloudflare
      ];

      # sensible behaviours
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;

      # Cache DNS queries.
      cache-size = 1000;

      interface = "br1";
      dhcp-range = ["br1,192.168.10.50,192.168.10.254,24h"];
      dhcp-option = ["option:router,192.168.10.1"];
      dhcp-host = "192.168.10.1";

      # don't use /etc/hosts as this would advertise surfer as localhost
      no-hosts = true;
    };
  };
}
