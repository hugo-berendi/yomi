"""Official local T3 MCP pairing/PKCE login; credentials never leave the broker."""

import base64
import hashlib
import json
from pathlib import Path
import secrets
import subprocess
import time
import uuid
from urllib.parse import parse_qs, urlsplit, urlencode
from urllib.request import Request, build_opener, HTTPRedirectHandler, ProxyHandler

from launcher import atomic_text


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def post_json(url, data, headers=None):
    headers = {"Content-Type": "application/json", **(headers or {})}
    body = (
        urlencode(data)
        if headers["Content-Type"] == "application/x-www-form-urlencoded"
        else json.dumps(data)
    )
    request = Request(
        url,
        data=body.encode(),
        headers=headers,
        method="POST",
    )
    # Loopback credentials must not follow inherited HTTP proxy settings.
    with build_opener(ProxyHandler({}), NoRedirect).open(
        request, timeout=35
    ) as response:
        raw = response.read(4_000_001)
        if len(raw) > 4_000_000:
            raise ValueError("T3 response exceeds broker limit")
        return dict(response.headers), raw.decode()


def decode_json(headers, raw):
    content_type = next(
        (v for k, v in headers.items() if k.lower() == "content-type"), ""
    )
    if "text/event-stream" in content_type:
        raw = "\n".join(
            line[5:].strip() for line in raw.splitlines() if line.startswith("data:")
        )
    return json.loads(raw) if raw else None


def b64(data):
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


class McpAuth:
    def __init__(self, config, post=post_json):
        self.config, self.post = config, post
        self.path = Path(config["stateDirectory"]) / "t3-mcp-auth.json"
        origin = urlsplit(config["baseUrl"])
        if (
            origin.scheme != "http"
            or origin.hostname not in {"127.0.0.1", "::1", "localhost"}
            or origin.username
            or origin.password
            or origin.path not in {"", "/"}
            or origin.query
            or origin.fragment
        ):
            raise ValueError("Local MCP credentials require a loopback T3 origin")

    def credentials(self):
        if self.path.exists():
            saved = json.loads(self.path.read_text())
            if saved["expiresAt"] > time.time() + 60:
                return saved
        saved = self.login()
        atomic_text(self.path, json.dumps(saved))
        return saved

    def login(self):
        origin = self.config["baseUrl"].rstrip("/")
        redirect_uri = "http://127.0.0.1/ciel-mcp-callback"

        def post(path, data):
            content_type = (
                "application/x-www-form-urlencoded"
                if path == "/oauth/mcp/token"
                else "application/json"
            )
            headers, raw = self.post(
                origin + path, data, {"Content-Type": content_type}
            )
            return decode_json(headers, raw)

        registered = post(
            "/oauth/mcp/register",
            {"client_name": "Ciel task broker", "redirect_uris": [redirect_uri]},
        )
        # Exactly T3's full-access MCP scope set; no unrelated admin/credential scopes.
        command = [
            self.config["t3"],
            "auth",
            "pairing",
            "create",
            "--base-dir",
            self.config["baseDirectory"],
            "--ttl",
            "5m",
            "--label",
            "Ciel MCP bootstrap",
            "--json",
        ]
        for scope in [
            "orchestration:read",
            "orchestration:operate",
            "settings:write",
            "source-control:write",
        ]:
            command += ["--scope", scope]
        issued = subprocess.run(
            command, capture_output=True, text=True, check=True, timeout=20
        )
        pairing = json.loads(issued.stdout)["credential"]
        verifier, state = b64(secrets.token_bytes(32)), b64(secrets.token_bytes(24))
        resource = origin + "/mcp"
        authorization = {
            "response_type": "code",
            "client_id": registered["client_id"],
            "redirect_uri": redirect_uri,
            "code_challenge": b64(hashlib.sha256(verifier.encode()).digest()),
            "code_challenge_method": "S256",
            "state": state,
            "resource": resource,
        }
        decision = post(
            "/oauth/mcp/decision",
            {
                "authorization": authorization,
                "decision": {
                    "_tag": "pairing-code",
                    "access": "full-access",
                    "code": pairing,
                },
            },
        )
        redirect = urlsplit(decision["redirectTo"])
        values = parse_qs(redirect.query)
        if (
            redirect._replace(query="").geturl() != redirect_uri
            or values.get("state") != [state]
            or values.get("iss") != [origin]
            or not values.get("code")
        ):
            raise ValueError("T3 MCP authorization redirect did not match this login")
        token = post(
            "/oauth/mcp/token",
            {
                "grant_type": "authorization_code",
                "client_id": registered["client_id"],
                "redirect_uri": redirect_uri,
                "code": values["code"][0],
                "code_verifier": verifier,
                "resource": resource,
            },
        )
        if token.get("token_type", "").lower() != "bearer" or not token.get(
            "access_token"
        ):
            raise ValueError("T3 MCP did not issue a bearer session")
        return {
            "access_token": token["access_token"],
            "generation": str(uuid.uuid4()),
            "expiresAt": time.time() + token["expires_in"],
        }
