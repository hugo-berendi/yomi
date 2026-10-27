"""A short, accessible weekly brief, built only from calculated evidence."""

import hashlib
import os
import re
from datetime import datetime, timedelta
from email.message import EmailMessage
from email.utils import format_datetime
from pathlib import Path
from urllib.parse import urlsplit

from jinja2 import Environment, FileSystemLoader, select_autoescape

from analysis import BERLIN
from app import QUESTIONS
from report_charts import charts


def number(value, unit="", digits=1):
    return "Unavailable" if value is None else f"{value:.{digits}f}{unit}"


def change(current, previous, key, unit=" pp"):
    a, b = current.get(key), previous.get(key)
    if a is None or b is None:
        return "No comparison"
    delta = round(a - b, 1)
    return "Unchanged" if delta == 0 else f"{delta:+.1f}{unit} vs prior week"


def presentation(report, selected, quality):
    current, previous = report["weeks"][:2]
    start = current["label"]
    end = datetime.fromtimestamp(current["end"], BERLIN).date() - timedelta(days=1)
    tiles = [
        dict(
            label=label,
            value=number(current.get(key), unit, digits),
            delta=change(current, previous, key, delta_unit),
            tone=tone,
        )
        for key, label, unit, digits, delta_unit, tone in (
            ("in_percent", "Time in range", "%", 1, " pp", "teal"),
            ("below_percent", "Time below range", "%", 1, " pp", "coral"),
            ("mean", "Average glucose", " mg/dL", 0, " mg/dL", "ink"),
            ("coverage", "Glucose coverage", "%", 1, " pp", "ink"),
        )
    ]
    highlights = []
    if current.get("below_percent") is not None and current["low_episodes"]:
        prior_episodes = (
            str(previous["low_episodes"])
            if previous["observed_hours"]
            else "unavailable"
        )
        episode_label = "episode" if current["low_episodes"] == 1 else "episodes"
        highlights.append(
            dict(
                title="Low-glucose periods",
                text=f"{current['low_episodes']} {episode_label} below {report['low']} mg/dL lasting at least 15 minutes; {prior_episodes} in the prior week. Counts depend on coverage.",
                tone="coral",
            )
        )
    if current["coverage"] < 90:
        highlights.append(
            dict(
                title="Gaps in this week's view",
                text=f"{100 - current['coverage']:.1f}% of the week has no glucose coverage. Percentages describe observed time only.",
                tone="ink",
            )
        )
    pattern_candidates = []
    for kind, key in (("low", "below_minutes"), ("high", "above_minutes")):
        for hour in current["hourly"]:
            dates = len(set(hour[kind + "_dates"]))
            if dates >= 3 and hour["observed_minutes"] >= 120:
                pattern_candidates.append((kind == "low", dates, hour[key], kind, hour))
    if pattern_candidates:
        _, dates, _, kind, hour = max(pattern_candidates, key=lambda row: row[:3])
        at = hour["hour"]
        highlights.append(
            dict(
                title="A recurring hour to review",
                text=f"{kind.capitalize()} readings during {at:02d}:00 to {(at + 1) % 24:02d}:00 on {dates} dates. {hour['observed_minutes']:.0f} observed minutes in that hour across the week. Uneven coverage can affect this pattern.",
                tone="coral" if kind == "low" else "ink",
            )
        )
    if not highlights:
        highlights.append(
            dict(
                title="No recurring hour met the review threshold",
                text="No hourly high or low pattern was observed on at least three dates with 120 observed minutes in that hour across the week.",
                tone="ink",
            )
        )
    memory = report.get("memory", {})
    trends = []
    for card in memory.get("facts", []):
        if card.get("kind") != "trend":
            continue
        labels = {
            "memory_trend_in_percent": "In range",
            "memory_trend_below_percent": "Below range",
            "memory_trend_above_percent": "Above range",
        }
        if card["id"] not in labels:
            continue
        evidence = card["evidence"]
        trends.append(
            dict(
                id=card["id"],
                label=labels[card["id"]],
                prior=number(evidence["prior_percent"], "%"),
                recent=number(evidence["recent_percent"], "%"),
                delta=f"{evidence['delta_percentage_points']:+.1f} pp",
                eligible=f"{len(evidence['recent_weeks'])}/4 recent, {len(evidence['prior_weeks'])}/4 prior weeks eligible",
            )
        )
    selected_ids = selected.get("fact_ids", []) if selected else []
    trends.sort(
        key=lambda row: next(
            (i for i, identifier in enumerate(selected_ids) if identifier == row["id"]),
            len(selected_ids),
        )
    )
    notices = [
        f"Coverage {number(current['coverage'], '%')}: {number(current['observed_hours'], ' hours')} observed out of {(current['end'] - current['start']) / 3600:.0f} hours. Missing time is not filled."
    ]
    timing = report.get("data_quality", {})
    held_cgm, held_bolus = (
        timing.get("quarantined_cgm_groups", 0),
        timing.get("quarantined_bolus_groups", 0),
    )
    timestamp_attention = bool(held_cgm or held_bolus)
    if timestamp_attention:
        notices.append(
            f"Timestamp verification pending: {held_cgm} CGM timestamp groups and {held_bolus} bolus timestamp groups remain excluded across stored history. Original entries are retained privately; time passing does not release them."
        )
    if not report.get("comparable"):
        notices.append(
            "Limited comparison: at least one week has less than 70% glucose coverage."
        )
    quality = list(quality or [])
    sync_attention = any(
        "local login" in q or "authentication required" in q or "verification code" in q
        for q in quality
    )
    if any(
        "sync did not finish" in q or "synchronization status: failed" in q
        for q in quality
    ):
        notices.append(
            "The latest Glooko refresh failed. This report uses stored history."
        )
    exclusions = {}
    for text in quality:
        match = re.match(r"Excluded (\d+) (CGM|bolus) entries with ambiguous", text)
        if match:
            exclusions[match[2]] = exclusions.get(match[2], 0) + int(match[1])
        elif "unsupported code 2001" in text:
            notices.append(
                "Unsupported glucose codes were excluded and leave coverage gaps."
            )
    if exclusions:
        notices.append(
            "Clock-change timestamps without offsets excluded: "
            + ", ".join(f"{count} {kind}" for kind, count in exclusions.items())
            + ". Original exports are retained privately."
        )
    sources = [
        dict(
            label=label,
            current=number(current.get(key), unit, digits),
            previous=number(previous.get(key), unit, digits),
        )
        for key, label, unit, digits in (
            ("recorded_bolus_units", "Recorded delivered bolus", " U", 1),
            ("recorded_carbs_g", "Carbs recorded with boluses", " g", 0),
            ("cv", "Glucose variability / CV", "%", 1),
        )
    ]
    question_ids = (
        selected.get("question_ids", []) if selected else ["patterns", "lows"]
    )
    if timestamp_attention:
        question_ids = ["timestamps"] + question_ids
    questions = [
        QUESTIONS[key] for key in dict.fromkeys(question_ids) if key in QUESTIONS
    ][:2]
    public_url = os.environ.get("PUBLIC_URL", "")
    parts = urlsplit(public_url)
    public_url = (
        public_url
        if parts.scheme == "https"
        and parts.hostname
        and not parts.username
        and not parts.query
        else ""
    )
    return dict(
        start=start,
        end=str(end),
        tiles=tiles,
        highlights=highlights[:3],
        trends=trends,
        memory=memory,
        notices=list(dict.fromkeys(notices)),
        sources=sources,
        questions=questions,
        sync_attention=sync_attention,
        timestamp_attention=timestamp_attention,
        ai_available=bool(selected),
        url=public_url,
        low=report["low"],
        high=report["high"],
        above=number(current.get("above_percent"), "%"),
        night=current["periods"]["night"],
        cv=number(current.get("cv"), "%"),
    )


