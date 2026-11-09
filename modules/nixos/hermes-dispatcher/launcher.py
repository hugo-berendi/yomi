"""Bootstrap a separate subscription-only Hermes profile without editing T3's login."""

import json
import os
from pathlib import Path
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


def managed_link(path, target):
    # Replace only our symlink; never remove an existing skill directory.
    if path.exists() and not path.is_symlink():
        raise FileExistsError(f"Refusing to replace unmanaged skills at {path}")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=path.parent, prefix=".managed-") as temporary:
        link = Path(temporary) / "link"
        link.symlink_to(target, target_is_directory=True)
        os.replace(link, path)


def main():
    settings = json.loads(Path(sys.argv[1]).read_text())
    action = sys.argv[2] if len(sys.argv) > 2 else "status"
    if action not in {"matrix-bootstrap", "profile", "login", "gateway", "status"}:
        raise SystemExit("Use: hermes-dispatcher {login|profile|status}")
    state = Path(settings["stateDirectory"])
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    for name in ("home", "hermes", "codex", "cache", "config"):
        (state / name).mkdir(mode=0o700, exist_ok=True)
    if action == "matrix-bootstrap":
        from matrix_bootstrap import bootstrap

        bootstrap(state, settings["matrix"])
        from matrix_profile import update_profile

        update_profile(
            state, settings["matrix"], name=settings["matrix"]["displayName"]
        )
        return
    if action == "profile":
        import argparse
        from matrix_profile import update_profile

        parser = argparse.ArgumentParser(prog="hermes-dispatcher profile")
        parser.add_argument("--name")
        parser.add_argument("--avatar", type=Path)
        args = parser.parse_args(sys.argv[3:])
        if not args.name and not args.avatar:
            parser.error("Pass --name and/or --avatar")
        update_profile(state, settings["matrix"], name=args.name, avatar=args.avatar)
        return
    env = {
        "PATH": settings["path"],
        "HOME": str(state / "home"),
        "HERMES_HOME": str(state / "hermes"),
        "CODEX_HOME": str(state / "codex"),
        "XDG_CONFIG_HOME": str(state / "config"),
        "XDG_CACHE_HOME": str(state / "cache"),
        "HERMES_DISABLE_LAZY_INSTALLS": "1",
        "CIEL_ROUTING_CONFIG": settings["routingConfig"],
        "CIEL_ROUTE_LEDGER": str(state / "home/routes.jsonl"),
        "CIEL_BROKER_SOCKET": settings["brokerSocket"],
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
                    "matrixLoginPresent": (state / "matrix-auth.json").exists(),
                    "matrixUser": settings["matrix"]["userId"],
                    "allowedUser": settings["matrix"]["allowedUser"],
                    "codexLoginPresent": (state / "codex/auth.json").exists(),
                    "hermesLoginPresent": (state / "hermes/auth.json").exists(),
                    "model": "gpt-6.1-sol",
                    "effort": "medium",
                }
            )
        )
        return
    config = state / "hermes/config.yaml"
    atomic_text(config, Path(settings["configuration"]).read_text())
    atomic_text(state / "codex/config.toml", Path(settings["codexConfig"]).read_text())
    memory = state / "home/memory"
    memory.mkdir(mode=0o700, exist_ok=True)
    # Curated memory survives upgrades; configuration only seeds a new profile.
    for name, initial in (("preferences", settings["memorySeed"]), ("projects", "[]")):
        target = memory / (name + ".json")
        if not target.exists():
            atomic_text(target, initial)
    instructions = (
        Path(settings["instructions"]).read_text()
        + f"\n\nInstalled skill catalog: {settings['catalog']}\n"
    )
    atomic_text(state / "hermes/SOUL.md", instructions)
    # Codex's native loop has its own skill discovery and instruction loader.
    managed_link(state / "codex/skills/yomi", Path(settings["skills"]))
    atomic_text(state / "codex/AGENTS.md", instructions)
    os.chdir(state / "home")
    if action == "login":
        # Separate grants avoid two clients racing single-use refresh tokens.
        subprocess.run(
            [settings["codex"], "login", "--device-auth"], env=env, check=True
        )
        argv = [settings["hermes"], "auth", "add", "openai-codex", "--type", "oauth"]
    else:
        codex_auth = json.loads((state / "codex/auth.json").read_text())
        if codex_auth.get("auth_mode") != "chatgpt" or codex_auth.get("OPENAI_API_KEY"):
            raise SystemExit("Only a ChatGPT subscription login is allowed")
        from matrix_bootstrap import validate_auth

        auth = json.loads((state / "matrix-auth.json").read_text())
        validate_auth(auth, settings["matrix"]["userId"])
        env.update(
            {
                "MATRIX_HOMESERVER": settings["matrix"]["homeserver"],
                "MATRIX_USER_ID": auth["user_id"],
                "MATRIX_ACCESS_TOKEN": auth["access_token"],
                "MATRIX_DEVICE_ID": auth["device_id"],
                "MATRIX_ALLOWED_USERS": settings["matrix"]["allowedUser"],
                "MATRIX_ALLOW_ALL_USERS": "false",
                "MATRIX_E2EE_MODE": "required",
                "MATRIX_ALLOW_PUBLIC_ROOMS": "false",
                "MATRIX_DM_AUTO_THREAD": "false",
                "MATRIX_AUTO_THREAD": "false",
                "MATRIX_RECOVERY_KEY_OUTPUT_FILE": str(state / "matrix-recovery-key"),
            }
        )
        argv = [settings["hermes"], "gateway", "run"]
    os.execve(argv[0], argv, env)


if __name__ == "__main__":
    os.umask(0o077)
    main()
