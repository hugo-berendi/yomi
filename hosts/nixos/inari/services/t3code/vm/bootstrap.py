import argparse
import json
import os
import shlex
import shutil
import socket
import time
import subprocess
import tempfile
from pathlib import Path

PHASE = "initialization"


def ssh_args(key, known_hosts, command):
    return [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=10",
        "-o",
        f"UserKnownHostsFile={known_hosts}",
        "-o",
        "StrictHostKeyChecking=yes",
        "-i",
        str(key),
        "--",
        "agent@10.231.0.2",
        shlex.join(command),
    ]


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, sort_keys=True)
        handle.write("\n")
        temporary = Path(handle.name)
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)


def credential_pairs(source_files, home="/home/agent"):
    pairs = []
    for source in source_files:
        source = Path(home) / source[2:] if source.startswith("~/") else Path(source)
        if not source.is_file():
            continue
        try:
            relative = source.relative_to(home)
        except ValueError:
            relative = Path(source.name)
        pairs.append((source, Path("/home/agent") / relative))
    return pairs


def install_file(key, known_hosts, source, destination):
    remote = ["install", "-D", "-m", "600", "/dev/stdin", str(destination)]
    with source.open("rb") as handle:
        subprocess.run(ssh_args(key, known_hosts, remote), stdin=handle, check=True)


def run_remote(key, known_hosts, command, *, input=None, check=True):
    return subprocess.run(
        ssh_args(key, known_hosts, command),
        input=input,
        text=True,
        capture_output=True,
        check=check,
    )


def wait_cloud_init(key, known_hosts):
    result = run_remote(
        key,
        known_hosts,
        ["sudo", "cloud-init", "status", "--wait", "--format", "json"],
        check=False,
    )
    if result.returncode != 0:
        status = json.loads(result.stdout)
        errors = status.get("errors", [])
        # Cloud-init retains historical errors after a successful module retry.
        # Recover only our original Noble package-name mistake; other failures
        # must still stop bootstrap rather than being hidden by readiness checks.
        if not (
            status.get("status") == "error"
            and len(errors) == 1
            and "PackageInstallerError" in errors[0]
            and "{'libatk-bridge2.0-0'}" in errors[0]
        ):
            raise RuntimeError("Cloud-init did not complete successfully")
        run_remote(
            key,
            known_hosts,
            ["sudo", "apt-get", "install", "-y", "libatk-bridge2.0-0t64"],
        )
        print(
            "Recovered legacy Noble package error; cloud-init retains its historical error",
            flush=True,
        )
    # Noble's package post-install starts the daemon before the socket. Starting
    # the socket while that daemon runs fails, so converge on socket activation.
    active = run_remote(
        key,
        known_hosts,
        ["systemctl", "is-active", "--quiet", "nix-daemon.socket"],
        check=False,
    )
    if active.returncode != 0:
        run_remote(
            key, known_hosts, ["sudo", "systemctl", "stop", "nix-daemon.service"]
        )
        run_remote(
            key, known_hosts, ["sudo", "systemctl", "reset-failed", "nix-daemon.socket"]
        )
        run_remote(
            key,
            known_hosts,
            ["sudo", "systemctl", "enable", "--now", "nix-daemon.socket"],
        )
    run_remote(
        key, known_hosts, ["systemctl", "is-active", "--quiet", "nix-daemon.socket"]
    )


def install_tools(key, known_hosts, package):
    current = run_remote(
        key, known_hosts, ["readlink", "-f", "/opt/t3code-tools"], check=False
    )
    if current.returncode == 0 and current.stdout.strip() == package:
        run_remote(
            key,
            known_hosts,
            ["sudo", "ln", "-sfn", package, "/nix/var/nix/gcroots/t3code-tools"],
        )
        return False
    closure = subprocess.check_output(["nix-store", "-qR", package], text=True)
    export = subprocess.Popen(
        ["nix-store", "--export", *closure.splitlines()], stdout=subprocess.PIPE
    )
    try:
        subprocess.run(
            ssh_args(key, known_hosts, ["sudo", "nix-store", "--import"]),
            stdin=export.stdout,
            check=True,
        )
    finally:
        export.stdout.close()
        if export.wait() != 0:
            raise RuntimeError("Nix closure export failed")
    current = run_remote(
        key, known_hosts, ["readlink", "-f", "/opt/t3code-tools"], check=False
    )
    if current.returncode == 0 and current.stdout.strip() == package:
        return False
    run_remote(key, known_hosts, ["sudo", "ln", "-sfn", package, "/opt/t3code-tools"])
    run_remote(
        key,
        known_hosts,
        ["sudo", "ln", "-sfn", package, "/nix/var/nix/gcroots/t3code-tools"],
    )
    return True


