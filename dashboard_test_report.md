# Yomi Dashboard Test Report

## Dashboard Access
✅ Dashboard is properly configured at `/var/lib/hass/dashboards/yomi.yaml`
✅ Home Assistant is accessible at `https://home.hugo-berendi.de`
✅ API authentication working

## Entity Status (43 total entities checked)

### ✅ Working Entities (34/43 - 79%)

#### Weather & Sun (7/7)
- weather.forecast_home
- sun.sun
- sensor.sun_next_dawn
- sensor.sun_next_rising
- sensor.sun_next_setting
- sensor.sun_next_dusk
- sensor.sun_next_midnight

#### Person & Phone (7/7)
- person.hugo_berendi
- device_tracker.a063
- sensor.a063_next_alarm
- binary_sensor.a063_is_charging
- binary_sensor.a063_bluetooth_state
- binary_sensor.a063_android_auto
- binary_sensor.a063_mobile_data
- binary_sensor.a063_wi_fi_state
- binary_sensor.a063_nfc_state
- binary_sensor.a063_hotspot_state

#### VW ID.3 Car (12/13)
- binary_sensor.hugo_s_id_3_car_is_online
- binary_sensor.hugo_s_id_3_car_is_active
- device_tracker.hugo_s_id_3_tracker
- sensor.hugo_s_id_3_state_of_charge
- binary_sensor.hugo_s_id_3_insufficient_battery_level_warning
- binary_sensor.hugo_s_id_3_climatisation_at_unlock
- binary_sensor.hugo_s_id_3_climatisation_without_external_power
- binary_sensor.hugo_s_id_3_front_window_heating_state
- binary_sensor.hugo_s_id_3_rear_window_heating_state

#### Lights (2/2)
- light.schlafzimmer_1
- light.schlafzimmer_2

#### Other (2/2)
- zone.home

### ❌ Missing/Renamed Entities (9/43 - 21%)

#### Car Entities (1)
- ❌ `sensor.hugo_s_id_3_remaining_range` → Should be: `sensor.hugo_s_id_3_range`

#### Automation Entities (7)
Dashboard uses old names, actual names in Home Assistant:
- ❌ `automation.id_3_doors_or_windows_open_warning` → `automation.warn_if_car_doors_windows_left_open_when_leaving`
- ❌ `automation.id_3_low_battery_10_warning` → `automation.warn_when_id_3_battery_is_low`
- ❌ `automation.remind_to_plug_in_id_3_at_night` → `automation.remind_to_plug_in_car_when_arriving_home`
- ❌ `automation.turn_on_lights_at_sunset` → `automation.turn_on_bedroom_lights_at_sunset_when_home`
- ❌ `automation.turn_off_lights_at_bedtime` → `automation.turn_off_bedroom_lights_at_bedtime`
- ❌ `automation.turn_off_lights_when_away` → `automation.turn_off_bedroom_lights_when_leaving_home`
- ❌ `automation.welcome_home_lights` → `automation.welcome_home_with_warm_lighting`

#### System Sensors (1)
- ❌ `sensor.uptime` → Does not exist

## Additional Automations Not in Dashboard
These exist but aren't shown in the dashboard:
- automation.adjust_light_brightness_based_on_weather
- automation.alarm_wake_up_lights_and_morning_message
- automation.extreme_weather_alert
- automation.morning_weather_alert
- automation.start_id_3_climate_based_on_weather_forecast
- automation.turn_on_lights_on_dark_cloudy_mornings

## Recommendations
1. Update dashboard entity names to match actual automation names
2. Remove or replace the non-existent `sensor.uptime` entity
3. Consider adding the new weather-based automations to the dashboard
