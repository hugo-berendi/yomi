#!/usr/bin/env bash

TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIzNmY1OTJlYTJjMDI0YTQ3Yjk2NjQyNWZmYTZlNDM3OCIsImlhdCI6MTc2MDQyNDgzMSwiZXhwIjoyMDc1Nzg0ODMxfQ.dU-EFHXo8ogLq8aatdEDXtxtE3-tWvnMVLK3oz7KX_o"
BASE_URL="https://home.hugo-berendi.de"

# Extract all entities from the dashboard
ENTITIES=(
  "weather.forecast_home"
  "sensor.a063_next_alarm"
  "sun.sun"
  "sensor.sun_next_dawn"
  "sensor.sun_next_rising"
  "person.hugo_berendi"
  "device_tracker.a063"
  "binary_sensor.a063_is_charging"
  "binary_sensor.a063_bluetooth_state"
  "binary_sensor.hugo_s_id_3_car_is_online"
  "binary_sensor.hugo_s_id_3_car_is_active"
  "device_tracker.hugo_s_id_3_tracker"
  "sensor.hugo_s_id_3_state_of_charge"
  "sensor.hugo_s_id_3_remaining_range"
  "binary_sensor.hugo_s_id_3_insufficient_battery_level_warning"
  "binary_sensor.hugo_s_id_3_climatisation_at_unlock"
  "binary_sensor.hugo_s_id_3_climatisation_without_external_power"
  "binary_sensor.hugo_s_id_3_front_window_heating_state"
  "binary_sensor.hugo_s_id_3_rear_window_heating_state"
  "automation.start_id_3_climate_mon_thu_07_20_if_15degc"
  "automation.start_id_3_climate_fri_08_10_if_15degc"
  "automation.auto_start_id_3_climate_when_leaving_home_if_cold"
  "automation.morning_id_3_status_summary"
  "automation.id_3_doors_or_windows_open_warning"
  "automation.id_3_low_battery_10_warning"
  "automation.notify_when_id_3_charging_complete"
  "automation.remind_to_plug_in_id_3_at_night"
  "light.schlafzimmer_1"
  "light.schlafzimmer_2"
  "automation.turn_on_lights_at_sunset"
  "automation.turn_off_lights_at_bedtime"
  "automation.turn_off_lights_when_away"
  "automation.welcome_home_lights"
  "sensor.sun_next_setting"
  "sensor.sun_next_dusk"
  "sensor.sun_next_midnight"
  "sensor.uptime"
  "zone.home"
  "binary_sensor.a063_android_auto"
  "binary_sensor.a063_mobile_data"
  "binary_sensor.a063_wi_fi_state"
  "binary_sensor.a063_nfc_state"
  "binary_sensor.a063_hotspot_state"
)

echo "Checking ${#ENTITIES[@]} entities from yomi dashboard..."
echo ""

MISSING=0
EXISTING=0

for entity in "${ENTITIES[@]}"; do
  response=$(curl -sSL -H "Authorization: Bearer $TOKEN" "$BASE_URL/api/states/$entity" 2>&1)
  
  if echo "$response" | grep -q "404"; then
    echo "❌ MISSING: $entity"
    ((MISSING++))
  elif echo "$response" | grep -q "entity_id"; then
    echo "✅ EXISTS:  $entity"
    ((EXISTING++))
  else
    echo "⚠️  UNKNOWN: $entity (unexpected response)"
  fi
done

echo ""
echo "Summary: $EXISTING existing, $MISSING missing"
