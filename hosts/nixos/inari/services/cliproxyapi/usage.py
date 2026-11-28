"""Expose CLIProxyAPI usage counters without exposing its management API."""

import json
import re
import sys
from collections import Counter
from datetime import datetime
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from threading import Thread
from time import sleep
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
    "input_tokens": "cliproxyapi_input_tokens_total",
    "output_tokens": "cliproxyapi_output_tokens_total",
    "cached_tokens": "cliproxyapi_cached_tokens_total",
}


QUOTA_URLS = {
    "claude": "https://api.anthropic.com/api/oauth/usage",
    "codex": "https://chatgpt.com/backend-api/wham/usage",
}
CLAUDE_WINDOWS = {
    "five_hour": "5h",
    "seven_day": "7d",
    "seven_day_sonnet": "7d-sonnet",
    "seven_day_opus": "7d-opus",
}
WINDOW_SECONDS = {18000: "5h", 604800: "7d"}
DATA_ERRORS = (OSError, ValueError, TypeError, KeyError, AttributeError)


def account_name(credential):
    return ACCOUNTS.get((credential["type"], int(credential.get("priority") or 0)))


def quota_windows(provider, payload):
    if provider == "claude":
        for field, label in CLAUDE_WINDOWS.items():
            if window := payload.get(field):
                reset = window.get("resets_at")
                yield (
                    label,
                    window.get("utilization"),
                    (datetime.fromisoformat(reset).timestamp() if reset else None),
                )
    else:
        for window in (payload.get("rate_limit") or {}).values():
            if isinstance(window, dict) and (
                label := WINDOW_SECONDS.get(window.get("limit_window_seconds"))
            ):
                yield label, window.get("used_percent"), window.get("reset_at")


def quota_metrics(fetch, credentials):
    for credential in credentials:
        try:
            if not (account := account_name(credential)) or credential.get("disabled"):
                continue
            provider = credential["type"]
            response = fetch(
                "api-call",
                {
                    "auth_index": credential["auth_index"],
                    "method": "GET",
                    "url": QUOTA_URLS[provider],
                    "header": {
                        "Authorization": "Bearer $TOKEN$",
                        **(
                            {"anthropic-beta": "oauth-2025-04-20"}
                            if provider == "claude"
                            else {}
                        ),
                    },
                },
            )
            if response["status_code"] != 200:
                continue
            payload = json.loads(response["body"])
            for window, used, reset in quota_windows(provider, payload):
                labels = f'account="{account}",window="{window}"'
                if type(used) in (int, float) and 0 <= used <= 100:
                    yield f"cliproxyapi_quota_used_percent{{{labels}}} {used}"
                if type(reset) in (int, float) and reset > 0:
                    yield f"cliproxyapi_quota_reset_timestamp_seconds{{{labels}}} {reset}"
            if provider == "claude":
                spend = (payload.get("spend") or {}).get("used") or {}
                currency = spend.get("currency")
                amount = spend.get("amount_minor")
                exponent = spend.get("exponent")
                if (
                    isinstance(currency, str)
                    and re.fullmatch(r"[A-Z]{3}", currency)
                    and type(amount) is int
                    and amount >= 0
                    and type(exponent) is int
                    and 0 <= exponent <= 6
                ):
                    cost = Decimal(amount).scaleb(-exponent)
                    yield f'cliproxyapi_extra_spend{{account="{account}",currency="{currency}"}} {cost}'
        except DATA_ERRORS:
            continue


class Usage:
    def __init__(self):
        self.counts = {account: Counter() for account in ACCOUNTS.values()}

    def update(self, credentials, events):
        accounts = {
            item["auth_index"]: account_name(item)
            for item in credentials
            if item.get("auth_index") and item["type"] in {"claude", "codex"}
        }
        for event in events:
            if account := accounts.get(event.get("auth_index")):
                counts = self.counts[account]
                counts["requests"] += 1
                counts["failures"] += bool(event.get("failed"))
                tokens = event.get("tokens", {})
                counts["tokens"] += tokens.get("total_tokens", 0)
                for field in ("input_tokens", "output_tokens", "cached_tokens"):
                    counts[field] += tokens.get(field, 0)

    def metrics(self):
        for kind, metric in COUNTERS.items():
            yield f"# TYPE {metric} counter"
            for account, counts in self.counts.items():
                yield f'{metric}{{account="{account}"}} {counts[kind]}'


def serve(proxy_port, metrics_port, key_path):
    usage = Usage()

    quotas = ()

    def fetch(path, payload=None):
        key = Path(key_path).read_text().strip()
        request = Request(
            f"http://127.0.0.1:{proxy_port}/v0/management/{path}",
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            data=None if payload is None else json.dumps(payload).encode(),
        )
        with urlopen(request, timeout=3) as response:
            return json.load(response)

    def refresh_quotas():
        nonlocal quotas
        while True:
            try:
                quotas = tuple(quota_metrics(fetch, fetch("auth-files")["files"]))
            except DATA_ERRORS:
                quotas = ()
            sleep(300)

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
            self.wfile.write(("\n".join((*usage.metrics(), *quotas)) + "\n").encode())

        def log_message(self, *_args):
            pass

    with HTTPServer(("127.0.0.1", int(metrics_port)), Handler) as server:
        Thread(target=refresh_quotas, daemon=True).start()
        server.serve_forever()


if __name__ == "__main__":
    serve(*sys.argv[1:])
