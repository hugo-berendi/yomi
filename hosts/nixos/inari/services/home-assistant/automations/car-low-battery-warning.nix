{...}: {
	# {{{ Low battery warning
	services.home-assistant.config.automation = [
		{
			id = "car_low_battery_warning";
			alias = "Warn when ID.3 battery is low";
			trigger = [
				{
					platform = "numeric_state";
					entity_id = "sensor.hugo_s_id_3_state_of_charge";
					below = 20;
				}
			];
			condition = [
				{
					condition = "state";
					entity_id = "sensor.hugo_s_id_3_plug_connection_state";
					state = "DISCONNECTED";
				}
			];
			action = [
				{
					action = "notify.notify";
					data = {
						title = "⚠️ Low Battery";
						message = "ID.3 battery at {{ states('sensor.hugo_s_id_3_state_of_charge') }}%. Range: {{ states('sensor.hugo_s_id_3_range') }} km. Consider charging soon.";
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
