"""Drive Immortal Rising through adb by matching template screenshots.

The game renders to a canvas, so there is no UI tree to query. Templates are
cropped from `immortal-rising shot` captures at the container's fixed
resolution, which is why matches stay stable between runs.

flow.json, next to a templates/ directory of PNGs:

    {
      "home": "home.png",                  # visible only on the main screen
      "login": ["fb_continue.png"],        # buttons that sign back in
      "dismiss": ["close.png"],            # pop-ups to tap away
      "kicked": "logged_out.png",          # shown when another device signed in
      "reloginGraceMinutes": 180,
      "routines": {
        "daily":    [{"image": "quest.png"}, {"image": "claim.png", "optional": true, "repeat": 3}],
        "periodic": []                     # missing or empty only keeps the session alive
      }
    }

A step accepts timeout (s, default 15), wait (s after the tap, default 1.5),
optional and repeat.

Exit codes: 0 done, 1 flow failed, 3 flow.json missing or incomplete, 4 deferred
(the account is signed in elsewhere and the grace period has not elapsed).
"""

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

import cv2
import numpy as np

THRESHOLD = 0.88


class Deferred(Exception):
    pass


class Agent:
    def __init__(self, serial, package, workdir):
        self.serial = serial
        self.package = package
        self.workdir = Path(workdir)
        self.templates = {}

    def adb(self, *args):
        return subprocess.run(
            ["adb", "-s", self.serial, *args], check=True, capture_output=True
        ).stdout

    def screen(self):
        png = self.adb("exec-out", "screencap", "-p")
        return cv2.imdecode(np.frombuffer(png, np.uint8), cv2.IMREAD_COLOR)

    def template(self, name):
        if name not in self.templates:
            image = cv2.imread(str(self.workdir / "templates" / name))
            if image is None:
                raise FileNotFoundError(f"template {name} is missing")
            self.templates[name] = image
        return self.templates[name]

    def find(self, screen, name):
        tpl = self.template(name)
        scores = cv2.matchTemplate(screen, tpl, cv2.TM_CCOEFF_NORMED)
        _, best, _, loc = cv2.minMaxLoc(scores)
        if best < THRESHOLD:
            return None
        height, width = tpl.shape[:2]
        return loc[0] + width // 2, loc[1] + height // 2

    def tap(self, point):
        self.adb("shell", "input", "tap", str(point[0]), str(point[1]))

    def in_foreground(self):
        focus = self.adb("shell", "dumpsys", "window").decode(errors="replace")
        return any(self.package in line for line in focus.splitlines() if "mCurrentFocus" in line)

    def launch(self):
        self.adb("shell", "monkey", "-p", self.package, "-c", "android.intent.category.LAUNCHER", "1")

    def kicked_since(self, flow, screen):
        """Seconds the account has been signed in elsewhere, or None."""
        marker = self.workdir / "kicked-since"
        if not flow.get("kicked") or not self.find(screen, flow["kicked"]):
            return None
        if not marker.exists():
            marker.write_text(str(time.time()))
        return time.time() - float(marker.read_text())

    def ensure_home(self, flow, timeout):
        """Reach the main screen, tapping through pop-ups and a kicked session."""
        grace = flow.get("reloginGraceMinutes", 180) * 60
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            screen = self.screen()
            if self.find(screen, flow["home"]):
                (self.workdir / "kicked-since").unlink(missing_ok=True)
                return
            elapsed = self.kicked_since(flow, screen)
            # Signing in again signs the owner's phone out, so wait out a grace
            # period after another device took the session.
            if elapsed is not None and elapsed < grace:
                raise Deferred(f"signed in elsewhere for {int(elapsed // 60)} min")
            # Login before dismiss: the "logged out" dialog and the login
            # button can be on screen together.
            for name in flow.get("login", []) + flow.get("dismiss", []):
                point = self.find(screen, name)
                if point:
                    self.tap(point)
                    break
            time.sleep(2)
        raise TimeoutError("never reached the home screen")

    def step(self, step):
        deadline = time.monotonic() + step.get("timeout", 15)
        while time.monotonic() < deadline:
            point = self.find(self.screen(), step["image"])
            if point:
                for _ in range(step.get("repeat", 1)):
                    self.tap(point)
                    time.sleep(step.get("wait", 1.5))
                return
            time.sleep(1)
        if not step.get("optional"):
            raise TimeoutError(f"{step['image']} never appeared")

    def save_screen(self, name):
        path = self.workdir / name
        path.parent.mkdir(exist_ok=True)
        cv2.imwrite(str(path), self.screen())
        return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["run", "shot"])
    parser.add_argument("--serial", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--workdir", required=True)
    parser.add_argument("--routine", default="periodic")
    args = parser.parse_args()
    agent = Agent(args.serial, args.package, args.workdir)

    if args.command == "shot":
        print(agent.save_screen("shots/" + time.strftime("%Y%m%d-%H%M%S") + ".png"))
        return 0

    try:
        flow = json.loads((agent.workdir / "flow.json").read_text())
        flow["home"]
    except (OSError, KeyError, json.JSONDecodeError) as error:
        print(f"flow.json is missing or incomplete: {error!r}", file=sys.stderr)
        return 3

    try:
        if not agent.in_foreground():
            agent.launch()
        agent.ensure_home(flow, flow.get("loginTimeout", 240))
        for step in flow.get("routines", {}).get(args.routine, []):
            agent.step(step)
            # A reward can open a pop-up that covers the next button.
            agent.ensure_home(flow, 60)
    except Deferred as reason:
        print(f"deferred: {reason}")
        return 4
    except (TimeoutError, FileNotFoundError, subprocess.CalledProcessError) as error:
        print(f"flow failed: {error}", file=sys.stderr)
        agent.save_screen("last-failure.png")
        return 1
    return 0


sys.exit(main())
