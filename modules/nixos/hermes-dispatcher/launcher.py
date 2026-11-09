"""Bootstrap a separate subscription-only Hermes profile without editing T3's login."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def atomic_text(path, text):
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".managed-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(text)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)


def main():
    settings = json.loads(Path(sys.argv[1]).read_text())
    action = sys.argv[2] if len(sys.argv) > 2 else "status"
    if action not in {"link", "login", "gateway", "signal", "status"}:
        raise SystemExit("Use: hermes-dispatcher {link|login|status}")
    state = Path(settings["stateDirectory"])
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    for name in ("home", "hermes", "codex", "signal", "cache", "config"):
        (state / name).mkdir(mode=0o700, exist_ok=True)
    env = {
        "PATH": settings["path"],
        "HOME": str(state / "home"),
        "HERMES_HOME": str(state / "hermes"),
        "CODEX_HOME": str(state / "codex"),
        "XDG_CONFIG_HOME": str(state / "config"),
        "XDG_CACHE_HOME": str(state / "cache"),
        "YOMI_SIGNAL_SOCKET": settings["socket"],
        "YOMI_SIGNAL_LEDGER": str(state / "hermes/signal-sent.sqlite"),
        "HERMES_DISABLE_LAZY_INSTALLS": "1",
        "LANG": "C.UTF-8",
    }
    # No inherited API keys, proxy credentials or unrelated provider logins.
    # Hermes also reads .env itself; refuse one rather than allowing hidden billing.
    for directory in (state / "hermes", state / "home"):
        if (directory / ".env").exists():
            raise SystemExit(
                "Remove the dispatcher's .env; only subscription login is supported"
            )
    if action == "status":
        print(
            json.dumps(
                {
                    "signalLinked": (state / "signal-account").exists(),
                    "codexLoginPresent": (state / "codex/auth.json").exists(),
                    "hermesLoginPresent": (state / "hermes/auth.json").exists(),
                    "signalSocketPresent": Path(settings["socket"]).exists(),
                    "model": "gpt-6.1-sol",
                    "effort": "medium",
                }
            )
        )
        return
    config = state / "hermes/config.yaml"
    atomic_text(config, Path(settings["configuration"]).read_text())
    atomic_text(state / "hermes/SOUL.md", Path(settings["instructions"]).read_text())
    os.chdir(state / "home")
    signal = [settings["signal"], "--config", str(state / "signal"), "--scrub-log"]
    if action == "link":
        subprocess.run([*signal, "link", "--name", "Yomi Hermes"], env=env, check=True)
        result = subprocess.run(
            [*signal, "--output", "json", "listAccounts"],
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )
        accounts = json.loads(result.stdout)
        if len(accounts) != 1 or not re.fullmatch(
            r"\+[1-9][0-9]{6,14}", accounts[0].get("number", "")
        ):
            raise SystemExit(
                "Expected exactly one linked Signal account with a phone number"
            )
        account_file = state / "signal-account"
        atomic_text(account_file, accounts[0]["number"] + "\n")
        account_file.chmod(0o600)
        return
    if action == "login":
        # Separate grants avoid two clients racing single-use refresh tokens.
        subprocess.run(
            [settings["codex"], "login", "--device-auth"], env=env, check=True
        )
        argv = [settings["hermes"], "auth", "add", "openai-codex", "--type", "oauth"]
    else:
        if action == "gateway":
            codex_auth = json.loads((state / "codex/auth.json").read_text())
            if codex_auth.get("auth_mode") != "chatgpt" or codex_auth.get(
                "OPENAI_API_KEY"
            ):
                raise SystemExit("Only a ChatGPT subscription login is allowed")
        account = (state / "signal-account").read_text().strip()
        if not re.fullmatch(r"\+[1-9][0-9]{6,14}", account):
            raise SystemExit("Invalid Signal account")
        env.update(
            {
                "SIGNAL_ACCOUNT": account,
                "SIGNAL_ALLOWED_USERS": account,
                "SIGNAL_ALLOW_ALL_USERS": "false",
                "SIGNAL_GROUP_ALLOWED_USERS": "",
                "SIGNAL_HTTP_URL": "http://signal-unix",
                "SIGNAL_IGNORE_STORIES": "true",
            }
        )
        argv = (
            [
                *signal,
                "--account",
                account,
                "daemon",
                "--socket",
                settings["socket"],
                "--receive-mode",
                "manual",
                "--ignore-attachments",
                "--ignore-stories",
                "--ignore-avatars",
                "--ignore-stickers",
            ]
            if action == "signal"
            else [settings["hermes"], "gateway", "run"]
        )
    os.execve(argv[0], argv, env)


if __name__ == "__main__":
    os.umask(0o077)
    main()
