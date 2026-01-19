{...}: {
  services.home-assistant.config.automation = [
    {
      id = "alarm_wake_up_fallback";
      alias = "Fallback Wake-Up (07:00)";
      description = "Fallback sunrise alarm when WebUntis data unavailable";
      trigger = [
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
          condition = "template";
          value_template = "{{ states('sensor.webuntis_wake_time') in ['unknown', 'unavailable'] }}";
        }
      ];
      action = [
        {
          action = "light.turn_on";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data = {
            brightness_pct = 5;
            color_temp_kelvin = 2200;
          };
        }
        {
          delay = "00:02:00";
        }
        {
          action = "light.turn_on";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data = {
            brightness_pct = 20;
            color_temp_kelvin = 3000;
            transition = 180;
          };
        }
        {
          delay = "00:03:00";
        }
        {
          action = "light.turn_on";
          target.entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
          data = {
            brightness_pct = 60;
            color_temp_kelvin = 4000;
            transition = 120;
          };
        }
      ];
      mode = "single";
    }
    {
      id = "phone_alarm_lights";
      alias = "Sync Lights with Phone Alarm";
      description = "Turn on lights when phone alarm goes off";
      trigger = [
        {
          platform = "state";
          entity_id = "sensor.hotei_next_alarm";
        }
      ];
      condition = [
        {
          condition = "template";
          value_template = ''
            {% set alarm = states('sensor.hotei_next_alarm') %}
            {% if alarm not in ['unknown', 'unavailable'] %}
              {% set alarm_time = as_datetime(alarm) %}
              {{ (alarm_time - now()).total_seconds() | abs < 120 }}
            {% else %}
              false
            {% endif %}
          '';
        }
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
            brightness_pct = 40;
            color_temp_kelvin = 4000;
            transition = 30;
          };
        }
      ];
      mode = "single";
    }
  ];
}
