"""Run in the managed VM: real HTTP/SQLite, fake T3, no production credentials."""

import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import tempfile
import threading
from urllib.parse import parse_qs, urlencode

from dispatch_core import Dispatcher
from dispatch_store import Store
from t3_backend import T3Backend
from t3_mcp import NativeMcp
from t3_mcp_auth import McpAuth, b64


def main():
    os.environ.update(
        http_proxy="http://127.0.0.1:1",
        HTTP_PROXY="http://127.0.0.1:1",
        no_proxy="",
        NO_PROXY="",
    )
    authorizations, commands, observed = {}, {}, []
    lose_reply, lose_session = [True], [True]

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def reply(self, value, status=200, session=False, sse=False):
            self.send_response(status)
            self.send_header(
                "Content-Type", "text/event-stream" if sse else "application/json"
            )
            if session:
                self.send_header("Mcp-Session-Id", "transport-session")
            self.end_headers()
            if value is not None:
                encoded = json.dumps(value)
                self.wfile.write(
                    ("data: " + encoded + "\n\n" if sse else encoded).encode()
                )

        def do_POST(self):
            raw = self.rfile.read(int(self.headers["Content-Length"])).decode()
            if self.path.endswith("/token"):
                assert (
                    self.headers["Content-Type"] == "application/x-www-form-urlencoded"
                )
                data = {k: v[0] for k, v in parse_qs(raw).items()}
                assert (
                    b64(hashlib.sha256(data["code_verifier"].encode()).digest())
                    == authorizations["code_challenge"]
                )
                self.reply(
                    {
                        "access_token": "dummy-token",
                        "token_type": "Bearer",
                        "expires_in": 3600,
                    }
                )
                return
            data = json.loads(raw)
            if self.path.endswith("/register"):
                observed.append("registered")
                self.reply({"client_id": "registered"})
            elif self.path.endswith("/decision"):
                authorizations.update(data["authorization"])
                self.reply(
                    {
                        "redirectTo": authorizations["redirect_uri"]
                        + "?"
                        + urlencode(
                            {
                                "code": "dummy-code",
                                "state": authorizations["state"],
                                "iss": origin,
                            }
                        )
                    }
                )
            else:
                assert self.path == "/mcp"
                assert self.headers["Authorization"] == "Bearer dummy-token"
                if data["method"] == "initialize":
                    observed.append("initialize")
                    self.reply(
                        {
                            "jsonrpc": "2.0",
                            "id": data["id"],
                            "result": {"protocolVersion": "2025-06-18"},
                        },
                        session=True,
                    )
                elif data["method"] == "notifications/initialized":
                    self.reply(None, status=202)
                else:
                    assert self.headers["Mcp-Session-Id"] == "transport-session"
                    name, args = data["params"]["name"], data["params"]["arguments"]
                    if lose_session[0]:
                        lose_session[0] = False
                        self.reply(None, status=404)
                        return
                    if name == "t3_project_list":
                        result = {
                            "projects": [
                                {
                                    "id": "allowed",
                                    "title": "Repo",
                                    "workspaceRoot": "/repo",
                                }
                            ],
                            "nextCursor": None,
                        }
                    elif name == "t3_thread_launch":
                        key = args["clientRequestId"]
                        commands.setdefault(key, args)
                        assert commands[key] == args
                        if lose_reply[0]:
                            lose_reply[0] = False
                            self.close_connection = True
                            return  # accepted, response lost
                        result = {
                            "threadId": "mcp:server-issued",
                            "link": "t3-thread://v2/test/mcp:server-issued",
                        }
                    elif name == "t3_thread_read":
                        result = {
                            "thread": {},
                            "recentRuns": [
                                {"runId": "run", "ordinal": 1, "status": "running"}
                            ],
                            "items": [],
                        }
                    else:
                        raise AssertionError(name)
                    self.reply(
                        {
                            "jsonrpc": "2.0",
                            "id": data["id"],
                            "result": {
                                "content": [
                                    {"type": "text", "text": json.dumps(result)}
                                ]
                            },
                        },
                        sse=True,
                    )

    server = HTTPServer(("127.0.0.1", 0), Handler)
    origin = f"http://127.0.0.1:{server.server_port}"
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fake_cli = root / "t3"
            fake_cli.write_text(
                '#!/usr/bin/env python3\nprint(\'{"credential":"dummy-pairing"}\')\n'
            )
            fake_cli.chmod(0o700)
            config = {
                "stateDirectory": directory,
                "baseUrl": origin,
                "t3": str(fake_cli),
                "baseDirectory": directory,
                "projectIds": ["allowed"],
                "taste": "",
                "routes": {
                    k: {"model": "luna", "effort": "low"}
                    for k in ["routine", "standard", "complex"]
                },
            }

            def dispatcher():
                store = Store(root / "db")
                native = NativeMcp(config, McpAuth(config), store)

                def supplement(operation, *args, **kwargs):
                    assert operation == "subscribeServerConfig"
                    return {
                        "config": {
                            "providers": [
                                {
                                    "instanceId": "codex",
                                    "enabled": True,
                                    "installed": True,
                                    "status": "ready",
                                }
                            ]
                        }
                    }

                return Dispatcher(
                    config,
                    store,
                    T3Backend(native, supplement),
                    verify_room=lambda cfg, room: "!dm:host",
                )

            first = dispatcher()
            try:
                first.start(
                    {
                        "task_key": "matrix-event:1",
                        "description": "Fix menu",
                        "project_id": "allowed",
                    }
                )
                raise AssertionError("Expected lost reply")
            except ConnectionError:
                pass
            assert first.store.task("matrix-event:1")["last_status"] == "launching"
            assert first.store.task("matrix-event:1")["thread_id"] is None
            first.store.db.close()
            resumed = dispatcher()
            resumed.tick()
            assert (
                resumed.store.task("matrix-event:1")["thread_id"] == "mcp:server-issued"
            )
            assert resumed.store.task("matrix-event:1")["last_status"] == "running"
            assert len(commands) == 1
            assert observed.count("registered") == 1
            assert (
                observed.count("initialize") == 3
            )  # initial, 404 renewal, process restart
            resumed.store.db.close()
            print(
                "HTTP integration passed: official PKCE/form login, JSON/SSE MCP, 404 session renewal, lost launch response, SQLite restart; one native task."
            )
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


if __name__ == "__main__":
    main()
