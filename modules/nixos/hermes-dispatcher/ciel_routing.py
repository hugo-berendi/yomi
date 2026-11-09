"""Conservative per-turn routing; uncertainty stays on the stronger baseline."""

from datetime import datetime, timezone
import json
import logging
import os
from pathlib import Path
import re


logger = logging.getLogger(__name__)
RISK = re.compile(
    r"auth|secur|sicherheits|secret|passwor|passwör|credential|datenbank|database|migration|"
    r"firewall|\bssh\b|\bsops\b|backup|delete|lösche|loesche|berechtig|payment|zahlung|"
    r"architektur|architecture|systemdesign|race.condition|deadlock|datenverlust|data.loss",
    re.IGNORECASE,
)
ROUTINE = re.compile(
    r"(?:hallo(?: ciel)?|hi(?: ciel)?|hey(?: ciel)?|guten (?:morgen|abend)|danke(?: schön)?|thanks)[!. ]*"
    r"|(?:übersetze|uebersetze|translate|sortiere|sort|formuliere|rephrase)\b.{1,1000}"
    r"|korrigiere (?:den |die |einen )?tippfehler\b.{0,200}",
    re.IGNORECASE | re.DOTALL,
)


def choose(text):
    if not isinstance(text, str) or len(text) > 4000:
        return "standard"
    if RISK.search(text):
        return "complex"
    # Bare confirmations can authorize a consequential previous proposal.
    # Length alone is never positive evidence for the cheap route.
    if ROUTINE.fullmatch(text.strip()):
        return "routine"
    return "standard"


def route_turn(text, *, model, effort):
    path = os.environ.get("CIEL_ROUTING_CONFIG")
    if not path:
        return model, effort
    try:
        config = json.loads(Path(path).read_text())
        baseline = config["baseline"]
        if model != baseline["model"] or effort != baseline["effort"]:
            return model, effort
        tier = choose(text)
        route = config["routes"][tier]
        selected = route["model"], route["effort"]
        if not all(isinstance(value, str) and value for value in selected):
            raise ValueError("Invalid model route")
    except (OSError, ValueError, KeyError, TypeError):
        logger.warning("Ciel routing configuration unavailable; retaining baseline")
        return model, effort
    ledger = os.environ.get("CIEL_ROUTE_LEDGER")
    if ledger:
        try:
            with os.fdopen(
                os.open(ledger, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600), "w"
            ) as stream:
                stream.write(
                    json.dumps(
                        {
                            "time": datetime.now(timezone.utc).isoformat(),
                            "tier": tier,
                            "model": selected[0],
                            "effort": selected[1],
                        }
                    )
                    + "\n"
                )
        except OSError:
            logger.warning("Could not record Ciel model selection")
    return selected
