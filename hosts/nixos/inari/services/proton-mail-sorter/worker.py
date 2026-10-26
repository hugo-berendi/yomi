"""Loopback-only worker for n8n; credentials stay outside workflow executions."""

import argparse
from collections import Counter
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


# Cached for a message the model answered unusably; never a folder name.
UNCLASSIFIED = ""


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
    # A pinned PEM, when given, is the one source for the fingerprint: the
    # stunnel relay trusts the same file, so the two pins cannot drift apart.
    if config.get("bridgeCertificateFile"):
        der = ssl.PEM_cert_to_DER_cert(
            Path(config["bridgeCertificateFile"]).read_text(encoding="ascii")
        )
        config["bridgeCertificateSha256"] = hashlib.sha256(der).hexdigest()
    if not re.fullmatch(r"[0-9a-fA-F]{64}", config["bridgeCertificateSha256"]):
        raise ValueError("A verified Bridge certificate fingerprint is required")
    for field in ("usernameRef", "passwordRef", "apiTokenRef"):
        if not re.fullmatch(r"op://[^/\r\n]+/[^/\r\n]+/[^\r\n]+", config[field]):
            raise ValueError("Invalid 1Password reference")
    if type(config["apply"]) is not bool or type(config["maxMessages"]) is not int:
        raise ValueError("Invalid apply/maxMessages settings")
    if not 1 <= config["maxMessages"] <= 1000:
        raise ValueError("Invalid message budget")
    if (
        type(config["maxReadMessages"]) is not int
        or not 1 <= config["maxReadMessages"] <= 100000
        or type(config["markExistingRead"]) is not bool
    ):
        raise ValueError("Invalid retroactive read settings")
    if (
        type(config.get("maxLabelMessages")) is not int
        or not 1 <= config["maxLabelMessages"] <= 1000
        or type(config.get("labelExisting")) is not bool
        or not isinstance(config.get("keepFolders"), list)
        or not all(
            isinstance(name, str) and name and "/" not in name
            for name in config["keepFolders"]
        )
    ):
        raise ValueError("Invalid label backfill settings")
    if type(config["bridgePort"]) is not int or not 1 <= config["bridgePort"] <= 65535:
        raise ValueError("Invalid Bridge port")
    url = urlsplit(config["modelUrl"])
    if (
        url.scheme not in ("http", "https")
        or not url.hostname
        or url.username
        or url.password
        or url.query
        or url.fragment
    ):
        raise ValueError("Invalid private model URL")
    if url.path.rstrip("/"):
        raise ValueError("Model URL must be a base URL, without /v1/chat/completions")
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
            token = (
                (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "op-service-account")
                .read_text()
                .strip()
            )
            if not token:
                raise SorterError("1Password bootstrap credential is empty")
            environment = os.environ.copy()
            environment["OP_SERVICE_ACCOUNT_TOKEN"] = token
            environment["OP_BIOMETRIC_UNLOCK_ENABLED"] = "false"
            environment.pop("OP_CONNECT_TOKEN", None)
            environment.pop("OP_CONNECT_HOST", None)
            try:
                result = subprocess.run(
                    [
                        self.config["opExecutable"],
                        "read",
                        "--no-newline",
                        self.config[field],
                    ],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    env=environment,
                    timeout=90,
                    check=False,
                )
            except (OSError, subprocess.TimeoutExpired):
                raise SorterError("1Password read failed") from None
            finally:
                environment.pop("OP_SERVICE_ACCOUNT_TOKEN", None)
                del token
            # CLI diagnostics can contain sensitive values; never propagate them.
            if (
                result.returncode
                or not result.stdout
                or "\n" in result.stdout
                or "\r" in result.stdout
            ):
                raise SorterError("1Password read failed")
            value = result.stdout
            if field == "apiTokenRef" and len(value) < 32:
                raise SorterError(
                    "Worker API token must contain at least 32 characters"
                )
            self.values[field] = (time.monotonic(), value)
            return value


def fingerprint(msg):
    return hashlib.sha256(msg.obj.as_bytes()).hexdigest()


# Where unsorted mail is read from. Wichtig was a folder until it became the
# Action label; whatever still sits in it (or the Windows sorter's KI-Wichtig)
# is sorted again, which files it by topic and labels it.
LEGACY_SOURCES = ("Wichtig", "KI-Wichtig")
# Folders whose messages are labelled without asking the model: neither
# Action nor Steuer can be true there, only the header-based Alias.
NO_MODEL_LABEL_FOLDERS = classifier.NO_ACTION_FOLDERS & classifier.NO_TAX_FOLDERS


