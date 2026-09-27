"""Private Yomi diabetes journal, reports and optional read-only integrations."""

import argparse
from collections import defaultdict
import contextlib
import fcntl
import hmac
import io
import json
import logging
import os
from pathlib import Path
import re
import secrets
import sqlite3
import threading
import time
from datetime import UTC, datetime, timedelta
from urllib.request import Request, urlopen
import uuid

from flask import (
    Flask,
    abort,
    jsonify,
    redirect,
    render_template,
    request,
    session,
    send_file,
)

from analysis import BERLIN, MAX_BYTES, comparison, number, parse_export, timestamp

DEFAULTS = {
    "low": 70,
    "high": 180,
    "display_unit": "mg/dL",
    "notify_service": "",
    "high_notifications": False,
    "high_minutes": 30,
    "light_entity": "",
    "night_light": False,
    "ai_enabled": True,
}
QUESTIONS = {
    "late": "What should my personal plan be when I remember a meal bolus during or after eating?",
    "patterns": "Do the highlighted high-glucose periods suggest a routine we should review together?",
    "lows": "Were there low-glucose periods alongside the highs that we should review?",
}


def read_secret(path):
    if not path.exists():
        try:
            with path.open("x") as file:
                os.chmod(path, 0o600)
                file.write(secrets.token_urlsafe(40))
        except FileExistsError:
            pass
    return path.read_text().strip()


@contextlib.contextmanager
def database(root):
    db = sqlite3.connect(root / "journal.sqlite", timeout=30)
    db.row_factory = sqlite3.Row
    try:
        with db:
            yield db
    finally:
        db.close()


def init_db(root):
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    with database(root) as db:
        db.executescript("""
        CREATE TABLE IF NOT EXISTS records (
          kind TEXT, ts INTEGER, value REAL, carbs REAL,
          event_index INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY(kind, ts, event_index));
        CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE IF NOT EXISTS reports (week TEXT PRIMARY KEY, payload TEXT, ai TEXT);
        CREATE TABLE IF NOT EXISTS actions (id TEXT PRIMARY KEY);
        CREATE TABLE IF NOT EXISTS supplies (
          kind TEXT PRIMARY KEY, stock INTEGER, hours REAL, lead_days INTEGER,
          changed INTEGER, site TEXT);
        INSERT OR IGNORE INTO supplies VALUES ('Pod', 0, 72, 14, NULL, '');
        INSERT OR IGNORE INTO supplies VALUES ('Sensor', 0, 240, 14, NULL, '');
        CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, ts INTEGER, text TEXT);
        CREATE TABLE IF NOT EXISTS appointments (id TEXT PRIMARY KEY, ts INTEGER, title TEXT);
        CREATE TABLE IF NOT EXISTS sent (key TEXT PRIMARY KEY, ts INTEGER);
        CREATE TABLE IF NOT EXISTS state (key TEXT PRIMARY KEY, value TEXT);
        """)
        db.execute("BEGIN IMMEDIATE")
        if "event_index" not in {
            row["name"] for row in db.execute("PRAGMA table_info(records)")
        }:
            db.execute("ALTER TABLE records RENAME TO legacy_records")
            db.execute("""CREATE TABLE records (
                kind TEXT, ts INTEGER, value REAL, carbs REAL,
                event_index INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY(kind, ts, event_index))""")
            db.execute("""INSERT INTO records (kind,ts,value,carbs)
                SELECT kind,ts,value,carbs FROM legacy_records""")
            db.execute("DROP TABLE legacy_records")


def get_settings(db):
    return DEFAULTS | {
        r["key"]: json.loads(r["value"]) for r in db.execute("SELECT * FROM settings")
    }


def get_state(db, key, default=None):
    row = db.execute("SELECT value FROM state WHERE key=?", (key,)).fetchone()
    return json.loads(row[0]) if row else default


def put_state(db, key, value):
    db.execute("INSERT OR REPLACE INTO state VALUES (?,?)", (key, json.dumps(value)))


def snapshot_database(root):
    """Publish a consistent SQLite backup for file-based restic snapshots."""
    temporary = root / "backup.sqlite.tmp"
    with (
        database(root) as source,
        contextlib.closing(sqlite3.connect(temporary)) as target,
    ):
        source.backup(target)
    os.replace(temporary, root / "backup.sqlite")


