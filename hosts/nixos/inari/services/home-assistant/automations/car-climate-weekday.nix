{...}: {
	# {{{ Start car climate Mon-Thu morning
	services.home-assistant.config.automation = [
		{
			id = "start_id3_climate_mon_thu";
			alias = "Start ID.3 Climate Mon-Thu 07:20 if <15°C";
			trigger = [
				{
					platform = "time";
					at = "07:20:00";
				}
			];
			condition = [
				{
					condition = "time";
					weekday = ["mon" "tue" "wed" "thu"];
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
