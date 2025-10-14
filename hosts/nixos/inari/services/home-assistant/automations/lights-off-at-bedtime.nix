{...}: {
	# {{{ Turn off bedroom lights at bedtime
	services.home-assistant.config.automation = [
		{
			id = "lights_off_at_bedtime";
			alias = "Turn off bedroom lights at bedtime";
			trigger = [
				{
					platform = "time";
					at = "23:30:00";
				}
			];
			condition = [
				{
					condition = "state";
					entity_id = "person.hugo_berendi";
					state = "home";
				}
			];
			action = [
				{
					action = "light.turn_on";
					target.entity_id = [
						"light.schlafzimmer_1"
						"light.schlafzimmer_2"
					];
					data = {
						brightness_pct = 5;
						color_temp = 500;
					};
				}
				{
					delay = "00:05:00";
				}
				{
					action = "light.turn_off";
					target.entity_id = [
						"light.schlafzimmer_1"
						"light.schlafzimmer_2"
					];
					data = {
						transition = 120;
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
