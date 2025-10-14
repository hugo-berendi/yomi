{...}: {
	# {{{ Start car climate Friday morning
	services.home-assistant.config.automation = [
		{
			id = "start_id3_climate_fri";
			alias = "Start ID.3 Climate Fri 08:10 if <15°C";
			trigger = [
				{
					platform = "time";
					at = "08:10:00";
				}
			];
			condition = [
				{
					condition = "time";
					weekday = ["fri"];
				}
				{
					condition = "numeric_state";
					entity_id = "sensor.outdoor_temperature";
					below = 15;
				}
			];
			action = [
				{
					action = "volkswagen_we_connect_id.volkswagen_id_set_climatisation";
					data = {
						start_stop = "start";
						vin = "WVWZZZE17TP012760";
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
