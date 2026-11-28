"""Export the read-only Beszel system summary to Prometheus."""

import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import urlopen

GAUGES = {
    "cpu": "beszel_cpu_percent",
    "mp": "beszel_memory_percent",
    "dp": "beszel_disk_percent",
}


def metrics(base):
    with urlopen(
        f"{base}/api/collections/systems/records?perPage=100", timeout=5
    ) as response:
        page = json.load(response)
    for system in page["items"]:
        label = json.dumps(system["name"], ensure_ascii=False)
        online = system["status"] == "up"
        yield f"beszel_system_up{{host={label}}} {int(online)}"
        if online:
            for field, name in GAUGES.items():
                value = system["info"].get(field)
                if type(value) in {int, float}:
                    yield f"{name}{{host={label}}} {value}"


def serve(beszel_port, metrics_port):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/metrics":
                self.send_error(404)
                return
            try:
                payload = "\n".join(metrics(f"http://127.0.0.1:{beszel_port}"))
            except (OSError, KeyError, ValueError, TypeError):
                self.send_error(503, "Beszel metrics unavailable")
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.end_headers()
            self.wfile.write((payload + "\n").encode())

        def log_message(self, *_args):
            pass

    with HTTPServer(("127.0.0.1", int(metrics_port)), Handler) as server:
        server.serve_forever()


if __name__ == "__main__":
    serve(*sys.argv[1:])
