"""Consume a signed Yomi release: verify, preflight, activate, check readiness.

Publication and consumption are separate trust domains. CI builds a host's
closure at one commit and signs a small manifest naming it. This host trusts
only the pinned SSH signing key: not the transport, not the Git forge, and not
the cache beyond Nix's own substituter signatures. Nothing here builds.

A failed readiness check never rolls back. Activation may already have run
application migrations, and only a human can tell whether reverting is safe.
"""

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen

FORMAT = 1
NAMESPACE = "yomi-release"
PRINCIPAL = "yomi-release"
MAX_DOCUMENT = 4096
CLOCK_SKEW = 300
MAX_VALIDITY = 14 * 86400
FIELDS = {
    "format",
    "host",
    "commit",
    "toplevel",
    "narHash",
    "sequence",
    "issuedAt",
    "expiresAt",
}
# Every external step is bounded; the unit's TimeoutStartSec is the backstop.
TIMEOUT = {
    "fetch": 30,
    "verify": 10,
    "realise": 3600,
    "query": 60,
    "dry-activate": 300,
    "profile": 120,
    "switch": 1800,
    "readiness": 300,
}
NIX_BASE32 = "0123456789abcdfghijklmnpqrsvwxyz"

EXIT_FAILED = 1
EXIT_HELD = 3
EXIT_REJECTED = 4
EXIT_UNREADY = 5


class Rejected(Exception):
    """The published release must not be applied on this host."""


class Held(Exception):
    """A human has to act before any release is applied."""


class Failed(Exception):
    """A local step failed; the same release may be retried."""


def log(message):
    print(message, flush=True)


def run(command, step, **kwargs):
    try:
        return subprocess.run(
            [str(part) for part in command],
            check=True,
            timeout=TIMEOUT[step],
            **kwargs,
        )
    except subprocess.TimeoutExpired as error:
        raise Failed(f"{step} exceeded {TIMEOUT[step]}s") from error
    except (OSError, subprocess.CalledProcessError) as error:
        raise Failed(f"{step} failed: {error}") from error


def atomic_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(path.suffix + ".partial")
    with temporary.open("w") as handle:
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def read_json(path):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return None


# {{{ Publication contract
def fetch(url):
    if not url.startswith("https://"):
        raise Rejected(f"Refusing non-HTTPS release URL: {url}")
    try:
        with urlopen(url, timeout=TIMEOUT["fetch"]) as response:
            body = response.read(MAX_DOCUMENT + 1)
    except OSError as error:
        raise Failed(f"Cannot fetch {url}: {error}") from error
    if len(body) > MAX_DOCUMENT:
        raise Rejected(f"{url} exceeds {MAX_DOCUMENT} bytes")
    return body


def verify_signature(document, signature, allowed_signers):
    with tempfile.TemporaryDirectory(prefix="yomi-release-") as directory:
        path = Path(directory) / "release.json.sig"
        path.write_bytes(signature)
        result = subprocess.run(
            [
                "ssh-keygen",
                "-Y",
                "verify",
                "-f",
                str(allowed_signers),
                "-I",
                PRINCIPAL,
                "-n",
                NAMESPACE,
                "-s",
                str(path),
            ],
            input=document,
            capture_output=True,
            timeout=TIMEOUT["verify"],
        )
    if result.returncode != 0:
        raise Rejected("Release signature does not verify against the pinned key")


def integer(value):
    return isinstance(value, int) and not isinstance(value, bool)


