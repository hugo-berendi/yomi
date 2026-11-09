"""Resolve only encrypted bot-owner DMs, without reading message history."""

import json
from pathlib import Path
from urllib.parse import quote
from matrix_bootstrap import request, validate_auth


def private_room(config, requested=None, call=request):
    auth = json.loads(Path(config["matrixAuth"]).read_text())
    matrix = config["matrix"]
    validate_auth(auth, matrix["userId"])

    def get(endpoint):
        status, result = call(
            matrix["homeserver"],
            endpoint,
            None,
            token=auth["access_token"],
            method="GET",
        )
        if status != 200:
            raise ValueError("Could not verify the private Matrix room")
        return result

    rooms = [requested] if requested else get("joined_rooms")["joined_rooms"]
    matches = []
    for room in rooms:
        if not isinstance(room, str) or not room.startswith("!"):
            continue
        prefix = "rooms/" + quote(room, safe="")
        members = get(prefix + "/joined_members").get("joined", {})
        if set(members) != {matrix["allowedUser"], matrix["userId"]}:
            continue
        encryption = get(prefix + "/state/m.room.encryption")
        if encryption.get("algorithm") == "m.megolm.v1.aes-sha2":
            matches.append(room)
    if len(matches) != 1:
        raise ValueError(
            "Expected one encrypted private chat with Hugo; specify its room ID if several exist"
        )
    return matches[0]
