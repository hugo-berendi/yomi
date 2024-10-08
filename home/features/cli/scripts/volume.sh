#!/usr/bin/env bash

iDIR="$HOME/dotfiles/yomi/home/features/desktop/dunst/icons"

# Get Volume
get_volume() {
	volume=$(pamixer --get-volume)
	echo "$volume"
}

# Get Microphone Volume
get_mic_volume() {
	mic_volume=$(pamixer --default-source --get-volume)
	echo "$mic_volume"
}

# Get icons for Volume
get_icon() {
	current=$(get_volume)
	if [[ "$current" -eq "0" ]]; then
		echo "$iDIR/volume-mute.png"
	elif [[ "$current" -le "30" ]]; then
		echo "$iDIR/volume-low.png"
	elif [[ "$current" -le "60" ]]; then
		echo "$iDIR/volume-mid.png"
	else
		echo "$iDIR/volume-high.png"
	fi
}

# Get icons for Microphone
get_mic_icon() {
	current=$(get_mic_volume)
	if [[ "$current" -eq "0" ]]; then
		echo "$iDIR/microphone-mute.png"
	else
		echo "$iDIR/microphone.png"
	fi
}

# Notify Volume
notify_volume() {
	local volume=$(get_volume)
	notify-send -u low -i "$(get_icon)" "Volume: $volume%" -h int:value:"$volume"
}

# Notify Microphone Volume
notify_mic() {
	local mic_volume=$(get_mic_volume)
	notify-send -u low -i "$(get_mic_icon)" "Mic Level: $mic_volume%" -h int:value:"$mic_volume"
}

# Increase Volume
inc_volume() {
	pamixer -i 5 && notify_volume
}

# Decrease Volume
dec_volume() {
	pamixer -d 5 && notify_volume
}

# Toggle Mute Volume
toggle_mute() {
	if [ "$(pamixer --get-mute)" == "false" ]; then
		pamixer -m && notify-send -u low -i "$iDIR/volume-mute.png" "Volume Muted" -h int:value:0
	else
		pamixer -u && notify_volume
	fi
}

# Toggle Mute Microphone
toggle_mic() {
	if [ "$(pamixer --default-source --get-mute)" == "false" ]; then
		pamixer --default-source -m && notify-send -u low -i "$iDIR/microphone-mute.png" "Microphone Muted" -h int:value:0
	else
		pamixer --default-source -u && notify_mic
	fi
}

# Increase Microphone Volume
inc_mic_volume() {
	pamixer --default-source -i 5 && notify_mic
}

# Decrease Microphone Volume
dec_mic_volume() {
	pamixer --default-source -d 5 && notify_mic
}

# Media Controls
media_control() {
	case "$1" in
		--stop)
			playerctl stop
			notify-send -u low -i "$iDIR/media-stop.png" "Media Stopped"
			;;
		--previous)
			playerctl previous
			notify-send -u low -i "$iDIR/media-previous.png" "Previous Track"
			;;
		--next)
			playerctl next
			notify-send -u low -i "$iDIR/media-next.png" "Next Track"
			;;
		--play-pause)
			playerctl play-pause
			notify-send -u low -i "$iDIR/media-play-pause.png" "Play/Pause Toggled"
			;;
	esac
}

# Execute based on the argument provided
if [[ "$1" == "--inc" ]]; then
	inc_volume
elif [[ "$1" == "--dec" ]]; then
	dec_volume
elif [[ "$1" == "--toggle" ]]; then
	toggle_mute
elif [[ "$1" == "--mic-inc" ]]; then
	inc_mic_volume
elif [[ "$1" == "--mic-dec" ]]; then
	dec_mic_volume
elif [[ "$1" == "--toggle-mic" ]]; then
	toggle_mic
elif [[ "$1" == "--stop" || "$1" == "--previous" || "$1" == "--next" || "$1" == "--play-pause" ]]; then
	media_control "$1"
else
	echo "Usage: $0 [--inc | --dec | --toggle | --mic-inc | --mic-dec | --toggle-mic | --stop | --previous | --next | --play-pause]"
fi