def parse(document, host, store, now):
    """Return the manifest only if every field is exactly what this host accepts."""
    try:
        manifest = json.loads(document)
    except ValueError as error:
        raise Rejected("Release manifest is not JSON") from error
    if not isinstance(manifest, dict) or set(manifest) != FIELDS:
        raise Rejected(f"Release manifest must have exactly {sorted(FIELDS)}")
    if manifest["format"] != FORMAT or not integer(manifest["format"]):
        raise Rejected(f"Unsupported release format {manifest['format']!r}")
    if manifest["host"] != host:
        raise Rejected(f"Release is for {manifest['host']!r}, not {host!r}")
    if not isinstance(manifest["commit"], str) or not re.fullmatch(
        r"[0-9a-f]{40}", manifest["commit"]
    ):
        raise Rejected("Release commit must be a full lowercase SHA-1")
    toplevel = rf"{re.escape(store)}/[{NIX_BASE32}]{{32}}-nixos-system-{re.escape(host)}-[0-9A-Za-z._+-]+"
    if not isinstance(manifest["toplevel"], str) or not re.fullmatch(
        toplevel, manifest["toplevel"]
    ):
        raise Rejected("Release toplevel is not a NixOS system path for this host")
    if not isinstance(manifest["narHash"], str) or not re.fullmatch(
        rf"sha256:[{NIX_BASE32}]{{52}}", manifest["narHash"]
    ):
        raise Rejected("Release narHash must be `nix-store --query --hash` output")
    for key in ("sequence", "issuedAt", "expiresAt"):
        if not integer(manifest[key]) or manifest[key] < 1:
            raise Rejected(f"Release {key} must be a positive integer")
    if manifest["issuedAt"] > now + CLOCK_SKEW:
        raise Rejected("Release is issued in the future; check the clock")
    if manifest["expiresAt"] <= now:
        raise Rejected("Release has expired; CI must publish a fresh one")
    if not 0 < manifest["expiresAt"] - manifest["issuedAt"] <= MAX_VALIDITY:
        raise Rejected(f"Release validity exceeds {MAX_VALIDITY}s")
    return manifest


# }}}
# {{{ Local decision
def decide(manifest, digest, state, current):
    """Choose activate, readiness or nothing. Refuse replays and equivocation."""
    if state is None or manifest["sequence"] > state["sequence"]:
        return "activate"
    if manifest["sequence"] < state["sequence"]:
        raise Rejected(
            f"Release {manifest['sequence']} is older than accepted {state['sequence']}"
        )
    if digest != state["manifest"]:
        raise Rejected(
            f"Two different manifests claim sequence {manifest['sequence']}; investigate the publisher"
        )
    if current != manifest["toplevel"] and state["status"] == "ready":
        raise Held(
            "The running system differs from the last ready release, so someone "
            "switched by hand. Publish a newer release instead of fighting it."
        )
    # An interrupted switch may have moved /run/current-system already.
    if current != manifest["toplevel"] or state["status"] == "activating":
        return "activate"
    if state["status"] == "ready":
        return "nothing"
    return "readiness"


def check_hold(state_dir):
    hold = read_json(Path(state_dir) / "hold.json")
    if hold is not None:
        raise Held(
            f"Releases are held ({hold.get('reason', 'no reason given')}). "
            f"Clear with: yomi-release release-hold --confirm {hold.get('id')}"
        )


# }}}
# {{{ Activation
def preflight(config, manifest):
    toplevel = manifest["toplevel"]
    realise = [
        "nix-store",
        "--realise",
        toplevel,
        "--option",
        "max-jobs",
        "0",
        "--option",
        "builders",
        "",
        "--option",
        "require-sigs",
        "true",
    ]
    if config.get("substituter"):
        realise += ["--option", "extra-substituters", config["substituter"]]
    run(realise, "realise", stdout=subprocess.DEVNULL)
    nar = run(
        ["nix-store", "--query", "--hash", toplevel],
        "query",
        capture_output=True,
        text=True,
    ).stdout.strip()
    if nar != manifest["narHash"]:
        raise Rejected(f"Closure hash {nar} does not match the signed manifest")
    switch = Path(toplevel) / "bin/switch-to-configuration"
    if not os.access(switch, os.X_OK):
        raise Rejected("Release toplevel has no switch-to-configuration")
    run([switch, "dry-activate"], "dry-activate")


def activate(config, manifest):
    toplevel = manifest["toplevel"]
    run(["nix-env", "--profile", config["profile"], "--set", toplevel], "profile")
    run([Path(toplevel) / "bin/switch-to-configuration", "switch"], "switch")


def ready(config, manifest):
    """Run the new generation's own readiness checks, which match its services."""
    command = Path(manifest["toplevel"]) / "sw/bin/yomi-deployment-health"
    if not os.access(command, os.X_OK):
        command = config["readiness"]
    try:
        run([command], "readiness")
    except Failed as error:
        log(str(error))
        return False
    return True


def current_system(config):
    try:
        return os.path.realpath(config["currentSystem"], strict=True)
    except OSError:
        return None


