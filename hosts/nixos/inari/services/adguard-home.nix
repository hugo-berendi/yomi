{config, ...}: {
  # {{{ Reverse proxy
  yomi.nginx.at.adguard.port = config.yomi.ports.adguard;
  # }}}
  # {{{ Service
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    port = config.yomi.nginx.at.adguard.port;
    settings = {
      dns = {
        bind_hosts = ["127.0.0.1" "::1"];
        port = config.yomi.ports.adguard-dns;
        upstream_dns = [
          "9.9.9.9#dns.quad9.net"
          "149.112.112.112#dns.quad9.net"
        ];
      };

      filtering = {
        protection_enabled = true;
        filtering_enabled = true;

        parental_enabled = false;
        safe_search = {
          enabled = false;
        };
      };
      filters =
        map (url: {
          enabled = true;
          url = url;
        }) [
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt"
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt"
        ];
    };
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/AdGuardHome";
      user = "adguardhome";
      group = "adguardhome";
      mode = "0750";
    }
  ];
  # }}}
}
