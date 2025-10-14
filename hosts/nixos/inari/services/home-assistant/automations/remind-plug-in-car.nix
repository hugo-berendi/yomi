{...}: {
	# {{{ Remind to plug in car when arriving home with low battery
	services.home-assistant.config.automation = [
		{
			id = "remind_plug_in_car";
			alias = "Remind to plug in car when arriving home";
			trigger = [
				{
					platform = "state";
					entity_id = "person.hugo_berendi";
					to = "home";
				}
			];
			condition = [
				{
					condition = "state";
					entity_id = "sensor.hugo_s_id_3_plug_connection_state";
					state = "DISCONNECTED";
				}
				{
					condition = "numeric_state";
					entity_id = "sensor.hugo_s_id_3_state_of_charge";
					below = 50;
				}
			];
			action = [
				{
					delay = "00:30:00";
				}
				{
					action = "notify.notify";
					data = {
						title = "🔌 Plug In Reminder";
						message = "Don't forget to plug in your ID.3! Battery at {{ states('sensor.hugo_s_id_3_state_of_charge') }}%";
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
