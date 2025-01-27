{config, ...}: {
  yomi.nginx.at.home.port = config.yomi.ports.home-assistant;
  services.home-assistant = {
    enable = true;
    extraPackages = python3Packages:
      with python3Packages; [
        gtts
        # numpy
        # hassil
        # home_assistant_intents
      ];
    extraComponents = [
      "isal"
      "esphome"
      "met"
      "radio_browser"
      "govee_ble"
      "govee_light_local"
    ];
    config = {
      default_config = {};
      http = {
        server_host = [
          "0.0.0.0"
          "::"
        ];
        server_port = config.yomi.nginx.at.home.port;
        use_x_forwarded_for = true;
        trusted_proxies = [
          "::1"
          "100.83.158.40"
          "127.0.0.1"
        ];
      };
      homeassistant = {
        unit_system = "metric";
        time_zone = "Europe/Berlin";
        name = "Home";
        latitude = "47.901628";
        longitude = "11.8304463";
      };
    };
  };
}