def render(report, config, now, selected=None, quality=None):
    view = presentation(report, selected, quality)
    lines = [
        f"Weekly diabetes review: {view['start']} to {view['end']}",
        "Europe/Berlin. Glucose in mg/dL.",
    ]
    if view["sync_attention"]:
        lines.append(
            "Glooko sign-in needs attention. This report uses stored history; reconnect through your private journal."
        )
    elif view["timestamp_attention"]:
        lines.append(
            "Some source timestamps need verification. Flagged entries are excluded; valid history is included."
        )
    lines += [
        f"{tile['label']}: {tile['value']}. {tile['delta']}." for tile in view["tiles"]
    ]
    lines += [f"{item['title']}: {item['text']}" for item in view["highlights"]]
    lines += [
        f"Above range: {view['above']}. Overnight, 00:00 to 06:00: {number(view['night']['above_percent'], '%')} above range over {number(view['night']['observed_hours'], ' observed hours')}."
    ]
    if view["trends"]:
        lines.append(
            "Longer view: latest four calendar weeks vs prior four. At least three weeks per block require 70% coverage."
        )
        lines += [
            f"{row['label']}: {row['prior']} to {row['recent']} ({row['delta']}); {row['eligible']}."
            for row in view["trends"]
        ]
    else:
        lines.append(
            "Longer view: not enough covered history for a four-week comparison."
        )
    lines += [
        f"{row['label']}: {row['current']}; prior week {row['previous']}."
        for row in view["sources"]
    ]
    lines += ["Data quality"] + view["notices"]
    lines += [
        "Totals cover supported records only. Actual automated basal delivery and total daily insulin are unavailable; programmed settings are never used as delivery. Absent bolus/carbohydrate entries do not prove zero delivery or intake. Identical events without IDs may merge.",
        "Each reading covers at most five minutes. Clock-change entries without an unambiguous offset are excluded. Hourly patterns use observed time only and do not establish a cause.",
    ]
    if not selected:
        lines.append(
            "Local AI unavailable, disabled or insufficient comparison coverage. Calculated findings shown."
        )
    lines += ["Questions for your diabetes team"] + view["questions"]
    lines.append("Retrospective review. No dosing recommendations or pump control.")
    if view["url"]:
        lines.append("Full private report: " + view["url"])
    message = EmailMessage()
    message["Subject"] = f"Weekly diabetes review · {view['start']}"
    message["From"], message["To"] = config["sender"], config["recipient"]
    message["Date"] = format_datetime(now)
    digest = hashlib.sha256(f"diabetes-weekly:{view['start']}".encode()).hexdigest()[
        :32
    ]
    message["Message-ID"] = f"<{digest}@{config['sender'].split('@')[1]}>"
    message.set_content("\n\n".join(lines))
    environment = Environment(
        loader=FileSystemLoader(Path(__file__).parent / "templates"),
        autoescape=select_autoescape(),
    )
    message.add_alternative(
        environment.get_template("weekly_email.html").render(**view), subtype="html"
    )
    for name, payload in charts(report).items():
        message.get_payload()[-1].add_related(
            payload, maintype="image", subtype="png", cid=f"<{name}>"
        )
    return message
