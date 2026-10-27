"""Drive Immortal Rising through adb by matching template screenshots.

The game renders to a canvas, so there is no UI tree to query. Templates are
cropped from `immortal-rising shot` captures at the container's fixed
resolution, which is why matches stay stable between runs.

Exit codes: 0 done, 1 flow failed, 3 flow.json missing or incomplete.
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

    def launch(self):
        self.adb("shell", "monkey", "-p", self.package, "-c", "android.intent.category.LAUNCHER", "1")

    def ensure_home(self, flow, timeout):
        """Reach the main screen, tapping through pop-ups and a kicked session."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            screen = self.screen()
            if self.find(screen, flow["home"]):
                return
            # Login before dismiss: after another device signs in, the "logged
            # out" dialog and the login button can be on screen together.
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
                self.tap(point)
                time.sleep(step.get("wait", 1.5))
                return
            time.sleep(1)
        if not step.get("optional"):
            raise TimeoutError(f"{step['image']} never appeared")

    def save_screen(self, name):
        path = self.workdir / name
        cv2.imwrite(str(path), self.screen())
        return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["run", "shot"])
    parser.add_argument("--serial", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--workdir", required=True)
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
        agent.launch()
        agent.ensure_home(flow, flow.get("loginTimeout", 240))
        for step in flow.get("routine", []):
            agent.step(step)
            # A reward can open a pop-up that covers the next button.
            agent.ensure_home(flow, 60)
    except (TimeoutError, FileNotFoundError, subprocess.CalledProcessError) as error:
        print(f"flow failed: {error}", file=sys.stderr)
        agent.save_screen("last-failure.png")
        return 1
    return 0


sys.exit(main())
