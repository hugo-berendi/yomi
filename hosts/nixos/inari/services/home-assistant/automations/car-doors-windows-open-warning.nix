{...}: {
	# {{{ Car doors or windows left open warning
	services.home-assistant.config.automation = [
		{
			id = "car_doors_windows_open_warning";
			alias = "Alert if ID.3 doors/windows open while I'm away";
			trigger = [
				{
					platform = "state";
					entity_id = [
						"sensor.hugo_s_id_3_door_front_left_open_status"
						"sensor.hugo_s_id_3_door_front_right_open_status"
						"sensor.hugo_s_id_3_door_rear_left_open_status"
						"sensor.hugo_s_id_3_door_rear_right_open_status"
						"sensor.hugo_s_id_3_window_front_left_open_status"
						"sensor.hugo_s_id_3_window_front_right_open_status"
						"sensor.hugo_s_id_3_window_rear_left_open_status"
						"sensor.hugo_s_id_3_window_rear_right_open_status"
						"sensor.hugo_s_id_3_trunk_open_status"
					];
					to = "open";
				}
			];
			condition = [
				{
					condition = "template";
					value_template = ''
						{% set car_lat = state_attr('device_tracker.hugo_s_id_3_tracker', 'latitude') | float(0) %}
						{% set car_lon = state_attr('device_tracker.hugo_s_id_3_tracker', 'longitude') | float(0) %}
						{% set person_lat = state_attr('person.hugo_berendi', 'latitude') | float(0) %}
						{% set person_lon = state_attr('person.hugo_berendi', 'longitude') | float(0) %}
						{% set distance = ((car_lat - person_lat)**2 + (car_lon - person_lon)**2)**0.5 %}
						{{ distance > 0.001 }}
					'';
				}
			];
			action = [
				{
					action = "notify.notify";
					data = {
						title = "🚗 ID.3 Alert!";
						message = ''
							You are away from your car, and {{ 
								'a door' if is_state('sensor.hugo_s_id_3_door_front_left_open_status', 'open') or 
									is_state('sensor.hugo_s_id_3_door_front_right_open_status', 'open') or 
									is_state('sensor.hugo_s_id_3_door_rear_left_open_status', 'open') or 
									is_state('sensor.hugo_s_id_3_door_rear_right_open_status', 'open') or
									is_state('sensor.hugo_s_id_3_trunk_open_status', 'open')
								else 'a window' 
							}} appears to be open!
						'';
					};
				}
			];
			mode = "single";
		}
	];
	# }}}
}
