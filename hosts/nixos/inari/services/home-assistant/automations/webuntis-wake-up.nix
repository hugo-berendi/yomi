{...}: {
  services.home-assistant.config = {
    template = [
      {
        sensor = [
          {
            name = "WebUntis Wake Time";
            unique_id = "webuntis_wake_time";
            state = ''
              {% set datetime = states('sensor.webuntis_next_lesson_to_wake_up') %}
              {% if datetime not in ["unknown", "unavailable", "None", none] %}
                {{ (as_datetime(datetime) - timedelta(hours=1, minutes=20)) | as_timestamp | timestamp_custom('%H:%M', true) }}
              {% else %}
                unknown
              {% endif %}
            '';
            icon = "mdi:alarm";
          }
          {
            name = "WebUntis Prep Time";
            unique_id = "webuntis_prep_time";
            state = ''
              {% set datetime = states('sensor.webuntis_next_lesson_to_wake_up') %}
              {% if datetime not in ["unknown", "unavailable", "None", none] %}
                {{ (as_datetime(datetime) - timedelta(minutes=40)) | as_timestamp | timestamp_custom('%H:%M', true) }}
              {% else %}
                unknown
              {% endif %}
            '';
            icon = "mdi:clock-outline";
          }
          {
            name = "School Day Status";
            unique_id = "school_day_status";
            state = ''
              {% set start = states('sensor.webuntis_today_s_school_start') %}
              {% set end = states('sensor.webuntis_today_s_school_end') %}
              {% if start in ['unknown', 'unavailable'] %}
                No School
              {% elif now().strftime('%H:%M') < start %}
                Before School
              {% elif now().strftime('%H:%M') > end %}
                After School
              {% else %}
                In School
              {% endif %}
            '';
            icon = "mdi:school";
          }
        ];
      }
    ];
    automation = [
      {
        id = "webuntis_dynamic_wake_up";
        alias = "WebUntis Dynamic Wake-Up";
        description = "Sunrise alarm simulation based on school schedule";
        trigger = [
          {
            platform = "template";
            value_template = "{{ now().strftime('%H:%M') == states('sensor.webuntis_wake_time') }}";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "person.hugo_berendi";
            state = "home";
          }
          {
            condition = "template";
            value_template = "{{ states('sensor.webuntis_wake_time') not in ['unknown', 'unavailable'] }}";
          }
          {
            condition = "time";
            weekday = ["mon" "tue" "wed" "thu" "fri"];
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
        id = "webuntis_prep_reminder";
        alias = "WebUntis Leave Reminder";
        description = "Reminder to leave for school";
        trigger = [
          {
            platform = "template";
            value_template = "{{ now().strftime('%H:%M') == states('sensor.webuntis_prep_time') }}";
          }
        ];
        condition = [
          {
            condition = "state";
            entity_id = "person.hugo_berendi";
            state = "home";
          }
          {
            condition = "template";
            value_template = "{{ states('sensor.webuntis_prep_time') not in ['unknown', 'unavailable'] }}";
          }
        ];
        action = [
          {
            action = "notify.mobile_app_hotei";
            data = {
              title = "Time to Leave!";
              message = ''
                First lesson in 40 minutes
                {{ states('sensor.webuntis_next_lesson') }}
                {% if is_state('binary_sensor.id_3_charging_cable_connected', 'on') %}Don't forget to unplug the car!{% endif %}
              '';
              data = {
                tag = "leave_reminder";
                priority = "high";
              };
            };
          }
        ];
        mode = "single";
      }
    ];
  };
}
