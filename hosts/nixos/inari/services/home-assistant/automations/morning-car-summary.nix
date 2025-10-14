{...}: {
	# {{{ Morning car status summary
	services.home-assistant.config.automation = [
		{
			id = "morning_car_status_summary";
			alias = "Morning ID.3 status summary";
			trigger = [
				{
					platform = "time";
					at = "07:00:00";
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
					action = "notify.notify";
					data = {
						title = "🌅 Good Morning!";
						message = "🔋 Battery: {{ states('sensor.hugo_s_id_3_state_of_charge') }}% | ⚡ Range: {{ states('sensor.hugo_s_id_3_range') }} km | 🔌 Charging: {{ states('sensor.hugo_s_id_3_charging_state') }}";
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
