#!/usr/bin/env bash

set -euo pipefail

STEP="5%"
MIN_BRIGHTNESS=5

# Get brightness
get_backlight() {
	max=$(brightnessctl m)
	current=$(brightnessctl g)
	awk "BEGIN {printf \"%.0f\n\", $current / $max * 100}"
}

# Increase brightness
inc_backlight() {
	brightnessctl s "${STEP}+"
}

# Decrease brightness
dec_backlight() {
	current="$(get_backlight)"
	if [ "$current" -le "$MIN_BRIGHTNESS" ]; then
		brightnessctl s "${MIN_BRIGHTNESS}%"
	else
		brightnessctl s "${STEP}-"
	fi
}

case "${1:-}" in
--get)
	get_backlight
	;;
--inc)
	inc_backlight
	;;
--dec)
	dec_backlight
	;;
*)
	echo "Usage: $0 [--get | --inc | --dec]"
	exit 1
	;;
esac
