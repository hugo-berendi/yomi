"""Run the checked-in diabetes workflow against an isolated local app and n8n DB."""

import json
import os
from pathlib import Path
import subprocess
import socket
import sys
import tempfile
import threading
import time

from flask import request
from werkzeug.serving import make_server

REPO = Path(__file__).resolve().parents[1]
SERVICE = REPO / "hosts/nixos/inari/services/diabetes"
WORKFLOW = REPO / "hosts/nixos/inari/services/n8n/workflows/diabetes-weekly.json"
if len(sys.argv) != 2:
    raise SystemExit("usage: n8n-diabetes.py /path/to/n8n")
N8N = sys.argv[1]
TOKEN = "synthetic-diabetes-integration-token"
ENCRYPTION_KEY = (
    "synthetic-diabetes-n8n-test-key-32bytes"  # gitleaks:allow (test fixture)
)

sys.path.insert(0, str(SERVICE))

with tempfile.TemporaryDirectory(prefix="n8n-diabetes-") as temporary:
    root = Path(temporary)
    app_root = root / "app-state"
    app_root.mkdir(mode=0o700)
    (app_root / "access-token").write_text(TOKEN)
    os.chmod(app_root / "access-token", 0o600)

    from app import create_app

    app = create_app(root=app_root)
    hits = []

    @app.after_request
    def record_weekly_call(response):
        if request.path == "/api/weekly-email":
            hits.append((response.status_code, response.get_json()))
        return response

    server = make_server("127.0.0.1", 0, app, threaded=True)
    port = server.server_port
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()

    # Internal task runners listen on a fixed default port. Pick an unused
    # loopback port so the isolated CLI cannot collide with the live n8n.
    with socket.socket() as broker_socket:
        broker_socket.bind(("127.0.0.1", 0))
        broker_port = broker_socket.getsockname()[1]

    n8n_root = root / "n8n"
    n8n_root.mkdir()
    workflow = json.loads(WORKFLOW.read_text())
    workflow["active"] = False
    workflow_path = root / "workflow.json"
    workflow_path.write_text(json.dumps(workflow))
    credential_path = root / "credential.json"
    credential_path.write_text(
        json.dumps(
            [
                {
                    "id": "CONFIGURE_DIABETES_ACCESS",
                    "name": "Diabetes service · Authorization",
                    "type": "httpHeaderAuth",
                    "data": {"name": "Authorization", "value": f"Bearer {TOKEN}"},
                }
            ]
        )
    )

    credentials_dir = root / "app-credentials"
    credentials_dir.mkdir(mode=0o700)
    (credentials_dir / "weekly-mail").write_text(
        json.dumps(
            {
                "host": "smtp.invalid",
                "port": 465,
                "implicit_tls": True,
                "sender": "sender@example.invalid",
                "recipient": "synthetic@example.invalid",
                "username": "synthetic-user",
                "password": "synthetic-password",
            }
        )
    )
    os.chmod(credentials_dir / "weekly-mail", 0o600)
    os.environ["CREDENTIALS_DIRECTORY"] = str(credentials_dir)
    env = os.environ.copy()
    env.update(
        {
            "N8N_USER_FOLDER": str(n8n_root),
            "DB_TYPE": "sqlite",
            "DB_SQLITE_DATABASE": str(n8n_root / "database.sqlite"),
            "N8N_ENCRYPTION_KEY": ENCRYPTION_KEY,
            "N8N_DIAGNOSTICS_ENABLED": "false",
            "N8N_VERSION_NOTIFICATIONS_ENABLED": "false",
            "N8N_TEMPLATES_ENABLED": "false",
            "N8N_RUNNERS_BROKER_PORT": str(broker_port),
            "N8N_RUNNERS_BROKER_LISTEN_ADDRESS": "127.0.0.1",
            "N8N_BLOCK_ENV_ACCESS_IN_NODE": "false",
            "DIABETES_URL": f"http://127.0.0.1:{port}",
            "WEEKLY_EMAIL_ENABLED": "false",
        }
    )

    def run_cli(*args):
        log = root / f"cli-{time.monotonic_ns()}.log"
        with log.open("w") as output:
            result = subprocess.run(
                [N8N, *args],
                env=env,
                stdout=output,
                stderr=subprocess.STDOUT,
                timeout=90,
                check=False,
            )
        if result.returncode:
            details = "\n".join(log.read_text(errors="replace").splitlines()[-20:])
            details = details.replace(TOKEN, "<redacted>").replace(
                "synthetic-password", "<redacted>"
            )
            raise RuntimeError(
                f"n8n {' '.join(args)} failed (exit {result.returncode}):\n{details}"
            )
        return log

    try:
        run_cli("import:workflow", f"--input={workflow_path}")
        run_cli("import:credentials", f"--input={credential_path}")
        execution_log = run_cli("execute", f"--id={workflow['id']}")
        if len(hits) != 1:
            raise AssertionError(
                f"expected one weekly endpoint hit, observed {len(hits)}; see {execution_log}"
            )
        if hits[0] != (200, {"status": "disabled"}):
            raise AssertionError(f"unexpected weekly endpoint response: {hits[0]!r}")
        output = execution_log.read_text(errors="replace")
        if (
            "Workflow execution finished" not in output
            and "Execution was successful" not in output
        ):
            raise AssertionError(
                f"n8n did not report successful execution; see {execution_log}"
            )

        # Exercise the enabled route using a fixed Monday-after-09:00 time and
        # a fake SMTP transport; the test cannot connect to a mail server.
        import weekly
        from analysis import BERLIN
        from datetime import datetime

        captured = []

        class FakeSMTP:
            def __init__(self, *_args, **_kwargs):
                pass

            def ehlo(self):
                pass

            def login(self, username, password):
                assert username == "synthetic-user"
                assert password == "synthetic-password"

            def send_message(self, message):
                captured.append(message)
                return {}

            def close(self):
                pass

        class FixedDatetime(datetime):
            @classmethod
            def now(cls, tz=None):
                fixed = cls(2026, 10, 26, 10, 0, tzinfo=BERLIN)
                return fixed.astimezone(tz) if tz else fixed

        weekly.smtplib.SMTP_SSL = FakeSMTP
        weekly.datetime = FixedDatetime
        os.environ["WEEKLY_EMAIL_ENABLED"] = "true"
        env["WEEKLY_EMAIL_ENABLED"] = "true"
        run_cli("execute", f"--id={workflow['id']}")
        run_cli("execute", f"--id={workflow['id']}")
        if hits[1:] != [
            (200, {"status": "submitted"}),
            (200, {"status": "submitted"}),
        ]:
            raise AssertionError(
                f"enabled endpoint responses were not submitted: {hits[1:]!r}"
            )
        if len(captured) != 1:
            raise AssertionError(
                f"expected one synthetic message across two requests; captured {len(captured)}"
            )
        if (
            not captured[0].is_multipart()
            or captured[0]["To"] != "synthetic@example.invalid"
        ):
            raise AssertionError(
                "captured message was not the expected synthetic multipart mail"
            )
    finally:
        server.shutdown()
        server_thread.join(timeout=5)

print(
    "n8n diabetes weekly workflow tested disabled and enabled paths; synthetic SMTP captured one mail across two submissions"
)
