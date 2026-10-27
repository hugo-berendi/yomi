"""A browser remote for the redroid screen, for devices that cannot run scrcpy.

Serves a refreshing screenshot and turns taps, drags, keys and typed text into
`adb shell input`. It is only started while a human is setting up a login, and
is reachable only where the firewall lets the port in (Tailscale).
"""

import argparse
import shlex
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

KEYS = {"back": "4", "home": "3", "enter": "66", "delete": "67", "tab": "61"}

PAGE = """<!doctype html>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>Immortal Rising</title>
<style>
  body{margin:0;background:#111;color:#eee;font:16px system-ui;text-align:center}
  img{max-width:100%;max-height:82vh;touch-action:none;-webkit-user-select:none;user-select:none}
  button,input{font:inherit;padding:.5em .8em;margin:.2em}
</style>
<img id=s alt="screen">
<div>
  <button onclick="key('back')">Back</button>
  <button onclick="key('home')">Home</button>
  <button onclick="key('delete')">Delete</button>
  <button onclick="key('enter')">Enter</button>
</div>
<form id=f><input id=t autocomplete=off autocapitalize=off autocorrect=off placeholder="type into the focused field"><button>Send</button></form>
<script>
const s = document.getElementById('s');
const post = (path) => fetch(path, {method: 'POST'});
const key = (name) => post('/key?name=' + name);
function refresh() { s.src = '/screen.png?' + Date.now(); }
s.onload = () => setTimeout(refresh, 400);
s.onerror = () => setTimeout(refresh, 2000);
refresh();
let down = null;
const point = (e) => {
  const r = s.getBoundingClientRect();
  return [Math.round((e.clientX - r.left) * s.naturalWidth / r.width),
          Math.round((e.clientY - r.top) * s.naturalHeight / r.height)];
};
s.onpointerdown = (e) => { down = point(e); };
s.onpointerup = (e) => {
  if (!down) return;
  const up = point(e);
  const moved = Math.hypot(up[0] - down[0], up[1] - down[1]) > 15;
  post(moved ? `/swipe?x1=${down[0]}&y1=${down[1]}&x2=${up[0]}&y2=${up[1]}` : `/tap?x=${up[0]}&y=${up[1]}`);
  down = null;
};
document.getElementById('f').onsubmit = (e) => {
  e.preventDefault();
  const box = document.getElementById('t');
  fetch('/text', {method: 'POST', body: box.value});
  box.value = '';
};
</script>
"""


class Handler(BaseHTTPRequestHandler):
    serial = ""
    lock = threading.Lock()

    def adb(self, *args):
        # One command at a time: concurrent screencaps and input events made the
        # emulator drop taps.
        with self.lock:
            return subprocess.run(
                ["adb", "-s", self.serial, *args], check=True, capture_output=True, timeout=30
            ).stdout

    def send(self, status, body=b"", kind="text/plain"):
        self.send_response(status)
        self.send_header("content-type", kind)
        self.send_header("cache-control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            self.send(200, PAGE.encode(), "text/html; charset=utf-8")
        elif path == "/screen.png":
            try:
                self.send(200, self.adb("exec-out", "screencap", "-p"), "image/png")
            except (subprocess.SubprocessError, OSError):
                self.send(503)
        else:
            self.send(404)

    def do_POST(self):
        url = urlparse(self.path)
        query = {k: v[0] for k, v in parse_qs(url.query).items()}
        try:
            if url.path == "/tap":
                self.adb("shell", "input", "tap", str(int(query["x"])), str(int(query["y"])))
            elif url.path == "/swipe":
                coords = [str(int(query[k])) for k in ("x1", "y1", "x2", "y2")]
                self.adb("shell", "input", "swipe", *coords, "300")
            elif url.path == "/key":
                self.adb("shell", "input", "keyevent", KEYS[query["name"]])
            elif url.path == "/text":
                length = min(int(self.headers.get("content-length", 0)), 1024)
                text = self.rfile.read(length).decode().replace(" ", "%s")
                # The string is parsed by the device's shell, so quote it there.
                self.adb("shell", "input", "text", shlex.quote(text))
            else:
                return self.send(404)
        except (KeyError, ValueError, subprocess.SubprocessError, OSError):
            return self.send(400)
        self.send(204)

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--serial", required=True)
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    Handler.serial = args.serial
    subprocess.run(["adb", "connect", args.serial], check=False, capture_output=True)
    ThreadingHTTPServer(("0.0.0.0", args.port), Handler).serve_forever()


main()
