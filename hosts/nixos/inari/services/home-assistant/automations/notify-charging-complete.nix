{...}: {
	# {{{ Notify when car charging complete
	services.home-assistant.config.automation = [
		{
			id = "notify_charging_complete";
			alias = "Notify when ID.3 charging complete";
			trigger = [
				{
					platform = "state";
					entity_id = "sensor.hugo_s_id_3_charging_state";
					to = "NOT_CHARGING";
				}
			];
			condition = [
				{
					condition = "numeric_state";
					entity_id = "sensor.hugo_s_id_3_state_of_charge";
					above = 79;
				}
				{
					condition = "state";
					entity_id = "sensor.hugo_s_id_3_plug_connection_state";
					state = "CONNECTED";
				}
			];
			action = [
				{
					action = "notify.notify";
					data = {
						title = "🔋 Car charging complete";
						message = "ID.3 is charged to {{ states('sensor.hugo_s_id_3_state_of_charge') }}%. Range: {{ states('sensor.hugo_s_id_3_range') }} km";
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
