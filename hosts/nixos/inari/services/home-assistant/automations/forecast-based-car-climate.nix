{...}: {
	# {{{ Smart car climate using forecast
	services.home-assistant.config.automation = [
		{
			id = "forecast_based_car_climate";
			alias = "Start ID.3 Climate Based on Weather Forecast";
			description = "Uses forecast temperature to pre-warm car intelligently";
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
							condition = "numeric_state";
							entity_id = "weather.forecast_home";
							attribute = "temperature";
							below = 12;
						}
						{
							condition = "state";
							entity_id = "weather.forecast_home";
							state = "snowy";
						}
						{
							condition = "state";
							entity_id = "weather.forecast_home";
							state = "rainy";
						}
					];
				}
			];
			action = [
				{
					action = "notify.mobile_app_a063";
					data = {
						title = "🚗 Car Climate Started";
						message = "Pre-warming ID.3 based on forecast: {{ states('weather.forecast_home') }}, {{ state_attr('weather.forecast_home', 'temperature') }}°C";
					};
				}
				{
					action = "volkswagen_we_connect_id.volkswagen_id_set_climatisation";
					data = {
						start_stop = "start";
						vin = "WVWZZZE17TP012760";
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