def import_records(db, records):
    inserted = 0
    grouped = defaultdict(set)
    for kind, ts, value, carbs in records:
        if ts > time.time() + 300:
            raise ValueError(
                "Export contains future records; check its timestamp timezone"
            )
        grouped[kind, ts].add((value, carbs))
    for (kind, ts), events in grouped.items():
        old = {
            tuple(row)
            for row in db.execute(
                "SELECT value, carbs FROM records WHERE kind=? AND ts=?", (kind, ts)
            )
        }
        # Minute-resolution exports can contain distinct boluses at one time.
        # Compare the whole group on reimport; a changed or partial group must
        # not silently add insulin or replace an earlier event.
        if (kind == "cgm" and len(events) != 1) or (old and old != events):
            raise ValueError(
                "Conflicting records at the same timestamp. Choose one source; nothing was imported."
            )
        if old:
            continue
        for index, (value, carbs) in enumerate(
            sorted(
                events,
                key=lambda event: (event[0], -1 if event[1] is None else event[1]),
            )
        ):
            inserted += db.execute(
                "INSERT INTO records VALUES (?,?,?,?,?)",
                (kind, ts, value, carbs, index),
            ).rowcount
    return inserted


def build_report(db, now=None):
    cfg = get_settings(db)
    readings = [
        (r[0], r[1])
        for r in db.execute("SELECT ts,value FROM records WHERE kind='cgm' ORDER BY ts")
    ]
    boluses = [
        tuple(r)
        for r in db.execute(
            "SELECT ts,value,carbs FROM records WHERE kind='bolus' ORDER BY ts"
        )
    ]
    report = comparison(readings, boluses, now, cfg["low"], cfg["high"])
    week = report["weeks"][0]["label"]
    old = db.execute("SELECT payload, ai FROM reports WHERE week=?", (week,)).fetchone()
    ai = (
        old[1] if old and json.loads(old[0])["revision"] == report["revision"] else None
    )
    db.execute(
        "INSERT OR REPLACE INTO reports VALUES (?,?,?)", (week, json.dumps(report), ai)
    )
    return report


def http_json(url, payload=None, token=None, timeout=15):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = Request(
        url,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers=headers,
    )
    with urlopen(req, timeout=timeout) as response:
        return json.loads(response.read(1024 * 1024))


def ai_review(report, url):
    """The model selects verified facts; it cannot supply prose, doses or numbers."""
    prompt = {
        "facts": report["facts"],
        "questions": QUESTIONS,
        "instruction": "Select up to three useful fact IDs and two question IDs for a weekly review. Return only JSON with fact_ids and question_ids arrays. Include coverage. Do not generate prose or treatment advice.",
    }
    result = http_json(
        url,
        {
            "messages": [{"role": "user", "content": json.dumps(prompt)}],
            "temperature": 0,
            "max_tokens": 180,
            "response_format": {"type": "json_object"},
        },
        timeout=180,
    )
    content = result["choices"][0]["message"]["content"].strip()
    # The installed local server can return a Markdown fence despite JSON
    # response_format. Remove only that wrapper, then enforce the same schema.
    if content.startswith("```json\n") and content.endswith("\n```"):
        content = content[8:-4]
    selected = json.loads(content)
    valid_facts = {f["id"] for f in report["facts"]}
    if set(selected) != {"fact_ids", "question_ids"}:
        raise ValueError("Invalid model response")
    for key, allowed, limit in (
        ("fact_ids", valid_facts, 3),
        ("question_ids", set(QUESTIONS), 2),
    ):
        values = selected[key]
        if (
            not isinstance(values, list)
            or len(values) > limit
            or any(not isinstance(v, str) or v not in allowed for v in values)
        ):
            raise ValueError("Model selected unknown evidence")
    if "coverage" not in selected["fact_ids"]:
        raise ValueError("Model omitted data coverage")
    return selected


