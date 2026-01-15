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
        ];
      }
    ];
    automation = [
      {
        id = "webuntis_dynamic_wake_up";
        alias = "WebUntis Dynamic Wake-Up";
        description = "Wake up based on first lesson time from WebUntis";
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
              title = "Good Morning! School Day";
              message = ''
                First lesson: {{ state_attr('sensor.webuntis_next_lesson', 'subjects') | default('Unknown', true) }}
                School starts: {{ states('sensor.webuntis_today_school_start') }}
                School ends: {{ states('sensor.webuntis_today_school_end') }}
              '';
            };
          }
        ];
        mode = "single";
      }
    ];
  };
}
