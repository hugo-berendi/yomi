from pydexcom import Dexcom
import pydexcom
import os
import json

mapping = {
    "": ["", "none"],  # Empty string
    "↑↑": ["", "doubleup"],  # Double Up Arrow
    "↑": ["", "up"],  # Up Arrow
    "↗": ["", "upright"],  # Up-Right Arrow
    "→": ["", "right"],  # Right Arrow
    "↘": ["", "downright"],  # Down-Right Arrow
    "↓": ["", "down"],  # Down Arrow
    "↓↓": ["", "doubledown"],  # Double Down Arrow
    "?": ["", "unknown"],  # Question Mark
    "-": ["", "nothing"],  # Minus Sign
}


def send(message: str):
    os.system(f"notify-send 'Dexcom' '{message}' --urgency=critical")


dexcom = Dexcom("HugoBerendi", "destiny2", ous=True)

glucose_reading: pydexcom.GlucoseReading | None = dexcom.get_current_glucose_reading()

if glucose_reading is None:
    raise Exception("No glucose reading")
map = mapping.get(glucose_reading.trend_arrow, "Unknown Icon")
icon = map[0]
value = glucose_reading.value

if value >= 180 or value <= 70:
    send(f"{value} {icon}")

out_data = {"text": f"{value}{icon}", "class": map[1]}

print(json.dumps(out_data))