class DexcomReader:
    def __init__(self, credential_path):
        self.path = credential_path
        self.client = None
        self.cached = None
        self.fetched = 0
        self.lock = threading.Lock()

    def read(self):
        with self.lock:
            now = time.time()
            if not self.path:
                return {
                    "available": False,
                    "reason": "Dexcom credentials not configured",
                }
            if now - self.fetched >= 60:
                self.fetched = now
                try:
                    from pydexcom import Dexcom
                    from requests.adapters import HTTPAdapter

                    class BoundedAdapter(HTTPAdapter):
                        def send(self, request, **kwargs):
                            kwargs["timeout"] = (5, 10)
                            return super().send(request, **kwargs)

                    class BoundedDexcom(Dexcom):
                        def _post(self, *args, **kwargs):
                            # pydexcom 0.5.1 has no timeout option, including
                            # its initial login. Bound every HTTPS exchange.
                            self._session.mount("https://", BoundedAdapter())
                            return super()._post(*args, **kwargs)

                    logging.getLogger("pydexcom").setLevel(logging.CRITICAL)

                    if self.client is None:
                        credentials = json.loads(Path(self.path).read_text())
                        self.client = BoundedDexcom(
                            username=credentials["username"],
                            password=credentials["password"],
                            region="ous",
                        )
                    reading = self.client.get_current_glucose_reading()
                    if reading is None:
                        raise ValueError("No reading")
                    self.cached = {
                        "value": reading.mg_dl,
                        "trend": reading.trend_arrow,
                        "timestamp": reading.datetime.timestamp(),
                    }
                except Exception:
                    self.client = None
                    self.cached = None
            if self.cached is None:
                return {"available": False, "reason": "Dexcom unavailable"}
            age = now - self.cached["timestamp"]
            if age < -60 or age > 600:
                return {
                    "available": False,
                    "reason": "Reading is stale or has a future timestamp",
                    "age_seconds": round(age),
                }
            return self.cached | {"available": True, "age_seconds": round(max(age, 0))}


