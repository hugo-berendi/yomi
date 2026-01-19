{...}: {
  # {{{ Auto-start climate when leaving home if cold
  services.home-assistant.config.automation = [
    {
      id = "car_climate_on_leaving_home";
      alias = "Auto start ID.3 climate when leaving home if cold";
      trigger = [
        {
          platform = "zone";
          entity_id = "person.hugo_berendi";
          zone = "zone.home";
          event = "leave";
        }
      ];
      condition = [
        {
          condition = "numeric_state";
          entity_id = "weather.forecast_home";
          attribute = "temperature";
          below = 12;
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
  # }}}
}
