"""Register once, retaining recovery credentials before any remote side effect."""

import fcntl
import json
import os
from pathlib import Path
import re
import secrets
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(
    base,
    endpoint,
    payload,
    *,
    token=None,
    method="POST",
    content_type="application/json",
):
    url = urlsplit(base)
    if url.scheme != "https" and not (
        url.scheme == "http" and url.hostname in {"127.0.0.1", "::1", "localhost"}
    ):
        raise ValueError("Matrix requires HTTPS or a loopback endpoint")
    # Do not forward registration credentials through inherited proxies/redirects.
    opener = build_opener(ProxyHandler({}), NoRedirect())
    path = endpoint if endpoint.startswith("/") else "/_matrix/client/v3/" + endpoint
    headers = {"Content-Type": content_type}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = Request(
        base.rstrip("/") + path,
        data=payload if isinstance(payload, bytes) else json.dumps(payload).encode(),
        headers=headers,
        method=method,
    )
    try:
        response = opener.open(req, timeout=30)
    except HTTPError as error:
        response = error
    with response:
        return response.status, json.load(response)


def validate_auth(auth, user_id):
    if auth.get("user_id") != user_id or not all(
        isinstance(auth.get(key), str) and auth[key]
        for key in ("access_token", "device_id")
    ):
        raise ValueError("Matrix login does not match the configured bot account")


def bootstrap(state, settings, call=request):
    with (state / "matrix-bootstrap.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        _bootstrap(state, settings, call)


def _bootstrap(state, settings, call):
    from launcher import atomic_text

    user_id = settings["userId"]
    if not re.fullmatch(r"@[a-z0-9._=-]+:[^\s/]+", user_id):
        raise ValueError("Invalid Matrix bot user ID")
    target = state / "matrix-auth.json"
    if target.exists():
        validate_auth(json.loads(target.read_text()), user_id)
        print("Matrix account already configured")
        return
    pending = state / "matrix-registration.json"
    if not pending.exists():
        atomic_text(
            pending,
            json.dumps(
                {
                    "user_id": user_id,
                    "password": secrets.token_urlsafe(48),
                    "device_id": "HERMES_" + secrets.token_hex(8).upper(),
                }
            ),
        )
    credentials = json.loads(pending.read_text())
    if credentials["user_id"] != user_id:
        raise ValueError("Pending Matrix registration belongs to a different account")
    payload = {
        "username": user_id[1:].split(":", 1)[0],
        "password": credentials["password"],
        "device_id": credentials["device_id"],
        "initial_device_display_name": "Yomi Hermes",
        "inhibit_login": False,
    }
    status, result = call(settings["homeserver"], "register", payload)
    attempted = set()
    while status == 401 and "session" in result:
        flows = [f.get("stages", []) for f in result.get("flows", [])]
        flow = next(
            (
                f
                for f in flows
                if f and set(f) <= {"m.login.registration_token", "m.login.dummy"}
            ),
            None,
        )
        remaining = [s for s in (flow or []) if s not in result.get("completed", [])]
        if not remaining or remaining[0] in attempted:
            raise RuntimeError(
                "Matrix registration needs an unsupported authentication step"
            )
        stage = remaining[0]
        attempted.add(stage)
        auth = {"type": stage, "session": result["session"]}
        if stage == "m.login.registration_token":
            credential_dir = Path(os.environ["CREDENTIALS_DIRECTORY"])
            auth["token"] = (credential_dir / "registration-token").read_text().strip()
        status, result = call(
            settings["homeserver"], "register", {**payload, "auth": auth}
        )
    if result.get("errcode") == "M_USER_IN_USE":
        # Covers a crash after registration succeeded but before token persistence.
        # A pre-existing account with another password is never modified.
        status, result = call(
            settings["homeserver"],
            "login",
            {
                "type": "m.login.password",
                "identifier": {"type": "m.id.user", "user": user_id},
                "password": credentials["password"],
                "device_id": credentials["device_id"],
                "initial_device_display_name": "Yomi Hermes",
            },
        )
    if status != 200:
        raise RuntimeError(
            f"Matrix bootstrap failed: HTTP {status}, {result.get('errcode', 'unknown error')}"
        )
    validate_auth(result, user_id)
    atomic_text(
        target,
        json.dumps(
            {key: result[key] for key in ("user_id", "access_token", "device_id")}
        ),
    )
    print("Matrix account configured")
