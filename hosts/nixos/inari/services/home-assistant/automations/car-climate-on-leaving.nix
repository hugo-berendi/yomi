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
					entity_id = "sensor.outdoor_temperature";
					below = 12;
				}
				{
					condition = "state";
					entity_id = "sensor.hugo_s_id_3_plug_connection_state";
					state = "CONNECTED";
				}
			];
			action = [
				{
					action = "button.press";
					target.entity_id = "button.hugo_s_id_3_start_climate";
				}
			];
			mode = "single";
		}
	];
	# }}}
}
