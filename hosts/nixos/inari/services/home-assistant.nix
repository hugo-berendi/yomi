{config, ...}: {
  yomi.nginx.at.home.port = config.yomi.ports.home-assistant;
  services.home-assistant = {
    enable = true;
    config = {
      http = {
        server_host = [
          "0.0.0.0"
          "::"
        ];
        server_port = config.yomi.nginx.at.home.port;
        trusted_proxies = [
          "localhost"
          "100.83.158.40"
        ];
        use_x_forwarded_for = true;
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
