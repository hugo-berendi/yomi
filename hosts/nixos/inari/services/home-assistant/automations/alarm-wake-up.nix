{...}: {
	services.home-assistant.config.automation = [
		{
			id = "alarm_wake_up_lights_and_message";
			alias = "Alarm Wake Up - Lights and Morning Message";
			trigger = [
				{
					platform = "template";
					value_template = "{{ (as_timestamp(states('sensor.a063_next_alarm'), 0) - as_timestamp(now())) <= 600 and (as_timestamp(states('sensor.a063_next_alarm'), 0) - as_timestamp(now())) > 0 }}";
				}
			];
			condition = [
				{
					condition = "template";
					value_template = "{{ states('sensor.a063_next_alarm') not in ['unavailable', 'unknown'] }}";
				}
			];
			action = [
				{
					delay = "{{ (as_timestamp(states('sensor.a063_next_alarm'), 0) - as_timestamp(now())) | int }}";
				}
				{
					action = "light.turn_on";
					target = {
						entity_id = ["light.schlafzimmer_1" "light.schlafzimmer_2"];
					};
					data = {
						brightness_pct = 30;
						transition = 300;
					};
				}
				{
					action = "notify.notify";
					data = {
						title = "🌅 Good Morning!";
						message = "☀️ {{ states('weather.forecast_home') | title }} {{ state_attr('weather.forecast_home', 'temperature') }}°C | 💨 Wind: {{ state_attr('weather.forecast_home', 'wind_speed') }} km/h | 💧 Humidity: {{ state_attr('weather.forecast_home', 'humidity') }}%";
					};
				}
			];
			mode = "single";
		}
	];
}
