#!/usr/bin/env bash

alt="$(playerctl -p spotify metadata mpris:artUrl)"
tooltip="$(playerctl -p spotify metadata title) - $(playerctl -p spotify metadata artist)"
class="class"
percentage="100"

echo "{\"text\": \"$tooltip\", \"alt\": \"$alt\", \"tooltip\": \"$tooltip\", \"class\": \"$class\", \"percentage\": \"$percentage\" }"
