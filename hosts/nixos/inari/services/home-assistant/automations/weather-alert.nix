{...}: {
	# {{{ Weather alert notifications
	services.home-assistant.config.automation = [
		{
			id = "morning_weather_alert";
			alias = "Morning Weather Alert";
			description = "Sends weather forecast summary in the morning";
			trigger = [
				{
					platform = "time";
					at = "06:00:00";
				}
			];
			condition = [
				{
					condition = "time";
					weekday = ["mon" "tue" "wed" "thu" "fri"];
				}
			];
			action = [
				{
					action = "notify.mobile_app_a063";
					data = {
						title = "🌤️ Morning Weather";
						message = "Today: {{ states('weather.forecast_home') | title }}, {{ state_attr('weather.forecast_home', 'temperature') }}°C. Humidity: {{ state_attr('weather.forecast_home', 'humidity') }}%. Wind: {{ state_attr('weather.forecast_home', 'wind_speed') }} km/h";
					};
				}
			];
			mode = "single";
		}
		{
			id = "extreme_weather_alert";
			alias = "Extreme Weather Alert";
			description = "Alert on extreme weather conditions";
			trigger = [
				{
					platform = "state";
					entity_id = "weather.forecast_home";
					to = ["snowy" "lightning-rainy" "exceptional"];
				}
			];
			action = [
				{
					action = "notify.mobile_app_a063";
					data = {
						title = "⚠️ Weather Alert";
						message = "Extreme weather detected: {{ states('weather.forecast_home') | title }}. Temperature: {{ state_attr('weather.forecast_home', 'temperature') }}°C";
						data = {
							priority = "high";
							ttl = 0;
						};
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
