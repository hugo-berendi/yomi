{...}: {
	# {{{ Turn off bedroom lights when leaving home
	services.home-assistant.config.automation = [
		{
			id = "lights_off_when_away";
			alias = "Turn off bedroom lights when leaving home";
			trigger = [
				{
					platform = "state";
					entity_id = "person.hugo_berendi";
					from = "home";
					to = "not_home";
					for = "00:05:00";
				}
			];
			action = [
				{
					action = "light.turn_off";
					target.entity_id = [
						"light.schlafzimmer_1"
						"light.schlafzimmer_2"
					];
				}
			];
			mode = "single";
		}
	];
	# }}}
}
