{config, ...}: {
  # {{{ Reverse proxy
  yomi.nginx.at.home.port = config.yomi.ports.home-assistant;
  # }}}
  # {{{ Home assistant
  services.home-assistant = {
    enable = true;
    extraPackages = python3Packages:
      with python3Packages; [
        gtts
      ];
    extraComponents = [
      "isal"
      "esphome"
      "met"
      "radio_browser"
      "tuya"
      "ibeacon"
      "roborock"
      "mqtt"
      "govee_ble"
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
  # }}}
  # {{{ Mosquitto
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        port = config.yomi.ports.mqtt;
        address = "127.0.0.1";
        acl = ["pattern readwrite #"];
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };
  # }}}
  # {{{ Govee2mqtt
  sops.templates."govee2mqtt.env" = {
    content = ''
      GOVEE_MQTT_HOST=127.0.0.1
      GOVEE_MQTT_PORT=${toString config.yomi.ports.mqtt}
      GOVEE_LAN_SCAN=192.168.178.107,192.168.178.108
    '';
    owner = config.services.govee2mqtt.user;
  };

  services.govee2mqtt = {
    enable = config.services.home-assistant.enable;
    environmentFile = config.sops.templates."govee2mqtt.env".path;
  };
  # }}}
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/hass";
      user = "hass";
      group = "hass";
    }
    {
      directory = "/var/lib/private/mosquitto";
      mode = "0700";
    }
    {
      directory = "/var/lib/govee2mqtt";
      user = config.services.govee2mqtt.user;
      group = config.services.govee2mqtt.group;
    }
  ];
  # }}}
}
