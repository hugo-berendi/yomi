{...}: {
	# {{{ Smart light control based on weather
	services.home-assistant.config.automation = [
		{
			id = "lights_on_cloudy_morning";
			alias = "Turn On Lights on Dark/Cloudy Mornings";
			description = "Automatically turns on lights when it's dark and cloudy";
			trigger = [
				{
					platform = "time";
					at = "06:30:00";
				}
			];
			condition = [
				{
					condition = "time";
					weekday = ["mon" "tue" "wed" "thu" "fri"];
				}
				{
					condition = "or";
					conditions = [
						{
							condition = "state";
							entity_id = "weather.forecast_home";
							state = "cloudy";
						}
						{
							condition = "state";
							entity_id = "weather.forecast_home";
							state = "fog";
						}
						{
							condition = "state";
							entity_id = "weather.forecast_home";
							state = "rainy";
						}
					];
				}
				{
					condition = "state";
					entity_id = "person.hugo_berendi";
					state = "home";
				}
			];
			action = [
				{
					action = "light.turn_on";
					target = {
						entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
					};
					data = {
						brightness_pct = 40;
						transition = 30;
					};
				}
			];
			mode = "single";
		}
		{
			id = "adjust_lights_on_weather_change";
			alias = "Adjust Light Brightness Based on Weather";
			description = "Dims lights when sunny, brightens when cloudy";
			trigger = [
				{
					platform = "state";
					entity_id = "weather.forecast_home";
				}
			];
			condition = [
				{
					condition = "state";
					entity_id = "person.hugo_berendi";
					state = "home";
				}
				{
					condition = "state";
					entity_id = "sun.sun";
					state = "above_horizon";
				}
			];
			action = [
				{
					choose = [
						{
							conditions = [
								{
									condition = "state";
									entity_id = "weather.forecast_home";
									state = ["sunny" "clear-night"];
								}
							];
							sequence = [
								{
									action = "light.turn_on";
									target = {
										entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
									};
									data = {
										brightness_pct = 20;
										transition = 10;
									};
								}
							];
						}
						{
							conditions = [
								{
									condition = "state";
									entity_id = "weather.forecast_home";
									state = ["cloudy" "fog" "rainy"];
								}
							];
							sequence = [
								{
									action = "light.turn_on";
									target = {
										entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
									};
									data = {
										brightness_pct = 60;
										transition = 10;
									};
								}
							];
						}
					];
				}
			];
			mode = "restart";
		}
	];
	# }}}
}
