"""Weekly mail using the existing journal and a durable at-most-once outbox."""

import fcntl
import json
import os
import re
import smtplib
import ssl
import sys
from datetime import UTC, datetime
from pathlib import Path

from analysis import BERLIN, week_bounds
from app import (
    ai_review,
    build_report,
    database,
    get_settings,
    get_state,
    snapshot_database,
)
from glooko_sync import sync
from report_email import render


class Rejected(Exception):
    """Submission definitely did not succeed; retry is safe."""


def due(now):
    local = now.astimezone(BERLIN)
    return local.weekday() != 0 or local.hour >= 9


def configuration():
    directory = Path(os.environ.get("CREDENTIALS_DIRECTORY", "/nonexistent"))
    path = directory / "weekly-mail"
    if not path.exists():
        return {}
    config = {
        "host": "smtp.migadu.com",
        "port": 465,
        "implicit_tls": True,
        "sender": "no-reply@tengu.hugo-berendi.de",
        "username": "no-reply@tengu.hugo-berendi.de",
    } | json.loads(path.read_text())
    password = directory / "weekly-smtp-password"
    if "password" not in config and password.exists():
        config["password"] = password.read_text().strip()
    return config


def valid_configuration(config):
    # Only a single, explicit mailbox is allowed for each envelope address.
    return all(
        isinstance(config.get(key), str)
        and re.fullmatch(r"[^\s<>@,;]+@[^\s<>@,;]+", config[key])
        for key in ("sender", "recipient")
    ) and bool(config.get("host"))


def smtp_submit(message, config):
    client = None
    submitting = False
    try:
        if config.get("implicit_tls", False):
            client = smtplib.SMTP_SSL(
                config["host"],
                int(config.get("port", 465)),
                timeout=30,
                context=ssl.create_default_context(),
            )
        else:
            client = smtplib.SMTP(
                config["host"], int(config.get("port", 587)), timeout=30
            )
            client.ehlo()
            client.starttls(context=ssl.create_default_context())
        client.ehlo()
        if config.get("username"):
            client.login(config["username"], config["password"])
        submitting = True
        refused = client.send_message(message)
        if refused:
            raise Rejected()
    except (
        smtplib.SMTPRecipientsRefused,
        smtplib.SMTPSenderRefused,
        smtplib.SMTPDataError,
    ):
        raise Rejected() from None
    except Exception:
        if not submitting:
            raise Rejected() from None
        raise
    finally:
        # A failed QUIT cannot turn an acknowledged DATA response into a failure.
        if client:
            try:
                client.close()
            except OSError:
                pass


def run_weekly(root, config=None, now=None, submit=smtp_submit, review=ai_review):
    now = now or datetime.now(UTC)
    config = configuration() if config is None else config
    if not valid_configuration(config):
        return {"status": "not configured"}
    if not due(now):
        return {"status": "not due"}
    with (root / "weekly.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return {"status": "already running"}
        week = datetime.fromtimestamp(week_bounds(now)[0], BERLIN).date().isoformat()
        with database(root) as db:
            db.execute(
                "CREATE TABLE IF NOT EXISTS weekly_mail (week TEXT PRIMARY KEY, revision TEXT, status TEXT, updated INTEGER)"
            )
            row = db.execute(
                "SELECT status,updated FROM weekly_mail WHERE week=?", (week,)
            ).fetchone()
            if row and row[0] == "rejected" and now.timestamp() - row[1] < 6 * 3600:
                return {"status": "rejected"}
            if row and row[0] in {"submitted", "submitting", "uncertain"}:
                return {"status": "uncertain" if row[0] == "submitting" else row[0]}
        sync_status = sync(root, refresh=True)
        with database(root) as db:
            report = build_report(db, now)
            enabled = get_settings(db)["ai_enabled"]
            sync_state = get_state(db, "glooko", {})
        quality = [
            f"Glooko synchronization status: {sync_status}. Last successful synchronization: "
            + (
                datetime.fromtimestamp(sync_state["success"], BERLIN).isoformat()
                if sync_state.get("success")
                else "Unavailable"
            )
            + "."
        ]
        if sync_state.get("error"):
            quality.append(sync_state["error"])
        quality += sync_state.get("notices", [])
        selected = None
        if enabled and report["comparable"]:
            try:
                selected = review(
                    report,
                    os.environ.get(
                        "AI_URL", "http://127.0.0.1:8496/v1/chat/completions"
                    ),
                )
            except Exception as error:
                # Type and message only: no traceback, which could echo report data.
                print(
                    f"AI review failed: {type(error).__name__}: {error}",
                    file=sys.stderr,
                )
        message = render(report, config, now, selected, quality)
        with database(root) as db:
            db.execute(
                "INSERT OR REPLACE INTO weekly_mail VALUES (?,?,?,?)",
                (week, report["revision"], "submitting", int(now.timestamp())),
            )
        # Backups must retain the reservation even if this process dies in DATA.
        snapshot_database(root)
        try:
            submit(message, config)
            status = "submitted"
        except Rejected:
            status = "rejected"
        except Exception:
            status = "uncertain"
        with database(root) as db:
            db.execute(
                "UPDATE weekly_mail SET status=?,updated=? WHERE week=?",
                (status, int(now.timestamp()), week),
            )
        snapshot_database(root)
        return {"status": status}
