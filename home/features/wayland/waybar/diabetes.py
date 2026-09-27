"""Read-only display; never emit treatment alerts from a desktop widget."""

import html
import json
from pathlib import Path
import sys
from urllib.parse import urlparse
from urllib.request import Request, urlopen


def display(config_path):
    try:
        config = json.loads(config_path.read_text())
        if urlparse(config["url"]).scheme != "https":
            raise ValueError("HTTPS required")
        token = Path(config["tokenFile"]).expanduser().read_text().strip()
        req = Request(
            config["url"].rstrip("/") + "/api/glucose",
            headers={"Authorization": "Bearer " + token},
        )
        with urlopen(req, timeout=8) as response:
            reading = json.load(response)
        if not reading.get("available"):
            raise ValueError("No fresh reading")
        age = int(reading["age_seconds"])
        if not 0 <= age <= 600:
            raise ValueError("Stale reading")
        text = f"{reading['display_value']} {reading['unit']} {reading['trend']} · {age // 60}m"
        return {
            "text": html.escape(text),
            "tooltip": f"Dexcom reading {age // 60} minutes old. Check Dexcom before treatment decisions.",
            "class": "glucose",
        }
    except FileNotFoundError:
        return {
            "text": "",
            "tooltip": "Glucose display not configured",
            "class": "unconfigured",
        }
    except Exception:
        return {
            "text": "Glucose unavailable",
            "tooltip": "No verified fresh reading",
            "class": "stale",
        }


if __name__ == "__main__":
    print(json.dumps(display(Path(sys.argv[1]))))
