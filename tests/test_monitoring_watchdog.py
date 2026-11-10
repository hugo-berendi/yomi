"""Monitoring watchdog: component faults, hysteresis, router fallback and heartbeat."""

import importlib.util
import json
import os
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPT = Path(
    os.environ.get(
        "MONITORING_WATCHDOG",
        Path(__file__).parents[1] / "hosts/nixos/inari/services/alerting/watchdog.py",
    )
)
spec = importlib.util.spec_from_file_location("watchdog", SCRIPT)
watchdog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watchdog)


class Fake(BaseHTTPRequestHandler):
    """One loopback server standing in for every component the watchdog asks."""

    world = {}
    calls = []

    def log_message(self, *args):
        pass

    def reply(self, status, body):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(status)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        Fake.calls.append(("GET", self.path, b""))
        w = Fake.world
        if self.path.startswith("/router/status"):
            return self.reply(*w.get("router_status", (200, {"ntfy": {"failing": 0}})))
        if self.path == "/ntfy/v1/health":
            return self.reply(200, {"healthy": w.get("ntfy_healthy", True)})
        if self.path == "/prom/-/ready":
            return self.reply(200, b"ready")
        if self.path.startswith("/prom/api/v1/query"):
            if "timestamp" in self.path:
                return self.reply(
                    200,
                    {
                        "status": "success",
                        "data": {"result": [{"value": [0, str(w.get("prom_age", 5))]}]},
                    },
                )
            return self.reply(
                200,
                {
                    "status": "success",
                    "data": {"result": [{"value": [0, str(w.get("targets", 6))]}]},
                },
            )
        if self.path == "/grafana/api/health":
            return self.reply(200, {"database": "ok"})
        if self.path == "/loki/ready":
            return self.reply(200, b"ready")
        if self.path.startswith("/loki/loki/api/v1/query"):
            lines = w.get("loki_lines", 120)
            return self.reply(
                200, {"data": {"result": [{"value": [0, str(lines)]}] if lines else []}}
            )
        if self.path == "/gatus/api/v1/endpoints/statuses":
            stamp = time.strftime(
                "%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - w.get("gatus_age", 30))
            )
            return self.reply(200, [{"name": "x", "results": [{"timestamp": stamp}]}])
        if self.path == "/n8n/healthz":
            return self.reply(*w.get("n8n", (200, {"status": "ok"})))
        if self.path == "/hermes/health":
            return self.reply(200, {"status": "ok"})
        if self.path == "/ping":
            return self.reply(200, b"OK")
        return self.reply(404, b"")

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        Fake.calls.append(("POST", self.path, body, dict(self.headers)))
        if self.path == "/router/alert":
            if Fake.world.get("router_down"):
                return self.reply(503, b"")
            return self.reply(200, {"sent": 0})
        return self.reply(200, b"OK")


class WatchdogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = HTTPServer(("127.0.0.1", 0), Fake)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        base = f"http://127.0.0.1:{cls.server.server_port}"
        cls.env = {
            "ALERT_ROUTER_URL": f"{base}/router/alert",
            "NTFY_URL": f"{base}/ntfy",
            "NTFY_TOPIC": "inari-alerts",
            "NTFY_TOKEN": "fixture",
            "PROMETHEUS_URL": f"{base}/prom",
            "GRAFANA_URL": f"{base}/grafana",
            "LOKI_URL": f"{base}/loki",
            "GATUS_URL": f"{base}/gatus",
            "N8N_URL": f"{base}/n8n",
            "HERMES_WEBHOOK_HEALTH": f"{base}/hermes/health",
            "EXPECTED_SYSTEM_TARGETS": "6",
        }
        cls.base = base

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        Fake.world = {}
        Fake.calls = []
        self.temp = tempfile.TemporaryDirectory()
        self.state = Path(self.temp.name) / "state.json"
        self.heartbeat = Path(self.temp.name) / "heartbeat-url"
        self.heartbeat.write_text(f"{self.base}/ping\n")
        self.saved = dict(os.environ)
        os.environ.update(self.env, HEARTBEAT_URL_FILE=str(self.heartbeat))

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self.saved)
        self.temp.cleanup()

    def run_once(self):
        Fake.calls = []
        watchdog.main(["--state", str(self.state)])
        posted = [
            json.loads(c[2])
            for c in Fake.calls
            if c[0] == "POST" and c[1] == "/router/alert"
        ]
        return posted[0] if posted else None

    def firing(self, alerts):
        return {a["service"]: a for a in alerts if not a.get("resolved")}

    def test_healthy_chain_resolves_and_pings(self):
        alerts = self.run_once()
        self.assertEqual(self.firing(alerts), {})
        self.assertTrue(
            all(a["host"] == "inari" and a["source"] == "watchdog" for a in alerts)
        )
        self.assertIn(("GET", "/ping", b""), Fake.calls, "success heartbeat")

    def test_silent_loki_is_a_fault_after_two_runs(self):
        Fake.world["loki_lines"] = 0
        self.assertEqual(self.firing(self.run_once()), {}, "one run is not an outage")
        firing = self.firing(self.run_once())
        self.assertIn("loki", firing)
        self.assertIn("keine Journalzeilen", firing["loki"]["message"])
        self.assertEqual(firing["loki"]["fingerprint"], "watchdog:loki")
        Fake.world["loki_lines"] = 50
        alerts = self.run_once()
        self.assertTrue(
            any(a["service"] == "loki" and a.get("resolved") for a in alerts),
            "all-clear sent",
        )

    def test_missing_and_stale_metrics(self):
        Fake.world.update(targets=4)
        self.run_once()
        self.assertIn("4 von 6", self.firing(self.run_once())["prometheus"]["message"])
        Fake.world.update(targets=6, prom_age=900)
        self.run_once()
        self.assertIn(
            "900 s alt", self.firing(self.run_once())["prometheus"]["message"]
        )

    def test_stalled_gatus_and_unreachable_n8n(self):
        Fake.world.update(gatus_age=1200, n8n=(500, {}))
        self.run_once()
        firing = self.firing(self.run_once())
        self.assertIn("seit 20 Minuten", firing["gatus"]["message"])
        self.assertEqual(firing["n8n"]["severity"], "critical")

    def test_router_down_falls_back_to_ntfy_once_and_fails_heartbeat(self):
        Fake.world["router_down"] = True
        self.run_once()
        self.run_once()
        direct = [
            c for c in Fake.calls if c[0] == "POST" and c[1] == "/ntfy/inari-alerts"
        ]
        self.assertEqual(len(direct), 1, "direct push after the second failed run")
        self.assertIn("Alarmrouter", direct[0][3]["Title"])
        failed = [c for c in Fake.calls if c[0] == "POST" and c[1] == "/ping/fail"]
        self.assertEqual(len(failed), 1, "heartbeat reports the broken push path")
        self.run_once()
        self.assertFalse(
            [c for c in Fake.calls if c[1] == "/ntfy/inari-alerts"],
            "no repeat within a day",
        )

    def test_unhealthy_ntfy_fails_heartbeat(self):
        Fake.world["ntfy_healthy"] = False
        self.run_once()
        self.assertTrue([c for c in Fake.calls if c[1] == "/ping/fail"])

    def test_no_heartbeat_configured(self):
        os.environ["HEARTBEAT_URL_FILE"] = ""
        self.run_once()
        self.assertFalse([c for c in Fake.calls if c[1].startswith("/ping")])


if __name__ == "__main__":
    unittest.main()
