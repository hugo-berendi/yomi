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
    ./home-assistant/automations/webuntis-wake-up.nix
    ./home-assistant/automations/webuntis-lesson-change.nix
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
        ascii-magic
      ];
    extraComponents = [
      "isal"
      "esphome"
      "met"
      "accuweather"
      "radio_browser"
      "tuya"
      "roborock"
      "mqtt"
      "sonos"
    ];
    customComponents = [
      (pkgs.buildHomeAssistantComponent {
        owner = "robinostlund";
        domain = "volkswagencarnet";
        version = "5.4.0";
        src = pkgs.fetchFromGitHub {
          owner = "robinostlund";
          repo = "homeassistant-volkswagencarnet";
          rev = "v5.4.0";
          hash = "sha256-uIsOuc+UXhLbPm4/koANQjzPFfRVwt/rMhYw6keVgYI=";
        };
        sourceDir = "custom_components/volkswagencarnet";
        dependencies = [
          (pkgs.python3Packages.buildPythonPackage {
            pname = "volkswagencarnet";
            version = "5.4.0";
            pyproject = true;
            src = pkgs.fetchPypi {
              pname = "volkswagencarnet";
              version = "5.4.0";
              hash = "sha256-+NTpUVe82CB1ESwLxEkm67ZlvIGk0vTxYjVKVeUrhhY=";
            };
            build-system = with pkgs.python3Packages; [setuptools setuptools-scm];
            dependencies = with pkgs.python3Packages; [
              lxml
              beautifulsoup4
              aiohttp
              pyjwt
            ];
            doCheck = false;
          })
        ];
        dontCheckManifest = true;
      })
      (pkgs.buildHomeAssistantComponent {
        owner = "JonasJoKuJonas";
        domain = "webuntis";
        version = "2.0.3";
        dependencies = [
          pkgs.python-webuntis
        ];
        src = pkgs.fetchFromGitHub {
          owner = "JonasJoKuJonas";
          repo = "homeassistant-WebUntis";
          rev = "v2.0.3";
          hash = "sha256-gK9v+Yl8svXbg1KDqb8+ximhxCqhaJwzme0fU4lBwak=";
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
      notify = [
        {
          name = "all_devices";
          platform = "group";
          services = [
            {service = "mobile_app_hotei";}
            {service = "mobile_app_raijin";}
          ];
        }
      ];
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
