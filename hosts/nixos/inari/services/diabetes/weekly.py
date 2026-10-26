"""Weekly mail using the existing journal and a durable at-most-once outbox."""

import fcntl
import hashlib
import html
import io
import json
import os
import re
import smtplib
import ssl
from datetime import UTC, datetime, timedelta
from email.message import EmailMessage
from email.utils import format_datetime
from pathlib import Path

from analysis import BERLIN, week_bounds
from app import (
    QUESTIONS,
    ai_review,
    build_report,
    database,
    get_settings,
    get_state,
    snapshot_database,
)
from glooko_sync import sync


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


def chart(report):
    from matplotlib.figure import Figure

    figure = Figure(figsize=(7, 3.8), layout="constrained")
    axes = figure.subplots(2, 1)
    for week, label, color in zip(
        report["weeks"][:2],
        ("Last week", "Previous week"),
        ("#3e8fb0", "#908caa"),
        strict=True,
    ):
        hours = week["hourly"]
        for axis, category in zip(axes, ("above", "below"), strict=True):
            values = [
                h[f"{category}_minutes"] / h["observed_minutes"] * 100
                if h["observed_minutes"]
                else float("nan")
                for h in hours
            ]
            axis.plot(range(24), values, label=label, color=color)
            axis.set_ylabel(f"{category.title()} range (%)")
            axis.set_ylim(0, 100)
            axis.set_xticks(range(0, 24, 3))
    axes[0].legend()
    axes[1].set_xlabel("Hour in Europe/Berlin; gaps mean no observations")
    output = io.BytesIO()
    figure.savefig(output, format="png", dpi=120)
    return output.getvalue()


def render(report, config, now, selected=None, quality=None):
    current, previous = report["weeks"][:2]
    end = datetime.fromtimestamp(current["end"], BERLIN).date() - timedelta(days=1)
    lines = [
        f"Weekly diabetes review: {current['label']} to {end}",
        "Europe/Berlin. Glucose in mg/dL.",
        f"Configured analysis range: {report['low']}–{report['high']} mg/dL.",
    ]
    rows = []
    for key, title in (
        ("coverage", "Glucose coverage (%)"),
        ("observed_hours", "Observed hours"),
        ("in_percent", "Time in range (%)"),
        ("below_percent", "Time below range (%)"),
        ("above_percent", "Time above range (%)"),
        ("mean", "Mean glucose (mg/dL)"),
        ("cv", "Coefficient of variation (%)"),
        ("high_episodes", "High episodes, at least 15 minutes"),
        ("low_episodes", "Low episodes, at least 15 minutes"),
        ("recorded_boluses", "Recorded bolus count"),
        ("recorded_bolus_units", "Recorded delivered bolus insulin (U)"),
        ("recorded_carbs_g", "Carbs recorded with boluses (g)"),
        ("boluses_with_carbs", "Boluses with carbohydrate data"),
    ):
        values = [
            "Unavailable" if week[key] is None else f"{week[key]:.2f}"
            for week in (current, previous)
        ]
        lines.append(f"{title}: {values[0]}; previous week: {values[1]}.")
        rows.append((title, *values))
    for period in ("night", "day"):
        stats = current["periods"][period]
        lines.append(
            f"{period.title()} (night = 00:00–06:00 Berlin): {stats['observed_hours']} observed hours; {stats['above_percent']}% above range."
        )
    for hour in current["hourly"]:
        for kind in ("high", "low"):
            dates = hour[f"{kind}_dates"]
            if len(dates) >= 3:
                lines.append(
                    f"Recurring {kind} observations at {hour['hour']:02d}:00–{hour['hour'] + 1:02d}:00 on {len(dates)} dates. Observed time in this hour: {hour['observed_minutes']:.0f} minutes. Uneven coverage can bias this pattern."
                )
    memory = report.get("memory")
    if memory is not None:
        lines.append(
            f"Long-term memory: {memory['available_weeks']} weeks with glucose observations in the last {memory['window_weeks']} completed weeks; {memory['eligible_weeks']} meet the 70% weekly coverage gate. Earlier history remains stored. Missing weeks are unknown, not zero."
        )
        lines.append(
            "Long-term trend cards need at least three covered weeks in each four-calendar-week block. Recurring-hour cards need at least 120 observed minutes in that hour per week, out-of-range readings on at least three dates totalling 45 minutes, and detection in at least three weeks. These are descriptive review thresholds, not clinical significance tests. Berlin clock-change hours use actual observed time."
        )
    lines += [f["text"] for f in report["facts"]]
    lines += [
        "Actual automated basal delivery and total daily insulin: unavailable. Programmed basal settings are never used as delivery.",
        "Bolus and carbohydrate totals describe supported records only; absent entries do not prove zero delivery or zero intake. Identical events without identifiers may collapse during deduplication.",
        "Coverage uses actual elapsed time, including daylight-saving changes. Each CGM reading covers at most the next five minutes. No gaps are filled. Recurring observations do not establish their cause.",
    ]
    lines.extend(quality or [])
    if selected:
        lines.append("Local Qwen review, selected from verified findings:")
        lines += [f["text"] for f in report["facts"] if f["id"] in selected["fact_ids"]]
        lines += [QUESTIONS[key] for key in selected["question_ids"]]
    else:
        lines.append(
            "Local AI unavailable, disabled or insufficient comparison coverage. The calculated report is unchanged."
        )
        lines += [QUESTIONS["patterns"], QUESTIONS["lows"]]
    lines.append(
        "Retrospective review for discussion with your diabetes team. No dosing recommendations or pump control."
    )
    message = EmailMessage()
    message["Subject"] = f"Weekly diabetes review · {current['label']}"
    message["From"] = config["sender"]
    message["To"] = config["recipient"]
    message["Date"] = format_datetime(now)
    digest = hashlib.sha256(f"diabetes-weekly:{current['label']}".encode()).hexdigest()[
        :32
    ]
    message["Message-ID"] = f"<{digest}@{config['sender'].split('@')[1]}>"
    message.set_content("\n\n".join(lines))
    body = '<table role="presentation" width="600" style="width:100%;max-width:600px;background:#232136;color:#e0def4;font:14px Verdana,sans-serif"><tr><td style="padding:20px">'
    body += f'<h1 style="color:#c4a7e7;font-size:22px">{html.escape(lines[0])}</h1>'
    body += '<table width="100%" style="border-collapse:collapse"><tr><th align="left">Measure</th><th>Last week</th><th>Previous</th></tr>'
    for row in rows:
        body += (
            "<tr>"
            + "".join(
                f'<td style="padding:7px;border-bottom:1px solid #393552">{html.escape(value)}</td>'
                for value in row
            )
            + "</tr>"
        )
    body += '</table><p><img src="cid:hourly-patterns" width="560" alt="Hourly percentages above and below the configured range, last week compared with previous week. Figures are also described in the text." style="width:100%;max-width:560px"></p>'
    body += "".join(
        f"<p>{html.escape(line)}</p>" for line in lines[1:3] + lines[3 + len(rows) :]
    )
    body += "</td></tr></table>"
    message.add_alternative(body, subtype="html")
    message.get_payload()[-1].add_related(
        chart(report), maintype="image", subtype="png", cid="<hourly-patterns>"
    )
    return message


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
            except Exception:
                pass
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
