#!/usr/bin/env bash

set -euo pipefail

SINK="@DEFAULT_AUDIO_SINK@"
SOURCE="@DEFAULT_AUDIO_SOURCE@"
STEP="5%"
MAX_VOL="1.0"

to_percent() {
	awk '{printf "%d", $1 * 100}'
}

get_volume() {
	wpctl get-volume "$SINK" | awk '{print $2}' | to_percent
}

get_mic_volume() {
	wpctl get-volume "$SOURCE" | awk '{print $2}' | to_percent
}

inc_volume() {
	wpctl set-volume -l "$MAX_VOL" "$SINK" "${STEP}+"
}

dec_volume() {
	wpctl set-volume "$SINK" "${STEP}-"
}

toggle_mute() {
	wpctl set-mute "$SINK" toggle
}

toggle_mic() {
	wpctl set-mute "$SOURCE" toggle
}

inc_mic_volume() {
	wpctl set-volume "$SOURCE" "${STEP}+"
}

dec_mic_volume() {
	wpctl set-volume "$SOURCE" "${STEP}-"
}

media_control() {
	case "$1" in
	--stop)
		playerctl stop
		;;
	--previous)
		playerctl previous
		;;
	--next)
		playerctl next
		;;
	--play-pause)
		playerctl play-pause
		;;
	esac
}

case "${1:-}" in
--get)
	get_volume
	;;
--get-mic)
	get_mic_volume
	;;
--inc)
	inc_volume
	;;
--dec)
	dec_volume
	;;
--toggle)
	toggle_mute
	;;
--mic-inc)
	inc_mic_volume
	;;
--mic-dec)
	dec_mic_volume
	;;
--toggle-mic)
	toggle_mic
	;;
--stop | --previous | --next | --play-pause)
	media_control "$1"
	;;
*)
	echo "Usage: $0 [--get | --get-mic | --inc | --dec | --toggle | --mic-inc | --mic-dec | --toggle-mic | --stop | --previous | --next | --play-pause]"
	exit 1
	;;
esac
