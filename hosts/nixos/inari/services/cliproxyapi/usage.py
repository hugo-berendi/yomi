"""Expose CLIProxyAPI usage counters without exposing its management API."""

import json
import sys
from collections import Counter
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

ACCOUNTS = {
    ("claude", 10): "Claude Stamm Phoenix",
    ("claude", 0): "Claude Work",
    ("codex", 10): "ChatGPT Stamm Phoenix",
    ("codex", 0): "ChatGPT Personal",
}
COUNTERS = {
    "requests": "cliproxyapi_requests_total",
    "failures": "cliproxyapi_failures_total",
    "tokens": "cliproxyapi_tokens_total",
}


class Usage:
    def __init__(self):
        self.counts = {account: Counter() for account in ACCOUNTS.values()}

    def update(self, credentials, events):
        accounts = {
            item["auth_index"]: ACCOUNTS.get(
                (item["type"], int(item.get("priority") or 0))
            )
            for item in credentials
            if item.get("auth_index") and item["type"] in {"claude", "codex"}
        }
        for event in events:
            if account := accounts.get(event.get("auth_index")):
                counts = self.counts[account]
                counts["requests"] += 1
                counts["failures"] += bool(event.get("failed"))
                counts["tokens"] += event.get("tokens", {}).get("total_tokens", 0)

    def metrics(self):
        for kind, metric in COUNTERS.items():
            yield f"# TYPE {metric} counter"
            for account, counts in self.counts.items():
                yield f'{metric}{{account="{account}"}} {counts[kind]}'


def serve(proxy_port, metrics_port, key_path):
    usage = Usage()

    def fetch(path):
        key = Path(key_path).read_text().strip()
        request = Request(
            f"http://127.0.0.1:{proxy_port}/v0/management/{path}",
            headers={"Authorization": f"Bearer {key}"},
        )
        with urlopen(request, timeout=3) as response:
            return json.load(response)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/metrics":
                self.send_error(404)
                return

            try:
                credentials = fetch("auth-files")["files"]
                events = fetch("usage-queue?count=10000")
                usage.update(credentials, events)
            except (OSError, ValueError, TypeError, KeyError):
                self.send_error(503, "CLIProxyAPI usage unavailable")
                return

            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.end_headers()
            self.wfile.write(("\n".join(usage.metrics()) + "\n").encode())

        def log_message(self, *_args):
            pass

    with HTTPServer(("127.0.0.1", int(metrics_port)), Handler) as server:
        server.serve_forever()


if __name__ == "__main__":
    serve(*sys.argv[1:])