@contextlib.contextmanager
def locked(state_dir):
    Path(state_dir).mkdir(mode=0o700, parents=True, exist_ok=True)
    with (Path(state_dir) / "lock").open("w") as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise Failed("Another release run holds the lock") from error
        yield


def apply(config, now=None, fetcher=fetch):
    state_dir = Path(config["stateDir"])
    with locked(state_dir):
        check_hold(state_dir)
        document = fetcher(config["manifestUrl"])
        signature = fetcher(config["signatureUrl"])
        verify_signature(document, signature, config["allowedSigners"])
        manifest = parse(
            document, config["host"], config["storeDir"], now or int(time.time())
        )
        digest = hashlib.sha256(document).hexdigest()
        state_path = state_dir / "state.json"
        state = read_json(state_path)
        action = decide(manifest, digest, state, current_system(config))
        label = f"release {manifest['sequence']} ({manifest['commit'][:12]})"
        if action == "nothing":
            log(f"{label} is already active and ready.")
            return 0
        record = {
            "sequence": manifest["sequence"],
            "manifest": digest,
            "commit": manifest["commit"],
            "toplevel": manifest["toplevel"],
        }

        def mark(status):
            atomic_json(state_path, record | {"status": status, "at": int(time.time())})

        if action == "activate":
            preflight(config, manifest)
            # From here on, no older sequence is accepted, even if switching fails.
            mark("activating")
            log(f"Activating {label}: {manifest['toplevel']}")
            activate(config, manifest)
            mark("activated")
        else:
            log(f"{label} is active but was not ready; checking readiness again.")
        if not ready(config, manifest):
            mark("unready")
            log(
                f"{label} is active but not ready. It stays active: no automatic "
                "rollback, because migrations may have run. Inspect, then fix forward "
                "or roll back by hand."
            )
            return EXIT_UNREADY
        mark("ready")
        log(f"{label} is active and ready.")
        return 0


# }}}
# {{{ Hold management
def place_hold(state_dir, reason):
    """Idempotent: an existing hold keeps its id and reason."""
    path = Path(state_dir) / "hold.json"
    existing = read_json(path)
    if existing is not None:
        return existing
    Path(state_dir).mkdir(mode=0o700, parents=True, exist_ok=True)
    hold = {
        "format": FORMAT,
        "id": secrets.token_hex(4),
        "reason": reason,
        "createdAt": int(time.time()),
    }
    atomic_json(path, hold)
    return hold


def release_hold(state_dir, confirm):
    path = Path(state_dir) / "hold.json"
    hold = read_json(path)
    if hold is None:
        log("No hold is set.")
        return 0
    if confirm != hold.get("id"):
        raise Held(f"Pass --confirm {hold.get('id')} to clear: {hold.get('reason')}")
    path.unlink()
    log("Hold cleared. The next run applies the newest signed release.")
    return 0


# }}}
def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--config", required=True)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("run", help="Apply the newest signed release")
    commands.add_parser("status", help="Show the accepted release and any hold")
    commands.add_parser("check-hold", help="Fail while releases are held")
    hold = commands.add_parser("hold", help="Stop applying releases")
    hold.add_argument("--reason", required=True)
    clear = commands.add_parser("release-hold", help="Clear a hold")
    clear.add_argument("--confirm", required=True)
    args = parser.parse_args(argv)
    config = json.loads(Path(args.config).read_text())
    state_dir = config["stateDir"]
    try:
        if args.command == "run":
            return apply(config)
        if args.command == "status":
            print(
                json.dumps(
                    {
                        "accepted": read_json(Path(state_dir) / "state.json"),
                        "hold": read_json(Path(state_dir) / "hold.json"),
                        "current": current_system(config),
                    },
                    indent=2,
                )
            )
            return 0
        if args.command == "check-hold":
            check_hold(state_dir)
            return 0
        if args.command == "hold":
            with locked(state_dir):
                log(json.dumps(place_hold(state_dir, args.reason)))
            return 0
        with locked(state_dir):
            return release_hold(state_dir, args.confirm)
    except Held as error:
        print(f"HELD: {error}", file=sys.stderr)
        return EXIT_HELD
    except Rejected as error:
        print(f"REJECTED: {error}", file=sys.stderr)
        return EXIT_REJECTED
    except Failed as error:
        print(f"FAILED: {error}", file=sys.stderr)
        return EXIT_FAILED


if __name__ == "__main__":
    sys.exit(main())