class Layout:
    """Bridge's folder namespace: Folders/<name> and Labels/<name>."""

    def __init__(self, folders):
        delimiter = next(
            (
                f.delim
                for f in folders
                if f.name in ("Folders", "Labels")
                or f.name.startswith(("Folders/", "Labels/"))
            ),
            "/",
        )
        if not delimiter or delimiter == "NIL":
            raise SorterError("Folder delimiter not recognized")
        self.delimiter = delimiter
        self.folder_prefix = "Folders" + delimiter
        self.label_prefix = "Labels" + delimiter
        self.selectable = [f.name for f in folders if "\\Noselect" not in f.flags]
        self.existing = {f.name for f in folders}

    def target(self, category):
        return self.folder_prefix + category

    def label(self, name):
        return self.label_prefix + name

    def category_of(self, folder):
        for category in classifier.CATEGORIES:
            if folder in (self.target(category), self.target("KI-" + category)):
                return category
        return None

    def sources(self, mode):
        if mode == "sort":
            # The retired Wichtig folders first: they are small, and what is
            # in them needs its Action label before the INBOX and Archive
            # backlog uses up every job's budget.
            legacy = [self.target(name) for name in LEGACY_SOURCES]
            return (
                [name for name in legacy if name in self.selectable]
                + [name for name in self.selectable if name.upper() == "INBOX"]
                + [name for name in self.selectable if name == "Archive"]
            )
        # read and labels: the category folders, current and KI- legacy, never
        # INBOX, Archive, Labels/* or folders nobody declared.
        return [name for name in self.selectable if self.category_of(name)]


def sources_for(folders, mark_read):
    """Kept for callers that only need sources and targets."""
    layout = Layout(folders)
    targets = {name: layout.target(name) for name in classifier.CATEGORIES}
    return layout.sources("read" if mark_read else "sort"), targets


