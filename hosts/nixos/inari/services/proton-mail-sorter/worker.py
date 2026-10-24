"""Loopback-only worker for n8n; credentials stay outside workflow executions."""

import argparse
from datetime import datetime, timezone
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import sqlite3
import ssl
import subprocess
import threading
import time
from urllib.parse import urlsplit
import uuid

from imap_tools import MailBoxStartTls
from imap_tools.utils import encode_folder

import classifier


class SorterError(RuntimeError):
    """A fixed, non-sensitive diagnostic safe for workflow/status output."""


def atomic_json(path, value):
    temporary = path.with_suffix(".tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False)
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


def validate_config(config):
    if not re.fullmatch(r"[0-9a-fA-F]{64}", config["bridgeCertificateSha256"]):
        raise ValueError("A verified Bridge certificate fingerprint is required")
    for field in ("usernameRef", "passwordRef", "apiTokenRef"):
        if not re.fullmatch(r"op://[^/\r\n]+/[^/\r\n]+/[^\r\n]+", config[field]):
            raise ValueError("Invalid 1Password reference")
    if type(config["apply"]) is not bool or type(config["maxMessages"]) is not int:
        raise ValueError("Invalid apply/maxMessages settings")
    if not 1 <= config["maxMessages"] <= 1000:
        raise ValueError("Invalid message budget")
    if type(config["maxReadMessages"]) is not int or not 1 <= config["maxReadMessages"] <= 100000 or type(config["markExistingRead"]) is not bool:
        raise ValueError("Invalid retroactive read settings")
    if type(config["bridgePort"]) is not int or not 1 <= config["bridgePort"] <= 65535:
        raise ValueError("Invalid Bridge port")
    url = urlsplit(config["ollamaUrl"])
    if url.scheme not in ("http", "https") or not url.hostname or url.username or url.password or url.query or url.fragment:
        raise ValueError("Invalid private Ollama URL")
    if url.path.rstrip("/"):
        raise ValueError("Ollama URL must be a base URL, without /api/chat")
    return config


class Secrets:
    def __init__(self, config):
        self.config = config
        self.values = {}
        self.lock = threading.Lock()

    def get(self, field):
        # Cache reads, never the service-account token. Frequent schedules must
        # not consume the 1Password quota once per message or HTTP request.
        with self.lock:
            cached = self.values.get(field)
            if cached and time.monotonic() - cached[0] < 900:
                return cached[1]
            token = (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "op-service-account").read_text().strip()
            if not token:
                raise SorterError("1Password bootstrap credential is empty")
            environment = os.environ.copy()
            environment["OP_SERVICE_ACCOUNT_TOKEN"] = token
            environment["OP_BIOMETRIC_UNLOCK_ENABLED"] = "false"
            environment.pop("OP_CONNECT_TOKEN", None)
            environment.pop("OP_CONNECT_HOST", None)
            try:
                result = subprocess.run(
                    [self.config["opExecutable"], "read", "--no-newline", self.config[field]],
                    capture_output=True, text=True, encoding="utf-8", env=environment,
                    timeout=90, check=False,
                )
            except (OSError, subprocess.TimeoutExpired):
                raise SorterError("1Password read failed") from None
            finally:
                environment.pop("OP_SERVICE_ACCOUNT_TOKEN", None)
                del token
            # CLI diagnostics can contain sensitive values; never propagate them.
            if result.returncode or not result.stdout or "\n" in result.stdout or "\r" in result.stdout:
                raise SorterError("1Password read failed")
            value = result.stdout
            if field == "apiTokenRef" and len(value) < 32:
                raise SorterError("Worker API token must contain at least 32 characters")
            self.values[field] = (time.monotonic(), value)
            return value


def fingerprint(msg):
    return hashlib.sha256(msg.obj.as_bytes()).hexdigest()


def sources_for(folders, mark_read):
    delimiter = next(
        (f.delim for f in folders if f.name == "Folders" or f.name.startswith("Folders/")), "/"
    )
    if not delimiter or delimiter == "NIL":
        raise SorterError("Folder delimiter not recognized")
    prefix = "Folders" + delimiter
    targets = {name: prefix + name for name in classifier.CATEGORIES}
    if mark_read:
        allowed = {prefix + old + name for old in ("", "KI-") for name in classifier.CATEGORIES if name != "Wichtig"}
        sources = [f.name for f in folders if "\\Noselect" not in f.flags and f.name in allowed]
    else:
        sources = [f.name for f in folders if "\\Noselect" not in f.flags and (f.name.upper() == "INBOX" or f.name == "Archive")]
    return sources, targets


class Sorter:
    def __init__(self, config, secrets, state, mailbox_factory=MailBoxStartTls):
        self.config = config
        self.secrets = secrets
        self.state = state
        self.mailbox_factory = mailbox_factory

    def connect(self):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        box = self.mailbox_factory(self.config["bridgeHost"], port=self.config["bridgePort"], ssl_context=context, timeout=120)
        try:
            actual = hashlib.sha256(box.client.socket().getpeercert(binary_form=True)).hexdigest()
            if not hmac.compare_digest(actual, self.config["bridgeCertificateSha256"].lower()):
                raise SorterError("Bridge certificate mismatch")
            username = self.secrets.get("usernameRef")
            password = self.secrets.get("passwordRef")
            try:
                box.login(username, password, initial_folder=None)
            except Exception:
                raise SorterError("Bridge authentication failed") from None
            finally:
                del password
            return box
        except Exception:
            try:
                box.logout()
            except Exception:
                pass
            raise

    def run(self, run_id, mark_read=False):
        box = self.connect()
        database = None
        try:
            database = sqlite3.connect(self.state / "classifications.sqlite")
            database.execute("CREATE TABLE IF NOT EXISTS verdict (source TEXT, validity INTEGER, uid TEXT, digest TEXT, category TEXT, PRIMARY KEY(source, validity, uid, digest))")
            capabilities = {v.decode() if isinstance(v, bytes) else v for v in box.client.capability()[1][0].split()}
            if not mark_read and "MOVE" not in capabilities:
                raise SorterError("Native IMAP MOVE required; no copy/delete fallback")
            folders = box.folder.list()
            sources, targets = sources_for(folders, mark_read)
            if not sources and not mark_read:
                raise SorterError("No unsorted source folders recognized")
            classifier.OLLAMA_CHAT_URL = self.config["ollamaUrl"].rstrip("/") + "/api/chat"
            plan = []
            limit = self.config["maxReadMessages"] if mark_read else self.config["maxMessages"]
            plan_path = self.state / ("plan-" + run_id + ".jsonl")
            with plan_path.open("x", encoding="utf-8") as preview:
                for folder in sources:
                    if len(plan) >= limit:
                        break
                    box.folder.set(folder)
                    validity = box.folder.status(folder, ["UIDVALIDITY"])["UIDVALIDITY"]
                    for msg in box.fetch("UNSEEN" if mark_read else "ALL", mark_seen=False, headers_only=mark_read, bulk=False):
                        if len(plan) >= limit:
                            break
                        if not re.fullmatch(r"[1-9][0-9]*", msg.uid):
                            raise SorterError("Invalid message UID")
                        digest = fingerprint(msg)
                        if mark_read:
                            category = next(c for c in classifier.CATEGORIES if folder in (targets[c], targets[c][:-len(c)] + "KI-" + c))
                            destination = folder
                        else:
                            # A verdict about a deadline must not survive a new
                            # assessment day, model or prompt revision unchanged.
                            cache_digest = hashlib.sha256((digest + time.strftime("%Y-%m-%d") + classifier.MODEL + classifier.CLASSIFICATION_PROMPT).encode()).hexdigest()
                            cached = database.execute("SELECT category FROM verdict WHERE source=? AND validity=? AND uid=? AND digest=?", (folder, validity, msg.uid, cache_digest)).fetchone()
                            category = cached[0] if cached else classifier.classify(msg)
                            if category not in classifier.CATEGORIES:
                                raise SorterError("Unknown model category")
                            database.execute("INSERT OR REPLACE INTO verdict VALUES (?,?,?,?,?)", (folder, validity, msg.uid, cache_digest, category))
                            database.commit()
                            destination = targets[category]
                        row = {"source": folder, "uid": msg.uid, "uidvalidity": validity, "sha256": digest,
                               "subject": msg.subject, "category": category, "destination": destination}
                        preview.write(json.dumps(row, ensure_ascii=False) + "\n")
                        preview.flush()
                        plan.append(row)
                os.fsync(preview.fileno())
            counts = {"planned": len(plan), "moved": 0, "markedRead": 0, "held": 0, "dryRun": not self.config["apply"]}
            if not self.config["apply"]:
                return counts
            existing = {f.name for f in folders}
            if not mark_read:
                for target in {r["destination"] for r in plan} - existing:
                    box.folder.create(target)
            with (self.state / ("actions-" + run_id + ".jsonl")).open("x", encoding="utf-8") as log:
                def record(row, action, status):
                    log.write(json.dumps({**row, "action": action, "status": status}, ensure_ascii=False) + "\n")
                    log.flush()
                    os.fsync(log.fileno())
                current = None
                for row in plan:
                    if current != row["source"]:
                        box.folder.set(row["source"])
                        current = row["source"]
                    if box.folder.status(current, ["UIDVALIDITY"])["UIDVALIDITY"] != row["uidvalidity"]:
                        raise SorterError("UIDVALIDITY changed; stopping without reusing UIDs")
                    msg = next(box.fetch("UID " + row["uid"], mark_seen=False, headers_only=mark_read), None)
                    if msg is None or fingerprint(msg) != row["sha256"]:
                        counts["held"] += 1
                        record(row, "hold", "message_missing_or_changed")
                        continue
                    if row["category"] != "Wichtig":
                        record(row, "mark_read", "pending")
                        if box.client.uid("STORE", row["uid"], "+FLAGS.SILENT", "(\\Seen)")[0] != "OK":
                            raise SorterError("Read flag update failed")
                        record(row, "mark_read", "done")
                        counts["markedRead"] += 1
                    if not mark_read:
                        record(row, "move", "pending")
                        if box.client.uid("MOVE", row["uid"], encode_folder(row["destination"]))[0] != "OK":
                            raise SorterError("Native MOVE failed; previous actions remain applied")
                        record(row, "move", "done")
                        counts["moved"] += 1
            return counts
        finally:
            if database is not None:
                database.close()
            try:
                box.logout()
            except Exception:
                pass


class Application:
    def __init__(self, config, state):
        self.config = config
        self.state = state
        state.mkdir(parents=True, exist_ok=True)
        self.secrets = Secrets(config)
        self.sorter = Sorter(config, self.secrets, state)
        self.lock = threading.Lock()
        self.previous = None
        status_path = state / "status.json"
        if status_path.exists():
            self.previous = json.loads(status_path.read_text(encoding="utf-8"))
            if self.previous.get("status") == "running":
                self.previous.update(status="failed", error="Worker restarted during a job; inspect the private action log")
                atomic_json(status_path, self.previous)

    def start(self, mark_read):
        if not self.lock.acquire(blocking=False):
            return {"started": False, "busy": True}
        previous = self.previous
        run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex
        running = {"id": run_id, "status": "running", "mode": "mark-read" if mark_read else "sort", "dryRun": not self.config["apply"]}
        try:
            atomic_json(self.state / "status.json", running)
            self.previous = running
            threading.Thread(target=self.finish, args=(running, mark_read), daemon=True).start()
        except Exception:
            self.lock.release()
            raise
        return {"started": True, "busy": False, "id": run_id, "dryRun": not self.config["apply"], "previous": previous}

    def finish(self, running, mark_read):
        try:
            result = self.sorter.run(running["id"], mark_read)
            if not mark_read and self.config["markExistingRead"]:
                result["existingRead"] = self.sorter.run(running["id"] + "-read", True)
            status = {**running, **result, "status": "done"}
        except Exception as error:
            # IMAP/Ollama/CLI exceptions can include message or credential data.
            # Keep the workflow and journal free of those provider diagnostics.
            diagnostic = str(error) if isinstance(error, SorterError) else type(error).__name__
            status = {**running, "status": "failed", "error": diagnostic}
        try:
            atomic_json(self.state / "status.json", status)
            self.previous = status
            print(json.dumps(status), flush=True)
        finally:
            self.lock.release()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def reply(self, code, payload):
        data = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def authenticated(self):
        try:
            expected = "Bearer " + self.server.application.secrets.get("apiTokenRef")
        except Exception:
            self.reply(503, {"error": "1Password unavailable"})
            return False
        if not hmac.compare_digest(self.headers.get("Authorization", "").encode(), expected.encode()):
            self.reply(401, {"error": "Unauthorized"})
            return False
        return True

    def do_GET(self):
        if self.authenticated():
            if self.path == "/api/status":
                self.reply(200, {"last": self.server.application.previous})
            else:
                self.reply(404, {"error": "Not found"})

    def do_POST(self):
        if not self.authenticated():
            return
        # No runtime arguments: a workflow cannot override folders, model,
        # destination, dry-run policy, secret references or network endpoints.
        if self.headers.get("Content-Length", "0") != "0" or self.headers.get("Transfer-Encoding"):
            self.reply(400, {"error": "Request body not accepted"})
        elif self.path in ("/api/tick", "/api/mark-read"):
            self.reply(202, self.server.application.start(self.path == "/api/mark-read"))
        else:
            self.reply(404, {"error": "Not found"})


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--state", default="/var/lib/proton-mail-sorter")
    parser.add_argument("--port", type=int, default=8505)
    args = parser.parse_args()
    os.umask(0o077)
    configuration = validate_config(json.loads(Path(args.config).read_text(encoding="utf-8")))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.application = Application(configuration, Path(args.state))
    server.serve_forever()
