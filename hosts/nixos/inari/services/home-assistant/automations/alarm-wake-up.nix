{...}: {
  services.home-assistant.config.automation = [
    {
      id = "alarm_wake_up_lights_and_message";
      alias = "Alarm Wake Up - Lights and Morning Message (Fallback)";
      description = "Fallback wake-up when WebUntis has no lesson data";
      trigger = [
        {
          platform = "time";
          at = "07:30:00";
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
          condition = "template";
          value_template = "{{ states('sensor.webuntis_wake_time') in ['unknown', 'unavailable'] }}";
        }
      ];
      action = [
        {
          action = "light.turn_on";
          target = {
            entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          };
          data = {
            brightness_pct = 30;
            transition = 300;
          };
        }
        {
          action = "notify.all_devices";
          data = {
            title = "Good Morning!";
            message = "{{ states('weather.forecast_home') | title }} {{ state_attr('weather.forecast_home', 'temperature') }}C | Wind: {{ state_attr('weather.forecast_home', 'wind_speed') }} km/h | Humidity: {{ state_attr('weather.forecast_home', 'humidity') }}%";
          };
        }
      ];
      mode = "single";
    }
  ];
}