def create_app(root=None, config=None):
    os.umask(0o077)
    root = Path(root or os.environ.get("STATE_DIRECTORY", "/var/lib/diabetes"))
    init_db(root)
    access_token = read_secret(root / "access-token")
    read_token = read_secret(root / "read-token")
    app = Flask(__name__)
    app.config.update(
        SECRET_KEY=read_secret(root / "session-key"),
        MAX_CONTENT_LENGTH=MAX_BYTES,
        SESSION_COOKIE_SECURE=True,
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Strict",
        PERMANENT_SESSION_LIFETIME=timedelta(hours=12),
    )
    app.config.update(config or {})
    app.config["ROOT"] = root
    dexcom = DexcomReader(os.environ.get("DEXCOM_CREDENTIAL_FILE"))
    app.extensions["dexcom"] = dexcom
    ha_url = os.environ.get("HOME_ASSISTANT_URL", "http://127.0.0.1:8123")
    credential_dir = Path(
        os.environ.get("CREDENTIALS_DIRECTORY", "/run/credentials/diabetes.service")
    )

    def ha_call(path, payload):
        token = (credential_dir / "home-assistant-token").read_text().strip()
        return http_json(ha_url + path, payload, token)

    def notify(cfg, key, message):
        if not cfg["notify_service"]:
            return False
        with database(root) as db:
            if db.execute("SELECT 1 FROM sent WHERE key=?", (key,)).fetchone():
                return True
        # No health values on the lock screen. The stable tag replaces a
        # duplicate if a process dies after sending but before committing.
        ha_call(
            "/api/services/notify/" + cfg["notify_service"],
            {
                "title": "Yomi",
                "message": message,
                "data": {
                    "tag": key,
                    "url": os.environ.get("PUBLIC_URL", "/"),
                    "clickAction": os.environ.get("PUBLIC_URL", "/"),
                },
            },
        )
        with database(root) as db:
            db.execute(
                "INSERT OR REPLACE INTO sent VALUES (?,?)", (key, int(time.time()))
            )
        return True

    def tick():
        with (root / "jobs.lock").open("w") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return {"status": "already running"}
            with database(root) as db:
                cfg = get_settings(db)
                report = build_report(db, datetime.fromtimestamp(time.time(), UTC))
                week = report["weeks"][0]["label"]
                ai = db.execute(
                    "SELECT ai FROM reports WHERE week=?", (week,)
                ).fetchone()[0]
                supplies = [dict(r) for r in db.execute("SELECT * FROM supplies")]
                appointments = [
                    dict(r) for r in db.execute("SELECT * FROM appointments")
                ]
                meal = get_state(db, "meal")
                ai_attempt = get_state(db, "ai_attempt", 0)
            errors = []
            if (
                cfg["ai_enabled"]
                and report["comparable"]
                and ai is None
                and time.time() - ai_attempt >= 3600
            ):
                with database(root) as db:
                    put_state(db, "ai_attempt", int(time.time()))
                try:
                    selected = ai_review(
                        report,
                        os.environ.get(
                            "AI_URL", "http://127.0.0.1:8496/v1/chat/completions"
                        ),
                    )
                    with database(root) as db:
                        # A simultaneous import must not attach stale commentary.
                        db.execute(
                            "UPDATE reports SET ai=? WHERE week=? AND payload=?",
                            (json.dumps(selected), week, json.dumps(report)),
                        )
                except Exception:
                    errors.append(
                        "Local AI unavailable or invalid; calculated report remains available"
                    )
            now = int(time.time())
            messages = (
                [
                    (
                        f"week:{week}:ready"
                        if report["comparable"]
                        else f"week:{week}:upload",
                        "Your weekly review is ready."
                        if report["comparable"]
                        else (
                            "Your weekly review has missing data. Check Glooko sync in your journal."
                            if (root / "glooko-credentials.json").exists()
                            else "Connect Glooko in your journal to update your weekly review automatically."
                        ),
                    )
                ]
                if now >= report["weeks"][0]["end"] + 8 * 3600
                else []
            )
            for supply in supplies:
                if supply["changed"] is None:
                    continue
                if now >= supply["changed"] + supply["hours"] * 3600 - 12 * 3600:
                    messages.append(
                        (
                            f"change:{supply['kind']}:{supply['changed']}",
                            "A replacement reminder is due. Open your journal.",
                        )
                    )
                if supply["stock"] * supply["hours"] / 24 <= supply["lead_days"]:
                    messages.append(
                        (
                            f"stock:{supply['kind']}",
                            "Review your supplies and delivery lead time.",
                        )
                    )
            for appointment in appointments:
                if 0 <= appointment["ts"] - now <= 7 * 86400:
                    messages.append(
                        (
                            "appointment:" + appointment["id"],
                            "Prepare your appointment notes and weekly reports.",
                        )
                    )
            if (
                meal
                and not meal["done"]
                and meal["due"] <= now
                and meal["expires"] > now
            ):
                messages.append(
                    (
                        f"meal:{meal['id']}:{meal['due']}",
                        "Meal check: review your plan and pump history.",
                    )
                )
            for key, message in messages:
                try:
                    notify(cfg, key, message)
                except Exception:
                    errors.append("Notification delivery failed; it will be retried")
            reading = (
                dexcom.read()
                if cfg["high_notifications"] or cfg["night_light"]
                else {"available": False}
            )
            with database(root) as db:
                high = get_state(db, "high")
                if (
                    not reading["available"]
                    or reading.get("age_seconds", 601) > 360
                    or reading["value"] <= cfg["high"]
                ):
                    high = None
                elif high is None or reading["timestamp"] - high["seen"] > 360:
                    high = {"start": reading["timestamp"], "seen": reading["timestamp"]}
                else:
                    high["seen"] = reading["timestamp"]
                put_state(db, "high", high)
            if (
                cfg["high_notifications"]
                and high
                and high["seen"] - high["start"] >= cfg["high_minutes"] * 60
            ):
                try:
                    notify(
                        cfg,
                        f"high:{high['start']}",
                        "Check your current glucose and your agreed care plan.",
                    )
                except Exception:
                    errors.append("Glucose reminder delivery failed")
            hour = datetime.now(BERLIN).hour
            if (
                cfg["night_light"]
                and cfg["light_entity"]
                and reading["available"]
                and reading["value"] < cfg["low"]
                and (hour >= 22 or hour < 6)
            ):
                with database(root) as db:
                    last_light = get_state(db, "last_light", 0)
                if now - last_light >= 3600:
                    try:
                        ha_call(
                            "/api/services/light/turn_on",
                            {"entity_id": cfg["light_entity"], "brightness_pct": 15},
                        )
                        with database(root) as db:
                            put_state(db, "last_light", now)
                    except Exception:
                        errors.append("Optional light unavailable")
            with database(root) as db:
                put_state(db, "jobs", {"at": now, "errors": sorted(set(errors))})
            snapshot_database(root)
            return {"status": "completed", "errors": sorted(set(errors))}

    app.extensions["tick"] = tick

    @app.before_request
    def authenticate():
        session.setdefault("csrf", secrets.token_urlsafe(32))
        token = request.headers.get("Authorization", "").removeprefix("Bearer ")
        full_access = hmac.compare_digest(token, access_token)
        read_access = (
            request.method == "GET"
            and request.path == "/api/glucose"
            and hmac.compare_digest(token, read_token)
        )
        if request.path.startswith("/static/"):
            return None
        if request.path != "/login" and not (
            session.get("authenticated") or full_access or read_access
        ):
            if request.path.startswith("/api/"):
                abort(401)
            return redirect("/login")
        if request.method == "POST" and not full_access:
            if not hmac.compare_digest(request.form.get("csrf", ""), session["csrf"]):
                abort(403)
        return None

    @app.after_request
    def headers(response):
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; style-src 'self'; script-src 'none'; frame-ancestors 'none'; form-action 'self'; base-uri 'none'"
        )
        return response

    @app.errorhandler(ValueError)
    def invalid(error):
        return render_template(
            "message.html", title="Nothing changed", message=str(error)
        ), 400

    @app.route("/login", methods=["GET", "POST"])
    def login():
        error = None
        if request.method == "POST":
            if hmac.compare_digest(request.form.get("token", ""), access_token):
                session.clear()
                session.update(authenticated=True, csrf=secrets.token_urlsafe(32))
                session.permanent = True
                return redirect("/")
            error = "Access key not accepted"
        return render_template("login.html", error=error), 401 if error else 200

    @app.post("/logout")
    def logout():
        session.clear()
        return redirect("/login")

    @app.get("/")
    @app.get("/appointment")
    def index():
        with database(root) as db:
            cfg = get_settings(db)
            reports = db.execute(
                "SELECT * FROM reports ORDER BY week DESC LIMIT 12"
            ).fetchall()
            requested = request.args.get("week")
            row = next(
                (r for r in reports if r["week"] == requested),
                reports[0] if reports else None,
            )
            report = json.loads(row["payload"]) if row else None
            selected = json.loads(row["ai"]) if row and row["ai"] else None
            return render_template(
                "index.html",
                cfg=cfg,
                report=report,
                selected=selected,
                questions=QUESTIONS,
                reports=reports,
                supplies=db.execute("SELECT * FROM supplies ORDER BY kind").fetchall(),
                notes=db.execute(
                    "SELECT * FROM notes ORDER BY ts DESC LIMIT 50"
                ).fetchall(),
                appointments=db.execute(
                    "SELECT * FROM appointments WHERE ts>? ORDER BY ts",
                    (int(time.time()),),
                ).fetchall(),
                jobs=get_state(db, "jobs"),
                glooko=get_state(db, "glooko", {}),
                glooko_connected=(root / "glooko-credentials.json").exists(),
                meal=get_state(db, "meal"),
                action_id=str(uuid.uuid4()),
                packet=request.path == "/appointment",
            )

    @app.post("/glooko")
    def glooko_connection():
        from glooko_sync import save_credentials, sync_lock

        action = request.form.get("action")
        with sync_lock(root):
            if action == "connect":
                save_credentials(
                    root,
                    request.form.get("email", ""),
                    request.form.get("password", ""),
                    request.form.get("timezone", "Europe/Berlin"),
                )
            elif action == "disconnect":
                (root / "glooko-credentials.json").unlink(missing_ok=True)
            elif action != "retry" or not (root / "glooko-credentials.json").exists():
                raise ValueError("Choose a configured Glooko connection")
            with database(root) as db:
                state = get_state(db, "glooko", {})
                state.update(next_attempt=0, error=None)
                put_state(db, "glooko", state)
        return redirect("/#glooko")

    @app.post("/import")
    def upload():
        file = request.files.get("export")
        if file is None:
            raise ValueError("Choose a CSV or ZIP export")
        zone = request.form.get("timezone", "UTC")
        if zone not in {"UTC", "Europe/Berlin"}:
            raise ValueError("Unsupported timezone")
        order = request.form.get("date_order", "day-first")
        if order not in {"day-first", "month-first"}:
            raise ValueError("Unsupported date order")
        records, skipped = parse_export(file.read(MAX_BYTES + 1), zone, order)
        with database(root) as db:
            inserted = import_records(db, records)
            build_report(db)
        return render_template(
            "message.html",
            title="Import complete",
            message=f"Added {inserted} records. Existing identical records were kept once. Import notices: {len(skipped)}. "
            + "; ".join(sorted(set(skipped))),
        )

    @app.post("/settings")
    def settings():
        low, high = number(request.form["low"]), number(request.form["high"])
        if not 20 <= low < high <= 500:
            raise ValueError("Check the analysis range, in mg/dL")
        service, light = (
            request.form.get("notify_service", ""),
            request.form.get("light_entity", ""),
        )
        if service and not re.fullmatch(r"mobile_app_[a-z0-9_]+", service):
            raise ValueError("Choose one mobile_app notification service")
        if light and not re.fullmatch(r"light\.[a-z0-9_]+", light):
            raise ValueError("Choose a light entity")
        minutes = int(request.form.get("high_minutes", 30))
        if not 15 <= minutes <= 240:
            raise ValueError("Reminder persistence must be between 15 and 240 minutes")
        unit = request.form.get("display_unit", "mg/dL")
        if unit not in {"mg/dL", "mmol/L"}:
            raise ValueError("Unsupported display unit")
        cfg = {
            "low": low,
            "high": high,
            "display_unit": unit,
            "notify_service": service,
            "light_entity": light,
            "high_minutes": minutes,
            **{
                k: request.form.get(k) == "on"
                for k in ("high_notifications", "night_light", "ai_enabled")
            },
        }
        with database(root) as db:
            for key, value in cfg.items():
                db.execute(
                    "INSERT OR REPLACE INTO settings VALUES (?,?)",
                    (key, json.dumps(value)),
                )
            put_state(db, "high", None)
            build_report(db)
        return redirect("/")

    @app.post("/action")
    def action():
        key = request.form.get("action_id", "")
        if not re.fullmatch(r"[a-zA-Z0-9-]{16,80}", key):
            raise ValueError("Reload the page before submitting")
        now = int(time.time())
        with database(root) as db:
            if not db.execute(
                "INSERT OR IGNORE INTO actions VALUES (?)", (key,)
            ).rowcount:
                return redirect("/")
            kind = request.form.get("action")
            if kind == "supply":
                item = request.form.get("kind")
                old = db.execute(
                    "SELECT * FROM supplies WHERE kind=?", (item,)
                ).fetchone()
                if old is None:
                    raise ValueError("Unknown supply")
                operation = request.form.get("operation")
                if operation == "change":
                    if old["stock"] <= 0:
                        raise ValueError(
                            "Set your stock count before recording a change"
                        )
                    db.execute(
                        "UPDATE supplies SET stock=stock-1,changed=?,site=? WHERE kind=?",
                        (now, request.form.get("site", "")[:100], item),
                    )
                elif operation == "configure":
                    stock, hours, lead = (
                        int(request.form["stock"]),
                        number(request.form["hours"]),
                        int(request.form["lead_days"]),
                    )
                    if not (
                        0 <= stock <= 1000 and 1 <= hours <= 720 and 0 <= lead <= 180
                    ):
                        raise ValueError(
                            "Check stock, replacement interval and delivery lead time"
                        )
                    db.execute(
                        "UPDATE supplies SET stock=?,hours=?,lead_days=? WHERE kind=?",
                        (stock, hours, lead, item),
                    )
                else:
                    raise ValueError("Unknown supply action")
                if operation == "configure" and stock > old["stock"]:
                    db.execute("DELETE FROM sent WHERE key=?", (f"stock:{item}",))
            elif kind == "note":
                text = request.form.get("text", "").strip()
                if not text or len(text) > 2000:
                    raise ValueError("Notes need 1 to 2000 characters")
                db.execute("INSERT INTO notes VALUES (?,?,?)", (key, now, text))
            elif kind == "appointment":
                ts = timestamp(request.form["at"], "Europe/Berlin")
                if ts <= now:
                    raise ValueError("Choose a future appointment")
                db.execute(
                    "INSERT INTO appointments VALUES (?,?,?)",
                    (key, ts, request.form.get("title", "Diabetes appointment")[:150]),
                )
            elif kind in {"delete_note", "delete_appointment"}:
                table = "notes" if kind == "delete_note" else "appointments"
                db.execute(f"DELETE FROM {table} WHERE id=?", (request.form["id"],))
            elif kind == "meal":
                operation = request.form.get("operation")
                meal = get_state(db, "meal")
                if operation == "start":
                    meal = {
                        "id": key,
                        "due": now,
                        "expires": now + 2 * 3600,
                        "done": False,
                    }
                elif meal and operation in {"done", "snooze"}:
                    if operation == "done":
                        meal["done"] = True
                    else:
                        meal["due"] = now + 5 * 60
                else:
                    raise ValueError("Start a meal check first")
                put_state(db, "meal", meal)
            else:
                raise ValueError("Unknown action")
        return redirect("/")

    @app.get("/api/glucose")
    def glucose():
        reading = dexcom.read()
        with database(root) as db:
            unit = get_settings(db)["display_unit"]
        if reading["available"]:
            reading["display_value"] = (
                round(reading["value"] / 18.0182, 1)
                if unit == "mmol/L"
                else round(reading["value"])
            )
            reading["unit"] = unit
        return jsonify(reading)

    @app.get("/live")
    def live():
        reading = glucose().get_json()
        return render_template("live.html", reading=reading), {"Refresh": "60"}

    @app.get("/plot.png")
    def plot():
        # Direct Figure objects avoid pyplot's shared global state in Waitress.
        from matplotlib.figure import Figure
        from matplotlib.dates import DateFormatter

        with database(root) as db:
            row = db.execute(
                "SELECT payload FROM reports WHERE week=?", (request.args.get("week"),)
            ).fetchone()
            if row is None:
                abort(404)
            report = json.loads(row[0])
            weeks = report["weeks"][:2]
            data = [
                db.execute(
                    "SELECT ts,value FROM records WHERE kind='cgm' AND ts>=? AND ts<? ORDER BY ts",
                    (w["start"], w["end"]),
                ).fetchall()
                for w in weeks
            ]
        figure = Figure(figsize=(12, 5), layout="constrained", facecolor="#232136")
        maximum = max(400, max((r[1] for rows in data for r in rows), default=0) + 20)
        for axis, week, rows in zip(figure.subplots(2, 1), weeks, data, strict=True):
            axis.set_facecolor("#2a273f")
            axis.axhspan(report["low"], report["high"], color="#9ccfd8", alpha=0.1)
            xs, ys, last = [], [], None
            for ts, val in rows:
                if last is not None and ts - last > 300:
                    xs.append(datetime.fromtimestamp(last + 1, BERLIN))
                    ys.append(float("nan"))
                xs.append(datetime.fromtimestamp(ts, BERLIN))
                ys.append(val)
                last = ts
            axis.plot(xs, ys, color="#9ccfd8", linewidth=0.8)
            axis.set_xlim(
                datetime.fromtimestamp(week["start"], BERLIN),
                datetime.fromtimestamp(week["end"], BERLIN),
            )
            axis.set_ylim(0, maximum)
            axis.set_ylabel("mg/dL", color="#e0def4")
            axis.set_title(
                f"Week of {week['label']} · {week['coverage']}% coverage",
                color="#e0def4",
                loc="left",
            )
            axis.tick_params(colors="#e0def4")
            axis.xaxis.set_major_formatter(DateFormatter("%a %d", tz=BERLIN))
        output = io.BytesIO()
        figure.savefig(output, format="png", dpi=120)
        output.seek(0)
        return send_file(output, mimetype="image/png")

    @app.post("/api/tick")
    def jobs():
        return jsonify(tick())

    @app.get("/report.json")
    def report_json():
        with database(root) as db:
            row = db.execute(
                "SELECT payload FROM reports ORDER BY week DESC LIMIT 1"
            ).fetchone()
            return jsonify(json.loads(row[0]) if row else {})

    @app.template_filter("localtime")
    def localtime(value):
        return (
            datetime.fromtimestamp(value, BERLIN).strftime("%d %b %Y, %H:%M")
            if value
            else "Not recorded"
        )

    return app


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["serve", "tick", "sync-glooko"])
    parser.add_argument("--port", type=int, default=8503)
    args = parser.parse_args()
    application = create_app()
    if args.command == "sync-glooko":
        from glooko_sync import sync

        print(sync(application.config["ROOT"]))
    elif args.command == "tick":
        print(json.dumps(application.extensions["tick"]()))
    else:
        from waitress import serve

        serve(
            application,
            host="127.0.0.1",
            port=args.port,
            threads=4,
            max_request_body_size=MAX_BYTES,
        )
