{...}: {
	# {{{ Turn on bedroom lights at sunset when home
	services.home-assistant.config.automation = [
		{
			id = "lights_on_at_sunset";
			alias = "Turn on bedroom lights at sunset when home";
			trigger = [
				{
					platform = "sun";
					event = "sunset";
					offset = "-00:30:00";
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
						brightness_pct = 15;
						color_temp = 370;
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
