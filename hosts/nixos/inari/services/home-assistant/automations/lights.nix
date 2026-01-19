{...}: {
  services.home-assistant.config.automation = [
    {
      id = "lights_on_at_sunset";
      alias = "Sunset Lighting";
      description = "Turn on warm lights before sunset when home";
      trigger = [
        {
          platform = "sun";
          event = "sunset";
          offset = "-00:30:00";
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = "person.hugo_berendi";
          state = "home";
        }
      ];
      action = [
        {
          action = "light.turn_on";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data = {
            brightness_pct = 25;
            color_temp_kelvin = 2700;
            transition = 60;
          };
        }
      ];
      mode = "single";
    }
    {
      id = "lights_off_at_bedtime";
      alias = "Bedtime Lights Off";
      description = "Gradually dim and turn off lights at bedtime";
      trigger = [
        {
          platform = "time";
          at = "22:30:00";
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = "person.hugo_berendi";
          state = "home";
        }
        {
          condition = "or";
          conditions = [
            {
              condition = "state";
              entity_id = "light.schlafzimmer_1";
              state = "on";
            }
            {
              condition = "state";
              entity_id = "light.schlafzimmer_2";
              state = "on";
            }
          ];
        }
      ];
      action = [
        {
          action = "light.turn_on";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data = {
            brightness_pct = 5;
            color_temp_kelvin = 2200;
            transition = 300;
          };
        }
        {
          delay = "00:10:00";
        }
        {
          action = "light.turn_off";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data.transition = 120;
        }
      ];
      mode = "single";
    }
    {
      id = "lights_off_when_away";
      alias = "Lights Off When Away";
      description = "Turn off all lights when leaving home";
      trigger = [
        {
          platform = "state";
          entity_id = "person.hugo_berendi";
          from = "home";
          for = "00:03:00";
        }
      ];
      action = [
        {
          action = "light.turn_off";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data.transition = 5;
        }
        {
          action = "switch.turn_off";
          target.entity_id = "switch.scenic_dreamview1_power_switch";
        }
      ];
      mode = "single";
    }
    {
      id = "welcome_home_lights";
      alias = "Welcome Home Lighting";
      description = "Turn on warm lights when arriving home after dark";
      trigger = [
        {
          platform = "state";
          entity_id = "person.hugo_berendi";
          to = "home";
        }
      ];
      condition = [
        {
          condition = "sun";
          after = "sunset";
          after_offset = "-00:30:00";
        }
      ];
      action = [
        {
          action = "light.turn_on";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data = {
            brightness_pct = 30;
            color_temp_kelvin = 2700;
            transition = 5;
          };
        }
      ];
      mode = "single";
    }
    {
      id = "lights_on_cloudy_morning";
      alias = "Cloudy Morning Lights";
      description = "Turn on lights on dark mornings";
      trigger = [
        {
          platform = "template";
          value_template = ''
            {% set wake_time = states('sensor.webuntis_wake_time') %}
            {% if wake_time not in ['unknown', 'unavailable'] %}
              {{ now().strftime('%H:%M') == wake_time }}
            {% else %}
              false
            {% endif %}
          '';
        }
        {
          platform = "time";
          at = "07:00:00";
        }
      ];
      condition = [
        {
          condition = "time";
          weekday = ["mon" "tue" "wed" "thu" "fri"];
        }
        {
          condition = "state";
          entity_id = "person.hugo_berendi";
          state = "home";
        }
        {
          condition = "or";
          conditions = [
            {
              condition = "state";
              entity_id = "weather.forecast_home";
              state = ["cloudy" "fog" "rainy" "snowy" "pouring"];
            }
            {
              condition = "sun";
              before = "sunrise";
            }
          ];
        }
      ];
      action = [
        {
          action = "light.turn_on";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data = {
            brightness_pct = 50;
            color_temp_kelvin = 4000;
            transition = 120;
          };
        }
      ];
      mode = "single";
    }
    {
      id = "adjust_lights_weather";
      alias = "Weather-Based Light Adjustment";
      description = "Adjust light brightness based on weather during daytime";
      trigger = [
        {
          platform = "state";
          entity_id = "weather.forecast_home";
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = "person.hugo_berendi";
          state = "home";
        }
        {
          condition = "sun";
          after = "sunrise";
          before = "sunset";
        }
        {
          condition = "or";
          conditions = [
            {
              condition = "state";
              entity_id = "light.schlafzimmer_1";
              state = "on";
            }
            {
              condition = "state";
              entity_id = "light.schlafzimmer_2";
              state = "on";
            }
          ];
        }
      ];
      action = [
        {
          choose = [
            {
              conditions = [
                {
                  condition = "state";
                  entity_id = "weather.forecast_home";
                  state = ["sunny" "partlycloudy"];
                }
              ];
              sequence = [
                {
                  action = "light.turn_on";
                  target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
                  data = {
                    brightness_pct = 15;
                    transition = 30;
                  };
                }
              ];
            }
            {
              conditions = [
                {
                  condition = "state";
                  entity_id = "weather.forecast_home";
                  state = ["cloudy" "fog" "rainy" "snowy" "pouring"];
                }
              ];
              sequence = [
                {
                  action = "light.turn_on";
                  target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
                  data = {
                    brightness_pct = 50;
                    transition = 30;
                  };
                }
              ];
            }
          ];
        }
      ];
      mode = "restart";
    }
  ];
}
