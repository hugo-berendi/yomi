{...}: {
  services.home-assistant.config.automation = [
    {
      id = "morning_car_status_summary";
      alias = "Morning ID.3 Status Summary";
      description = "Comprehensive morning car status with weather context";
      trigger = [
        {
          platform = "time";
          at = "06:45:00";
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
              ID.3: {{ states('sensor.id_3_battery_level') }}% | {{ states('sensor.id_3_electric_range') }}km
              {% if is_state('binary_sensor.id_3_charging_cable_connected', 'on') %}Plugged in{% else %}Not plugged in{% endif %}
              Weather: {{ states('weather.forecast_home') | title }}, {{ state_attr('weather.forecast_home', 'temperature') }}°C
            '';
            data = {
              tag = "morning_summary";
              group = "daily";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "car_doors_windows_open_warning";
      alias = "ID.3 Security Alert - Doors/Windows Open";
      description = "Alert when car doors/windows are open while away";
      trigger = [
        {
          platform = "state";
          entity_id = [
            "binary_sensor.id_3_doors_locked"
            "binary_sensor.id_3_windows_closed"
            "binary_sensor.id_3_trunk_closed"
          ];
          to = "off";
          for = "00:02:00";
        }
      ];
      condition = [
        {
          condition = "template";
          value_template = ''
            {% set car_lat = state_attr('device_tracker.id_3_position', 'latitude') | float(0) %}
            {% set car_lon = state_attr('device_tracker.id_3_position', 'longitude') | float(0) %}
            {% set person_lat = state_attr('person.hugo_berendi', 'latitude') | float(0) %}
            {% set person_lon = state_attr('person.hugo_berendi', 'longitude') | float(0) %}
            {% set distance = ((car_lat - person_lat)**2 + (car_lon - person_lon)**2)**0.5 * 111000 %}
            {{ distance > 50 }}
          '';
        }
      ];
      action = [
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "ID.3 Security Alert!";
            message = ''
              {% if is_state('binary_sensor.id_3_doors_locked', 'off') %}Doors unlocked!{% endif %}
              {% if is_state('binary_sensor.id_3_windows_closed', 'off') %}Windows open!{% endif %}
              {% if is_state('binary_sensor.id_3_trunk_closed', 'off') %}Trunk open!{% endif %}
            '';
            data = {
              priority = "high";
              ttl = 0;
              tag = "car_security";
              group = "car";
              actions = [
                {
                  action = "LOCK_CAR";
                  title = "Lock Car";
                }
              ];
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "car_low_battery_warning";
      alias = "ID.3 Low Battery Warning";
      description = "Alert when battery is low and not charging";
      trigger = [
        {
          platform = "numeric_state";
          entity_id = "sensor.id_3_battery_level";
          below = 20;
        }
        {
          platform = "numeric_state";
          entity_id = "sensor.id_3_battery_level";
          below = 15;
        }
        {
          platform = "numeric_state";
          entity_id = "sensor.id_3_battery_level";
          below = 10;
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = "binary_sensor.id_3_charging_cable_connected";
          state = "off";
        }
      ];
      action = [
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "ID.3 Low Battery!";
            message = ''
              Battery: {{ states('sensor.id_3_battery_level') }}%
              Range: {{ states('sensor.id_3_electric_range') }}km
              Please charge soon!
            '';
            data = {
              priority = "high";
              tag = "car_battery";
              group = "car";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "remind_plug_in_car";
      alias = "Remind to Plug In ID.3";
      description = "Reminder when arriving home with low battery";
      trigger = [
        {
          platform = "state";
          entity_id = "person.hugo_berendi";
          to = "home";
          for = "00:15:00";
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = "binary_sensor.id_3_charging_cable_connected";
          state = "off";
        }
        {
          condition = "numeric_state";
          entity_id = "sensor.id_3_battery_level";
          below = 60;
        }
      ];
      action = [
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "Plug In Reminder";
            message = ''
              ID.3 battery at {{ states('sensor.id_3_battery_level') }}%
              Don't forget to plug in!
            '';
            data = {
              tag = "plug_reminder";
              group = "car";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "notify_charging_complete";
      alias = "ID.3 Charging Complete";
      description = "Notify when car finishes charging";
      trigger = [
        {
          platform = "state";
          entity_id = "sensor.id_3_charging_state";
          from = "charging";
          to = "notCharging";
        }
      ];
      condition = [
        {
          condition = "numeric_state";
          entity_id = "sensor.id_3_battery_level";
          above = 75;
        }
      ];
      action = [
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "ID.3 Charged!";
            message = ''
              Battery: {{ states('sensor.id_3_battery_level') }}%
              Range: {{ states('sensor.id_3_electric_range') }}km
            '';
            data = {
              tag = "charging_complete";
              group = "car";
            };
          };
        }
      ];
      mode = "single";
    }
    {
      id = "lock_car_action";
      alias = "Lock Car from Notification";
      description = "Handle lock car action from notification";
      trigger = [
        {
          platform = "event";
          event_type = "mobile_app_notification_action";
          event_data = {
            action = "LOCK_CAR";
          };
        }
      ];
      action = [
        {
          action = "lock.lock";
          target.entity_id = "lock.id_3_door_locked";
        }
        {
          action = "notify.mobile_app_hotei";
          data = {
            title = "ID.3 Locked";
            message = "Car has been locked remotely";
            data = {
              tag = "car_security";
            };
          };
        }
      ];
      mode = "single";
    }
  ];
}
