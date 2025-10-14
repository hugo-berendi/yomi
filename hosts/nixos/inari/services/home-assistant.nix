{
  config,
  pkgs,
  ...
}: {
  # {{{ Import automations
  imports = [
    ./home-assistant/automations/car-climate-weekday.nix
    ./home-assistant/automations/car-climate-friday.nix
    ./home-assistant/automations/car-climate-on-leaving.nix
    ./home-assistant/automations/morning-car-summary.nix
    ./home-assistant/automations/car-doors-windows-open-warning.nix
    ./home-assistant/automations/car-low-battery-warning.nix
    ./home-assistant/automations/remind-plug-in-car.nix
    ./home-assistant/automations/notify-charging-complete.nix
    ./home-assistant/automations/lights-off-when-away.nix
    ./home-assistant/automations/lights-on-at-sunset.nix
    ./home-assistant/automations/lights-off-at-bedtime.nix
    ./home-assistant/automations/welcome-home-lights.nix
    ./home-assistant/automations/alarm-wake-up.nix
    ./home-assistant/automations/forecast-based-car-climate.nix
    ./home-assistant/automations/weather-alert.nix
    ./home-assistant/automations/weather-based-lights.nix
  ];
  # }}}
  # {{{ Reverse proxy
  yomi.nginx.at.home.port = config.yomi.ports.home-assistant;
  # }}}
  # {{{ Govee2MQTT
  sops.secrets."govee2mqtt_env_email" = {
    sopsFile = ../secrets.yaml;
  };
  sops.secrets."govee2mqtt_env_api_key" = {
    sopsFile = ../secrets.yaml;
  };

  sops.templates."govee2mqtt.env".content = ''
    GOVEE_MQTT_HOST=127.0.0.1
    GOVEE_MQTT_PORT=${toString config.yomi.ports.mqtt}
    GOVEE_EMAIL=${config.sops.placeholder."govee2mqtt_env_email"}
    GOVEE_API_KEY=${config.sops.placeholder."govee2mqtt_env_api_key"}
  '';

  services.govee2mqtt = {
    enable = true;
    environmentFile = config.sops.templates."govee2mqtt.env".path;
  };
  # }}}
  # {{{ Home assistant
  services.home-assistant = {
    enable = true;
    extraPackages = python3Packages:
      with python3Packages; [
        gtts
        (weconnect.overridePythonAttrs (old: {
          src = pkgs.fetchFromGitHub {
            owner = "tillsteinbach";
            repo = "WeConnect-python";
            rev = "7a0eafc33ec82fe04d9ad3e7abd32ab1966733f0";
            hash = "sha256-q4jttmN4kaUSeXE4qilq+02CSuhSibbISHvD/ZhOe3s=";
          };
          version = "0.60.8+git";
        }))
        ascii-magic
      ];
    extraComponents = [
      "isal"
      "esphome"
      "met"
      "accuweather"
      "radio_browser"
      "tuya"
      "ibeacon"
      "roborock"
      "mqtt"
    ];
    customComponents = [
      (pkgs.buildHomeAssistantComponent {
        owner = "mitch-dc";
        domain = "volkswagen_we_connect_id";
        version = "0.2.6";
        src = pkgs.fetchFromGitHub {
          owner = "mitch-dc";
          repo = "volkswagen_we_connect_id";
          rev = "v0.2.6";
          hash = "sha256-f5guxLE93QtTPV1zw1313bzF521pVr0vsUa3hzcRmJo=";
        };
        dontCheckManifest = true;
      })
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
      lovelace = {
        mode = "storage";
        dashboards = {
          lovelace-yomi = {
            mode = "yaml";
            title = "Yomi Dashboard";
            icon = "mdi:home-assistant";
            show_in_sidebar = true;
            filename = "/var/lib/hass/dashboards/yomi.yaml";
          };
        };
      };
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/hass/dashboards 0755 hass hass - -"
    "L+ /var/lib/hass/dashboards/yomi.yaml - hass hass - ${./home-assistant/dashboards/yomi.yaml}"
  ];
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
  # {{{ Persistence
  environment.persistence."/persist/state".directories = [
    {
      directory = "/var/lib/hass";
      user = "hass";
      group = "hass";
    }
  ];
  # }}}
}
