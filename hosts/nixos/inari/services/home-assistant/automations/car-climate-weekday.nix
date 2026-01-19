{...}: {
  services.home-assistant.config.automation = [
    {
      id = "smart_car_climate_school_days";
      alias = "Smart ID.3 Climate for School Days";
      description = "Pre-conditions car 20 minutes before WebUntis wake time based on weather";
      trigger = [
        {
          platform = "template";
          value_template = ''
            {% set wake_time = states('sensor.webuntis_wake_time') %}
            {% if wake_time not in ['unknown', 'unavailable'] %}
              {% set wake_dt = today_at(wake_time) %}
              {% set climate_time = wake_dt - timedelta(minutes=20) %}
              {{ now().strftime('%H:%M') == climate_time.strftime('%H:%M') }}
            {% else %}
              false
            {% endif %}
          '';
        }
      ];
      condition = [
        {
          condition = "time";
          weekday = ["mon" "tue" "wed" "thu" "fri"];
        }
        {
          condition = "or";
          conditions = [
            {
              condition = "numeric_state";
              entity_id = "weather.forecast_home";
              attribute = "temperature";
              below = 15;
            }
            {
              condition = "numeric_state";
              entity_id = "weather.forecast_home";
              attribute = "temperature";
              above = 25;
            }
            {
              condition = "state";
              entity_id = "weather.forecast_home";
              state = ["snowy" "rainy" "fog"];
            }
          ];
        }
        {
          condition = "state";
          entity_id = "binary_sensor.id_3_charging_cable_connected";
          state = "on";
        }
      ];
      action = [
        {
          action = "climate.turn_on";
          target.entity_id = "climate.id_3_electric_climatisation";
        }
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "Car Climate Started";
            message = ''
              Pre-conditioning ID.3 for school
              Outside: {{ state_attr('weather.forecast_home', 'temperature') }}°C
              Battery: {{ states('sensor.id_3_battery_level') }}%
            '';
            data = {
              tag = "car_climate";
              group = "car";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "fallback_car_climate_weekday";
      alias = "Fallback ID.3 Climate Mon-Thu 07:00";
      description = "Fallback when WebUntis data unavailable";
      trigger = [
        {
          platform = "time";
          at = "07:00:00";
        }
      ];
      condition = [
        {
          condition = "time";
          weekday = ["mon" "tue" "wed" "thu"];
        }
        {
          condition = "template";
          value_template = "{{ states('sensor.webuntis_wake_time') in ['unknown', 'unavailable'] }}";
        }
        {
          condition = "or";
          conditions = [
            {
              condition = "numeric_state";
              entity_id = "weather.forecast_home";
              attribute = "temperature";
              below = 15;
            }
            {
              condition = "numeric_state";
              entity_id = "weather.forecast_home";
              attribute = "temperature";
              above = 25;
            }
          ];
        }
        {
          condition = "state";
          entity_id = "binary_sensor.id_3_charging_cable_connected";
          state = "on";
        }
      ];
      action = [
        {
          action = "climate.turn_on";
          target.entity_id = "climate.id_3_electric_climatisation";
        }
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "Car Climate Started (Fallback)";
            message = "Pre-conditioning ID.3 | {{ state_attr('weather.forecast_home', 'temperature') }}°C outside";
            data = {
              tag = "car_climate";
              group = "car";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "fallback_car_climate_friday";
      alias = "Fallback ID.3 Climate Friday 07:50";
      description = "Fallback for Friday when WebUntis data unavailable";
      trigger = [
        {
          platform = "time";
          at = "07:50:00";
        }
      ];
      condition = [
        {
          condition = "time";
          weekday = ["fri"];
        }
        {
          condition = "template";
          value_template = "{{ states('sensor.webuntis_wake_time') in ['unknown', 'unavailable'] }}";
        }
        {
          condition = "or";
          conditions = [
            {
              condition = "numeric_state";
              entity_id = "weather.forecast_home";
              attribute = "temperature";
              below = 15;
            }
            {
              condition = "numeric_state";
              entity_id = "weather.forecast_home";
              attribute = "temperature";
              above = 25;
            }
          ];
        }
        {
          condition = "state";
          entity_id = "binary_sensor.id_3_charging_cable_connected";
          state = "on";
        }
      ];
      action = [
        {
          action = "climate.turn_on";
          target.entity_id = "climate.id_3_electric_climatisation";
        }
      ];
      mode = "single";
    }
  ];
}
