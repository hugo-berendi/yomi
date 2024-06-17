#!/bin/bash

notify-send "Package update started" "The system packages will be updated."

kitty -e sudo paru -Syyu

notify-send "Package update complete" "The system packages have been updated."
