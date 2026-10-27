"""Exercise real n8n HTTP branches and paired items against a synthetic DAV server."""

import copy
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPO = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2:
    raise SystemExit("usage: n8n-webuntis.py /path/to/n8n")
N8N = sys.argv[1]
source = json.loads(
    (
        REPO / "hosts/nixos/inari/services/n8n/workflows/webuntis-radicale.json"
    ).read_text()
)
requests = []


class Server(BaseHTTPRequestHandler):
    def do_PUT(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        requests.append(("PUT", self.path))
        assert self.headers.get("Authorization") == "Basic dGVzdDp0ZXN0"
        self.send_response(201 if self.path.endswith("new-a") else 204)
        self.end_headers()

    def do_DELETE(self):
        requests.append(("DELETE", self.path))
        assert self.headers.get("Authorization") == "Basic dGVzdDp0ZXN0"
        self.send_response(404)
        self.end_headers()

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Server)
threading.Thread(target=server.serve_forever, daemon=True).start()
port = server.server_port
with tempfile.TemporaryDirectory(prefix="yomi-webuntis-runtime-") as temporary:
    root = Path(temporary)
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        broker = sock.getsockname()[1]
    names = [
        "Manuell testen",
        "PUT oder DELETE?",
        "Termin in Radicale schreiben",
        "Termin aus Radicale löschen",
        "Sync-Status festschreiben",
    ]
    nodes = [copy.deepcopy(n) for n in source["nodes"] if n["name"] in names]
    operations = []
    planned = {
        "keep": {"hash": "keep"},
        "new-a": {"hash": "a"},
        "new-b": {"hash": "b"},
        "unacknowledged": {"hash": "must-not-appear"},
    }
    for method, href in [("DELETE", "old"), ("PUT", "new-a"), ("PUT", "new-b")]:
        operations.append(
            {
                "json": {
                    "method": method,
                    "href": href,
                    "url": f"http://127.0.0.1:{port}/{href}",
                    "body": "SUMMARY:synthetic\r\n",
                    "summary": {},
                    "nextState": planned,
                }
            }
        )
    planner = {
        "id": "fixture-planner",
        "name": "Persönliche Termine vorbereiten",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [0, 0],
        "parameters": {
            "jsCode": "$getWorkflowStaticData('global').hashByHref={old:{hash:'old'},keep:{hash:'keep'}}; return "
            + json.dumps(operations)
            + ";"
        },
    }
    verify = {
        "id": "fixture-verify",
        "name": "Verify paired items",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [0, 0],
        "parameters": {
            "jsCode": "const s=$getWorkflowStaticData('global').hashByHref;if(s.unacknowledged)throw Error('Unacknowledged state committed');const complete=!!s['new-a']&&!!s['new-b']&&!s.old&&!!s.keep;return [{json:{pairedItemVerified:complete}}];"
        },
    }
    for n in nodes:
        if n["type"] == "n8n-nodes-base.httpRequest":
            n["credentials"] = {
                "httpBasicAuth": {
                    "id": "synthetic-radicale",
                    "name": "Synthetic Radicale",
                }
            }

    def edge(name):
        return {"main": [[{"node": name, "type": "main", "index": 0}]]}

    connections = {
        "Manuell testen": edge(planner["name"]),
        planner["name"]: edge("PUT oder DELETE?"),
        "PUT oder DELETE?": copy.deepcopy(source["connections"]["PUT oder DELETE?"]),
        "Termin in Radicale schreiben": edge("Sync-Status festschreiben"),
        "Termin aus Radicale löschen": edge("Sync-Status festschreiben"),
        "Sync-Status festschreiben": edge(verify["name"]),
    }
    workflow = {
        "id": "YomiWebUntisRuntime",
        "name": "Synthetic WebUntis runtime",
        "active": False,
        "nodes": nodes + [planner, verify],
        "connections": connections,
        "nodeGroups": [],
        "settings": {"executionOrder": "v1", "timezone": "Europe/Berlin"},
    }
    wf = root / "workflow.json"
    wf.write_text(json.dumps(workflow))
    cred = root / "credentials.json"
    cred.write_text(
        json.dumps(
            [
                {
                    "id": "synthetic-radicale",
                    "name": "Synthetic Radicale",
                    "type": "httpBasicAuth",
                    "data": {"user": "test", "password": "test"},
                }
            ]
        )
    )
    env = os.environ | {
        "N8N_USER_FOLDER": str(root),
        "DB_TYPE": "sqlite",
        "DB_SQLITE_DATABASE": str(root / "database.sqlite"),
        "N8N_ENCRYPTION_KEY": "synthetic-only-32-byte-webuntis-key",
        "N8N_DIAGNOSTICS_ENABLED": "false",
        "N8N_VERSION_NOTIFICATIONS_ENABLED": "false",
        "N8N_TEMPLATES_ENABLED": "false",
        "N8N_RUNNERS_BROKER_PORT": str(broker),
        "N8N_RUNNERS_BROKER_LISTEN_ADDRESS": "127.0.0.1",
    }

    def cli(*args):
        result = subprocess.run(
            [N8N, *args],
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=120,
        )
        if result.returncode:
            raise RuntimeError(result.stdout[-4000:])
        return result.stdout

    cli("import:workflow", "--input=" + str(wf))
    cli("import:credentials", "--input=" + str(cred))
    output = cli("execute", "--id=" + workflow["id"])
    if '"pairedItemVerified": true' not in output:
        raise AssertionError(output[-6000:])
    assert sorted(requests) == [
        ("DELETE", "/old"),
        ("PUT", "/new-a"),
        ("PUT", "/new-b"),
    ], requests
    print(
        "Installed n8n runtime passed: interleaved PUT/DELETE branches, HTTP201/204/404, real paired-item lookup, exact acknowledged state."
    )
server.shutdown()
