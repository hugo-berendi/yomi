"""Add the loopback alert webhook to Hermes' configuration at gateway start.

The routes deliver into exactly one room: the encrypted chat that holds only
Hugo and Ciel, verified the same way the task broker verifies it. If that
cannot be established, or the signing secret is missing, the gateway starts
without the webhook platform. Hugo's chat keeps working and the alert router
sees a refused connection, retries, and keeps pushing to ntfy regardless.
"""

import copy
import json
import os
import sys
from pathlib import Path

CREDENTIAL = "alert-webhook"
MINIMUM_SECRET = 32


def read_secret(directory):
    if not directory:
        return None
    try:
        secret = (Path(directory) / CREDENTIAL).read_text().strip()
    except OSError:
        return None
    return secret if len(secret) >= MINIMUM_SECRET else None


def configure(configuration, webhook, *, secret, room):
    """Return ``configuration`` with the webhook platform bound to ``room``."""
    result = copy.deepcopy(configuration)
    routes = {}
    for name, route in webhook["routes"].items():
        route = copy.deepcopy(route)
        route["secret"] = secret
        route["deliver"] = "matrix"
        route["deliver_extra"] = {"chat_id": room}
        routes[name] = route
    result.setdefault("platforms", {})["webhook"] = {
        "enabled": True,
        "extra": {
            "host": "127.0.0.1",
            "port": webhook["port"],
            "rate_limit": webhook.get("rateLimit", 30),
            "max_body_bytes": webhook.get("maxBodyBytes", 65536),
            "routes": routes,
        },
    }
    return result


def gateway_configuration(settings, state, *, environ=os.environ, resolve=None):
    """Hermes config.yaml content (JSON is valid YAML) for the gateway."""
    configuration = json.loads(Path(settings["configuration"]).read_text())
    webhook = settings.get("alertWebhook")
    if not webhook:
        return configuration
    secret = read_secret(environ.get("CREDENTIALS_DIRECTORY"))
    if secret is None:
        print("alert webhook disabled: signing secret unavailable", file=sys.stderr)
        return configuration
    if resolve is None:
        from matrix_rooms import private_room as resolve
    try:
        room = resolve(
            {
                "matrixAuth": str(state / "matrix-auth.json"),
                "matrix": settings["matrix"],
            }
        )
    except Exception as error:  # noqa: BLE001 - any failure means no webhook
        print(
            f"alert webhook disabled: {type(error).__name__}: {error}", file=sys.stderr
        )
        return configuration
    return configure(configuration, webhook, secret=secret, room=room)
