"""Update the bot profile without putting credentials in command arguments."""

import json
from urllib.parse import quote

from matrix_bootstrap import request, validate_auth


def update_profile(state, settings, *, name=None, avatar=None, call=request):
    auth = json.loads((state / "matrix-auth.json").read_text())
    validate_auth(auth, settings["userId"])
    base = settings["homeserver"]
    profile = "profile/" + quote(auth["user_id"], safe="")

    def send(endpoint, payload, **kwargs):
        status, result = call(
            base, endpoint, payload, token=auth["access_token"], **kwargs
        )
        if status != 200:
            raise RuntimeError(
                f"Matrix profile update failed: HTTP {status}, {result.get('errcode', 'unknown error')}"
            )
        return result

    # Validate the local image before any profile mutation or upload.
    if avatar is not None:
        if avatar.stat().st_size > 5 * 1024 * 1024:
            raise ValueError("Avatar must be at most 5 MiB")
        data = avatar.read_bytes()
        if data.startswith(b"\x89PNG\r\n\x1a\n"):
            content_type = "image/png"
        elif data.startswith(b"\xff\xd8\xff"):
            content_type = "image/jpeg"
        elif data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            content_type = "image/webp"
        else:
            raise ValueError("Avatar must be a PNG, JPEG or WebP image")
    if name is not None:
        if not name.strip() or len(name) > 100:
            raise ValueError("Display name must contain 1–100 characters")
        send(profile + "/displayname", {"displayname": name}, method="PUT")
    if avatar is not None:
        result = send("/_matrix/media/v3/upload", data, content_type=content_type)
        uri = result.get("content_uri", "")
        if not isinstance(uri, str) or not uri.startswith("mxc://"):
            raise ValueError("Matrix upload did not return a media URI")
        send(profile + "/avatar_url", {"avatar_url": uri}, method="PUT")
    print("Matrix profile updated")
