{config, ...}: {
  yomi.nginx.at.adguard.port = config.yomi.ports.adguard;
  services.adguardhome = {
    enable = true;
    port = config.yomi.nginx.at.adguard.port;
    settings = {
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;

        parental_enabled = false; # Parental control-based DNS requests filtering.
        safe_search = {
          enabled = false; # Enforcing "Safe search" option for search engines, when possible.
        };
      };
      filters =
        map (url: {
          enabled = true;
          url = url;
        }) [
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt" # The Big List of Hacked Malware Web Sites
          "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt" # malicious url blocklist
          "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt"
        ];
    };
  };
}