def state_for_link(state, listed):
    if not state.get("linked"):
        return state
    environment_id = state.get("environmentId")
    if any(link.get("environmentId") == environment_id for link in listed):
        return state
    return {**state, "revoked": True, "linked": False}


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--key", type=Path, required=True)
    parser.add_argument("--known-hosts", type=Path, required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--rpc", type=Path, required=True)
    parser.add_argument("--pilot", required=True)
    parser.add_argument("--local-url", default="http://127.0.0.1:3773")
    parser.add_argument("--peer-url", default="http://127.0.0.1:8511")
    parser.add_argument("--credential-home", default="/home/agent")
    parser.add_argument("--provider-instances", default="")
    parser.add_argument("--credentials", action="append", default=[])
    return parser.parse_args()


def main():
    global PHASE
    args = parse_args()
    state = json.loads(args.state.read_text()) if args.state.exists() else {}
    connection = Path(args.credential_home) / ".local/state/t3code-vm"
    connection.mkdir(parents=True, exist_ok=True, mode=0o700)
    for source, name in [(args.key, "ssh_key"), (args.known_hosts, "known_hosts")]:
        temporary = connection / (name + ".new")
        shutil.copyfile(source, temporary)
        temporary.chmod(0o600)
        os.replace(temporary, connection / name)
    PHASE = "guest-ssh"
    for attempt in range(90):
        ready = run_remote(args.key, args.known_hosts, ["true"], check=False)
        if ready.returncode == 0:
            break
        time.sleep(5)
    else:
        raise RuntimeError("Guest SSH did not become ready")
    PHASE = "cloud-init"
    wait_cloud_init(args.key, args.known_hosts)
    PHASE = "tooling-import"
    tools_changed = install_tools(args.key, args.known_hosts, args.package)
    run_remote(args.key, args.known_hosts, ["/opt/t3code-tools/bin/t3", "--version"])
    from guest_setup import configure_guest

    PHASE = "guest-service"
    configure_guest(args.key, args.known_hosts, tools_changed)
    for attempt in range(60):
        try:
            with socket.create_connection(("10.231.0.2", 3773), timeout=2):
                break
        except OSError:
            time.sleep(2)
    else:
        raise RuntimeError("Guest T3 did not start")

    PHASE = "credential-seeding"
    for source, destination in credential_pairs(args.credentials, args.credential_home):
        exists = run_remote(
            args.key, args.known_hosts, ["test", "-s", str(destination)], check=False
        )
        if exists.returncode != 0:
            install_file(args.key, args.known_hosts, source, destination)
    PHASE = "provider-configuration"
    if args.provider_instances:
        guest_token = run_remote(
            args.key,
            args.known_hosts,
            [
                "/opt/t3code-tools/bin/t3",
                "auth",
                "session",
                "issue",
                "--token-only",
                "--ttl",
                "5m",
                "--scope",
                "settings:write",
                "--scope",
                "providers:manage",
            ],
        ).stdout.strip()
        call_rpc(
            args,
            guest_token,
            "server.updateSettings",
            {"patch": {"providerInstances": json.loads(args.provider_instances)}},
            base_url="http://10.231.0.2:3773",
        )

    PHASE = "host-auth"
    token = subprocess.check_output(
        [
            "t3",
            "auth",
            "session",
            "issue",
            "--token-only",
            "--ttl",
            "5m",
            "--scope",
            "access:write",
            "--scope",
            "access:read",
            "--scope",
            "settings:write",
        ],
        text=True,
    ).strip()
    listed = json.loads(call_rpc(args, token, "peerLinks.list", {}))
    state = state_for_link(state, listed.get("links", []))
    if state.get("revoked"):
        atomic_json(args.state, state)
        return
    if state.get("linked"):
        return
    PHASE = "environment-linking"
    call_rpc(
        args,
        token,
        "server.updateSettings",
        {"patch": {"linkedEnvironmentsEnabled": True}},
    )
    guest_token = run_remote(
        args.key,
        args.known_hosts,
        [
            "/opt/t3code-tools/bin/t3",
            "auth",
            "session",
            "issue",
            "--token-only",
            "--ttl",
            "5m",
            "--scope",
            "settings:write",
        ],
    ).stdout.strip()
    call_rpc(
        args,
        guest_token,
        "server.updateSettings",
        {"patch": {"linkedEnvironmentsEnabled": True}},
        base_url="http://10.231.0.2:3773",
    )
    pairing = run_remote(
        args.key,
        args.known_hosts,
        [
            "/opt/t3code-tools/bin/t3",
            "auth",
            "pairing",
            "create",
            "--json",
            "--ttl",
            "5m",
        ],
    )
    credential = json.loads(pairing.stdout)["credential"]
    linked = call_rpc(
        args,
        token,
        "peerLinks.link",
        {
            "url": args.peer_url,
            "pairingCode": credential,
            "access": "full-access",
        },
    )
    linked_data = json.loads(linked)
    state.update(
        {
            "environmentId": linked_data["environmentId"],
            "linked": True,
            "revoked": False,
        }
    )
    atomic_json(args.state, state)


def call_rpc(args, token, operation, payload, *, base_url=None):
    return subprocess.check_output(
        ["node", str(args.rpc)],
        input=json.dumps(
            {
                "baseUrl": base_url or args.local_url,
                "token": token,
                "operation": operation,
                "input": payload,
            }
        ),
        text=True,
    )


if __name__ == "__main__":
    try:
        main()
    except (subprocess.SubprocessError, OSError, ValueError, KeyError, RuntimeError):
        raise SystemExit(
            f"T3 VM bootstrap failed during {PHASE}; captured credential output suppressed"
        )
