{...}: {
	# {{{ Welcome home lighting
	services.home-assistant.config.automation = [
		{
			id = "welcome_home_lights";
			alias = "Welcome home with warm lighting";
			trigger = [
				{
					platform = "state";
					entity_id = "person.hugo_berendi";
					to = "home";
				}
			];
			condition = [
				{
					condition = "sun";
					after = "sunset";
					after_offset = "-01:00:00";
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
						brightness_pct = 20;
						color_temp = 380;
						transition = 3;
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