def message_id(msg):
    return classifier.mail_header(msg, "Message-ID", 1000).strip()


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
        box = self.mailbox_factory(
            self.config["bridgeHost"],
            port=self.config["bridgePort"],
            ssl_context=context,
            timeout=120,
        )
        try:
            actual = hashlib.sha256(
                box.client.socket().getpeercert(binary_form=True)
            ).hexdigest()
            if not hmac.compare_digest(
                actual, self.config["bridgeCertificateSha256"].lower()
            ):
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

    def verdict(self, database, folder, validity, msg, digest):
        """Cached model verdict, or None when the model answered unusably."""
        # A verdict about a deadline must not survive a new assessment day,
        # model or prompt revision unchanged.
        cache_digest = hashlib.sha256(
            (
                digest
                + time.strftime("%Y-%m-%d")
                + classifier.MODEL
                + classifier.CLASSIFICATION_PROMPT
            ).encode()
        ).hexdigest()
        cached = database.execute(
            "SELECT category FROM verdict WHERE source=? AND validity=? AND uid=? AND digest=?",
            (folder, validity, msg.uid, cache_digest),
        ).fetchone()
        if cached:
            return json.loads(cached[0]) if cached[0] else None
        try:
            verdict = classifier.validate(classifier.classify(msg))
            stored = json.dumps(verdict)
        except (ValueError, KeyError, TypeError):
            # The model answered, but not with a usable verdict. Hold only
            # this message: aborting here let one unreadable mail block every
            # later run at the same position. Anything else (model server
            # down, timeouts) still aborts the whole run before any change.
            verdict, stored = None, UNCLASSIFIED
        # Cached for the day like a verdict, so a held message costs one model
        # call per day rather than one per ten-minute run.
        database.execute(
            "INSERT OR REPLACE INTO verdict VALUES (?,?,?,?,?)",
            (folder, validity, msg.uid, cache_digest, stored),
        )
        database.commit()
        return verdict

    def action_message_ids(self, box, layout):
        """Message-IDs carrying the Action label; the read pass leaves them."""
        folder = layout.label(classifier.LABEL_ACTION)
        if folder not in layout.existing:
            return set()
        box.folder.set(folder)
        return {
            message_id(msg)
            for msg in box.fetch("ALL", mark_seen=False, headers_only=True, bulk=False)
        } - {""}

    def tidy(self, box, layout, note):
        """Fold KI- folders into their category and drop empty unused folders.

        note is None for a dry run, which only reports what would happen.
        """
        merged, deleted = 0, []
        budget = self.config["maxReadMessages"]
        # The Windows sorter's KI-<category> holds the same category; moving
        # it needs no model and empties the folder for the step below.
        for category in classifier.CATEGORIES:
            legacy = layout.target("KI-" + category)
            if legacy not in layout.selectable or merged >= budget:
                continue
            box.folder.set(legacy)
            uids = [uid for uid in box.uids("ALL") if re.fullmatch(r"[1-9][0-9]*", uid)]
            uids = uids[: budget - merged]
            if not uids:
                continue
            merged += len(uids)
            if note is None:
                continue
            target = layout.target(category)
            if target not in layout.existing:
                box.folder.create(target)
                layout.existing.add(target)
            entry = {
                "action": "merge",
                "source": legacy,
                "destination": target,
                "count": len(uids),
            }
            note({**entry, "status": "pending"})
            # UIDs from this same selection a moment ago; no older UID is used.
            if box.client.uid("MOVE", ",".join(uids), encode_folder(target))[0] != "OK":
                raise SorterError(
                    "Folder merge failed; previous actions remain applied"
                )
            note({**entry, "status": "done"})
        # Then every folder under Folders/ that is not a category, has no
        # subfolders and is empty right now. Labels are never touched, and
        # keepFolders protects folders the pilot wants to keep empty.
        keep = {layout.target(c) for c in classifier.CATEGORIES}
        keep |= {layout.target(name) for name in self.config["keepFolders"]}
        candidates = sorted(
            (
                name
                for name in layout.selectable
                if name.startswith(layout.folder_prefix) and name not in keep
            ),
            # Deepest first, so a parent can go once its children have.
            key=lambda name: -name.count(layout.delimiter),
        )
        for name in candidates:
            if any(
                other.startswith(name + layout.delimiter) for other in layout.existing
            ):
                continue
            if box.folder.status(name, ["MESSAGES"])["MESSAGES"] != 0:
                continue
            deleted.append(name)
            if note is None:
                continue
            entry = {"action": "delete_folder", "folder": name}
            note({**entry, "status": "pending"})
            # Never delete the selected mailbox from under the session.
            box.folder.set("INBOX")
            box.folder.delete(name)
            layout.existing.discard(name)
            note({**entry, "status": "done"})
        return {"merged": merged, "deletedFolders": deleted}

    def run(self, run_id, mark_read=False, labels=False):
        mode = "read" if mark_read else "labels" if labels else "sort"
        box = self.connect()
        database = None
        try:
            database = sqlite3.connect(self.state / "classifications.sqlite")
            database.execute(
                "CREATE TABLE IF NOT EXISTS verdict (source TEXT, validity INTEGER, uid TEXT, digest TEXT, category TEXT, PRIMARY KEY(source, validity, uid, digest))"
            )
            # Messages the label pass has finished with, so old mail is
            # labelled once rather than re-read every run.
            database.execute(
                "CREATE TABLE IF NOT EXISTS labelled (source TEXT, validity INTEGER, uid TEXT, PRIMARY KEY(source, validity, uid))"
            )
            capabilities = {
                v.decode() if isinstance(v, bytes) else v
                for v in box.client.capability()[1][0].split()
            }
            if mode == "sort" and "MOVE" not in capabilities:
                raise SorterError("Native IMAP MOVE required; no copy/delete fallback")
            layout = Layout(box.folder.list())
            sources = layout.sources(mode)
            if not sources and mode == "sort":
                raise SorterError("No unsorted source folders recognized")
            classifier.MODEL_CHAT_URL = (
                self.config["modelUrl"].rstrip("/") + "/v1/chat/completions"
            )
            keep_unread = (
                self.action_message_ids(box, layout) if mode == "read" else set()
            )
            plan = []
            unclassified = 0
            limit = {
                "read": self.config["maxReadMessages"],
                "labels": self.config["maxLabelMessages"],
                "sort": self.config["maxMessages"],
            }[mode]
            headers_only = mode == "read"
            plan_path = self.state / ("plan-" + run_id + ".jsonl")
            with plan_path.open("x", encoding="utf-8") as preview:

                def hold(folder, validity, msg, digest):
                    preview.write(
                        json.dumps(
                            {
                                "source": folder,
                                "uid": msg.uid,
                                "uidvalidity": validity,
                                "sha256": digest,
                                "subject": msg.subject,
                                "category": None,
                                "action": "hold",
                                "status": "model_answer_unusable",
                            },
                            ensure_ascii=False,
                        )
                        + "\n"
                    )
                    preview.flush()

                for folder in sources:
                    if len(plan) + unclassified >= limit:
                        break
                    box.folder.set(folder)
                    validity = box.folder.status(folder, ["UIDVALIDITY"])["UIDVALIDITY"]
                    if mode == "labels":
                        # Pick the unfinished UIDs first: fetching whole folders
                        # only to skip what is done would download all of it.
                        todo = [
                            uid
                            for uid in box.uids("ALL")
                            if not database.execute(
                                "SELECT 1 FROM labelled WHERE source=? AND validity=? AND uid=?",
                                (folder, validity, uid),
                            ).fetchone()
                        ][: limit - len(plan) - unclassified]
                        if not todo:
                            continue
                        query = "UID " + ",".join(todo)
                    else:
                        query = "UNSEEN" if mode == "read" else "ALL"
                    for msg in box.fetch(
                        query, mark_seen=False, headers_only=headers_only, bulk=False
                    ):
                        if len(plan) + unclassified >= limit:
                            break
                        if not re.fullmatch(r"[1-9][0-9]*", msg.uid):
                            raise SorterError("Invalid message UID")
                        digest = fingerprint(msg)
                        row = {
                            "source": folder,
                            "uid": msg.uid,
                            "uidvalidity": validity,
                            "sha256": digest,
                            "subject": msg.subject,
                        }
                        if mode == "read":
                            if message_id(msg) in keep_unread:
                                continue
                            row.update(
                                category=layout.category_of(folder),
                                destination=folder,
                                labels=[],
                                markRead=True,
                                move=False,
                            )
                        elif mode == "labels":
                            category = layout.category_of(folder)
                            if category in NO_MODEL_LABEL_FOLDERS:
                                verdict = {
                                    "folder": category,
                                    "action": False,
                                    "tax": False,
                                }
                            else:
                                verdict = self.verdict(
                                    database, folder, validity, msg, digest
                                )
                            if verdict is None:
                                unclassified += 1
                                hold(folder, validity, msg, digest)
                                continue
                            row.update(
                                category=category,
                                destination=folder,
                                labels=classifier.labels_for(msg, verdict),
                                markRead=False,
                                move=False,
                            )
                        else:
                            verdict = self.verdict(
                                database, folder, validity, msg, digest
                            )
                            if verdict is None:
                                unclassified += 1
                                hold(folder, validity, msg, digest)
                                continue
                            names = classifier.labels_for(msg, verdict)
                            row.update(
                                category=verdict["folder"],
                                destination=layout.target(verdict["folder"]),
                                labels=names,
                                # Action replaces the old Wichtig folder,
                                # which kept its read state; so does Action.
                                markRead=classifier.LABEL_ACTION not in names,
                                move=True,
                            )
                        preview.write(json.dumps(row, ensure_ascii=False) + "\n")
                        preview.flush()
                        plan.append(row)
                os.fsync(preview.fileno())
            counts = {
                "planned": len(plan),
                "moved": 0,
                "markedRead": 0,
                "labelled": 0,
                "held": 0,
                "unclassified": unclassified,
                "dryRun": not self.config["apply"],
                # Folder names only, so the journal shows where a job's budget
                # went without any message content.
                "sources": dict(Counter(row["source"] for row in plan)),
            }
            if not self.config["apply"]:
                if mode == "sort":
                    counts["tidy"] = self.tidy(box, layout, None)
                return counts
            needed = {layout.label(name) for row in plan for name in row["labels"]}
            needed |= {row["destination"] for row in plan if row["move"]}
            for name in sorted(needed - layout.existing):
                box.folder.create(name)
            with (self.state / ("actions-" + run_id + ".jsonl")).open(
                "x", encoding="utf-8"
            ) as log:

                def record(row, action, status):
                    log.write(
                        json.dumps(
                            {**row, "action": action, "status": status},
                            ensure_ascii=False,
                        )
                        + "\n"
                    )
                    log.flush()
                    os.fsync(log.fileno())

                def command(row, action, *arguments, failure):
                    record(row, action, "pending")
                    if box.client.uid(*arguments)[0] != "OK":
                        raise SorterError(failure)
                    record(row, action, "done")

                current = None
                for row in plan:
                    if current != row["source"]:
                        box.folder.set(row["source"])
                        current = row["source"]
                    if (
                        box.folder.status(current, ["UIDVALIDITY"])["UIDVALIDITY"]
                        != row["uidvalidity"]
                    ):
                        raise SorterError(
                            "UIDVALIDITY changed; stopping without reusing UIDs"
                        )
                    msg = next(
                        box.fetch(
                            "UID " + row["uid"],
                            mark_seen=False,
                            headers_only=headers_only,
                        ),
                        None,
                    )
                    if msg is None or fingerprint(msg) != row["sha256"]:
                        counts["held"] += 1
                        record(row, "hold", "message_missing_or_changed")
                        continue
                    # Labels first: COPY needs the message where the plan saw
                    # it, and a label must not be lost to a failed move.
                    for name in row["labels"]:
                        command(
                            row,
                            "label:" + name,
                            "COPY",
                            row["uid"],
                            encode_folder(layout.label(name)),
                            failure="Label copy failed; previous actions remain applied",
                        )
                        counts["labelled"] += 1
                    if row["markRead"]:
                        command(
                            row,
                            "mark_read",
                            "STORE",
                            row["uid"],
                            "+FLAGS.SILENT",
                            "(\\Seen)",
                            failure="Read flag update failed",
                        )
                        counts["markedRead"] += 1
                    if row["move"]:
                        command(
                            row,
                            "move",
                            "MOVE",
                            row["uid"],
                            encode_folder(row["destination"]),
                            failure="Native MOVE failed; previous actions remain applied",
                        )
                        counts["moved"] += 1
                    if mode == "labels":
                        database.execute(
                            "INSERT OR REPLACE INTO labelled VALUES (?,?,?)",
                            (row["source"], row["uidvalidity"], row["uid"]),
                        )
                        database.commit()

                def note(entry):
                    log.write(json.dumps(entry, ensure_ascii=False) + "\n")
                    log.flush()
                    os.fsync(log.fileno())

                if mode == "sort":
                    counts["tidy"] = self.tidy(box, layout, note)
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
                self.previous.update(
                    status="failed",
                    error="Worker restarted during a job; inspect the private action log",
                )
                atomic_json(status_path, self.previous)

    def start(self, mark_read):
        if not self.lock.acquire(blocking=False):
            return {"started": False, "busy": True}
        previous = self.previous
        run_id = (
            datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
            + "-"
            + uuid.uuid4().hex
        )
        running = {
            "id": run_id,
            "status": "running",
            "mode": "mark-read" if mark_read else "sort",
            "dryRun": not self.config["apply"],
        }
        try:
            atomic_json(self.state / "status.json", running)
            self.previous = running
            threading.Thread(
                target=self.finish, args=(running, mark_read), daemon=True
            ).start()
        except Exception:
            self.lock.release()
            raise
        return {
            "started": True,
            "busy": False,
            "id": run_id,
            "dryRun": not self.config["apply"],
            "previous": previous,
        }

    def finish(self, running, mark_read):
        try:
            result = self.sorter.run(running["id"], mark_read)
            if not mark_read and self.config["markExistingRead"]:
                result["existingRead"] = self.sorter.run(running["id"] + "-read", True)
            # Old mail gets its labels only while there is nothing new to
            # sort, so a backlog of labelling never delays incoming mail.
            if (
                not mark_read
                and self.config["labelExisting"]
                and result["planned"] == 0
                and result["unclassified"] == 0
            ):
                result["existingLabels"] = self.sorter.run(
                    running["id"] + "-labels", labels=True
                )
            status = {**running, **result, "status": "done"}
        except Exception as error:
            # IMAP/model/CLI exceptions can include message or credential data.
            # Keep the workflow and journal free of those provider diagnostics.
            diagnostic = (
                str(error) if isinstance(error, SorterError) else type(error).__name__
            )
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
        if not hmac.compare_digest(
            self.headers.get("Authorization", "").encode(), expected.encode()
        ):
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
        if self.headers.get("Content-Length", "0") != "0" or self.headers.get(
            "Transfer-Encoding"
        ):
            self.reply(400, {"error": "Request body not accepted"})
        elif self.path in ("/api/tick", "/api/mark-read"):
            self.reply(
                202, self.server.application.start(self.path == "/api/mark-read")
            )
        else:
            self.reply(404, {"error": "Not found"})


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--state", default="/var/lib/proton-mail-sorter")
    parser.add_argument("--port", type=int, default=8505)
    args = parser.parse_args()
    os.umask(0o077)
    configuration = validate_config(
        json.loads(Path(args.config).read_text(encoding="utf-8"))
    )
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.application = Application(configuration, Path(args.state))
    server.serve_forever()
