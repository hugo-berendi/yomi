{...}: {
  services.home-assistant.config.automation = [
    {
      id = "morning_weather_briefing";
      alias = "Morning Weather Briefing";
      description = "Comprehensive morning weather and schedule summary";
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
      ];
      action = [
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "Good Morning!";
            message = ''
              {{ states('weather.forecast_home') | title }}, {{ state_attr('weather.forecast_home', 'temperature') }}°C
              {% if state_attr('weather.forecast_home', 'temperature') | float < 5 %}Bundle up - it's cold!{% endif %}
              {% if states('weather.forecast_home') in ['rainy', 'pouring'] %}Don't forget an umbrella!{% endif %}
              {% if states('weather.forecast_home') == 'snowy' %}Watch out for slippery roads!{% endif %}

              First lesson: {{ states('sensor.webuntis_next_lesson') | default('Unknown') }}
              School: {{ states('sensor.webuntis_today_s_school_start') }} - {{ states('sensor.webuntis_today_s_school_end') }}
            '';
            data = {
              tag = "morning_briefing";
              group = "daily";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "extreme_weather_alert";
      alias = "Extreme Weather Alert";
      description = "Immediate alert for dangerous weather conditions";
      trigger = [
        {
          platform = "state";
          entity_id = "weather.forecast_home";
          to = ["lightning" "lightning-rainy" "hail" "exceptional"];
        }
        {
          platform = "numeric_state";
          entity_id = "weather.forecast_home";
          attribute = "temperature";
          below = -10;
        }
        {
          platform = "numeric_state";
          entity_id = "weather.forecast_home";
          attribute = "temperature";
          above = 35;
        }
        {
          platform = "numeric_state";
          entity_id = "weather.forecast_home";
          attribute = "wind_speed";
          above = 60;
        }
      ];
      action = [
        {
          action = "notify.all_devices";
          data = {
            title = "Weather Alert!";
            message = ''
              {% set condition = states('weather.forecast_home') %}
              {% set temp = state_attr('weather.forecast_home', 'temperature') | float %}
              {% set wind = state_attr('weather.forecast_home', 'wind_speed') | float %}
              {% if condition in ['lightning', 'lightning-rainy'] %}Thunderstorm warning!
              {% elif condition == 'hail' %}Hail warning! Seek shelter.
              {% elif temp < -10 %}Extreme cold: {{ temp }}°C - Limit outdoor exposure
              {% elif temp > 35 %}Extreme heat: {{ temp }}°C - Stay hydrated!
              {% elif wind > 60 %}High winds: {{ wind }}km/h - Secure loose objects
              {% else %}Severe weather: {{ condition | title }}{% endif %}
            '';
            data = {
              priority = "high";
              ttl = 0;
              tag = "weather_alert";
              group = "alerts";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "rain_reminder";
      alias = "Rain Reminder When Leaving";
      description = "Remind to take umbrella when rain expected";
      trigger = [
        {
          platform = "state";
          entity_id = "person.hugo_berendi";
          from = "home";
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = "weather.forecast_home";
          state = ["rainy" "pouring" "lightning-rainy"];
        }
      ];
      action = [
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "Take an Umbrella!";
            message = "Rain expected: {{ states('weather.forecast_home') | title }}";
            data = {
              tag = "rain_reminder";
              group = "reminders";
            };
          };
        }
      ];
      mode = "single";
    }
  ];
}
