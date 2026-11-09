import hashlib
import fcntl
import json
from pathlib import Path
import re

from launcher import atomic_text


class LocalTools:
    def __init__(self, config):
        self.config = config

    def handle(self, name, args):
        if name in {"ciel_memory_read", "ciel_memory_write"}:
            kind = args.get("kind")
            if kind not in {"preferences", "projects"}:
                raise ValueError("Unknown memory kind")
            root = Path(self.config["memoryDirectory"])
            root.mkdir(mode=0o700, parents=True, exist_ok=True)
            with (root / (kind + ".lock")).open("a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                return self._handle(name, args)
        return self._handle(name, args)

    def _handle(self, name, args):
        if name == "ciel_skills_list":
            return Path(self.config["catalog"]).read_text()
        if name == "ciel_skill_read":
            skill = args.get("skill", "")
            if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", skill):
                raise ValueError("Invalid skill name")
            root = (Path(self.config["skills"]) / skill).resolve(strict=True)
            path = (root / args.get("path", "SKILL.md")).resolve(strict=True)
            if (
                not path.is_relative_to(root)
                or not path.is_file()
                or path.stat().st_size > 64000
            ):
                raise ValueError(
                    "Skill resource is outside the selected skill or too large"
                )
            return path.read_text()
        if name in {"ciel_memory_read", "ciel_memory_write"}:
            kind = args.get("kind")
            if kind not in {"preferences", "projects"}:
                raise ValueError("Unknown memory kind")
            root = Path(self.config["memoryDirectory"])
            path = root / (kind + ".json")
            current = path.read_text() if path.exists() else "[]"
            etag = hashlib.sha256(current.encode()).hexdigest()
            if name == "ciel_memory_read":
                return {"etag": etag, "entries": json.loads(current)}
            if args.get("etag") != etag:
                raise ValueError("Memory changed; read it again before replacing it")
            entries = args.get("entries")
            if not isinstance(entries, list) or any(
                not isinstance(e, dict)
                or not all(
                    isinstance(e.get(k), str) and e[k]
                    for k in ("fact", "source", "date")
                )
                for e in entries
            ):
                raise ValueError("Each memory needs a fact, source and date")
            content = json.dumps(entries, ensure_ascii=False, indent=2)
            if len(content) > 6000 or re.search(
                r"access_token|refresh_token|authorization:|-----BEGIN.*PRIVATE KEY|\bsk-[A-Za-z0-9]{12}",
                content,
                re.I,
            ):
                raise ValueError("Memory is too large or contains credential-like data")
            root.mkdir(mode=0o700, parents=True, exist_ok=True)
            atomic_text(path, content)
            return {"saved": True, "etag": hashlib.sha256(content.encode()).hexdigest()}
        raise ValueError("Unknown local Ciel tool")
