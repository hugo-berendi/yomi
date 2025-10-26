{config, ...}:
# hostapd creates a WIFI network my other devices can connect to
let
  interface = "wlp2s0";
in
{
  sops.secrets.wifi_password = {
    sopsFile = ../secrets.yaml;
  };
  services.hostapd = {
    enable = true;
    radios.${interface} = {
      band = "2g";
      countryCode = "DE";
      channel = 0; # Automatic channel selection

      networks.${interface} = {
        ssid = "kitsune";
        logLevel = 0; # Debugging
        authentication = {
          # This device doesn't support wpa3-sae
          mode = "wpa2-sha1";
          wpaPasswordFile = config.sops.secrets.wifi_password;
        };

        settings = {
          bridge = "br0";
          ieee80211w = 0;
        };
      };
    };
  };
}