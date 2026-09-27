"""Deterministic, retrospective CGM summaries. No treatment recommendations."""

import csv
import hashlib
import io
import json
import math
import re
import zipfile
from datetime import UTC, datetime, time, timedelta
from zoneinfo import ZoneInfo

BERLIN = ZoneInfo("Europe/Berlin")
MAX_BYTES = 20 * 1024 * 1024


def number(value):
    result = float(str(value).strip().replace(",", "."))
    if not math.isfinite(result):
        raise ValueError("Non-finite number")
    return result


def timestamp(value, zone="UTC", date_order="day-first"):
    value = value.strip()
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        formats = ["%d.%m.%Y %H:%M:%S", "%d.%m.%Y %H:%M"]
        prefix = "%d/%m/%Y" if date_order == "day-first" else "%m/%d/%Y"
        formats += [prefix + " %H:%M:%S", prefix + " %H:%M", prefix + " %I:%M:%S %p"]
        result = None
        for fmt in formats:
            try:
                result = datetime.strptime(value, fmt)
                break
            except ValueError:
                continue
        if result is None:
            raise ValueError(
                "Unrecognized timestamp; use ISO 8601 or a supported date format"
            )
    if result.tzinfo is None:
        tz = ZoneInfo(zone)
        first, second = (
            result.replace(tzinfo=tz, fold=0),
            result.replace(tzinfo=tz, fold=1),
        )
        if first.utcoffset() != second.utcoffset():
            raise ValueError(
                "Ambiguous/nonexistent local time; export UTC or explicit offsets"
            )
        result = first
    return int(result.timestamp())


def normalize(value):
    return re.sub(r"\s+", " ", value.strip().lower().replace("\ufeff", ""))


def parse_export(payload, zone="UTC", date_order="day-first"):
    """Read a ZIP in memory, never extract paths or retain names/serial numbers.

    CGM and bolus file families are deliberately narrow. Unknown CSVs are
    reported, not interpreted as glucose or delivered insulin by position.
    """
    if len(payload) > MAX_BYTES:
        raise ValueError("Upload exceeds 20 MiB")
    files = []
    if zipfile.is_zipfile(io.BytesIO(payload)):
        with zipfile.ZipFile(io.BytesIO(payload)) as archive:
            members = [m for m in archive.infolist() if not m.is_dir()]
            if len(members) > 100 or sum(m.file_size for m in members) > MAX_BYTES:
                raise ValueError("Expanded archive exceeds the import limits")
            for member in members:
                if member.filename.lower().endswith(".csv"):
                    files.append(
                        (member.filename.rsplit("/", 1)[-1], archive.read(member))
                    )
    else:
        files = [("upload.csv", payload)]
    records, skipped = [], []
    for filename, data in files:
        text = data.decode("utf-8-sig")
        delimiter = ";" if text.count(";") > text.count(",") else ","
        rows = list(csv.reader(io.StringIO(text), delimiter=delimiter))
        header_at = next(
            (
                i
                for i, r in enumerate(rows[:30])
                if "timestamp" in [normalize(c) for c in r]
            ),
            None,
        )
        if header_at is None:
            skipped.append("CSV without a supported timestamp header")
            continue
        headers = [normalize(c) for c in rows[header_at]]
        glucose = next(
            (
                h
                for h in headers
                if h
                in {
                    "glucose (mg/dl)",
                    "glucose value (mg/dl)",
                    "glucose (mmol/l)",
                    "glucose value (mmol/l)",
                }
            ),
            None,
        )
        bolus = next(
            (
                h
                for h in headers
                if h
                in {
                    "insulin delivered (u)",
                    "bolus volume delivered (u)",
                    "insulin (u)",
                }
            ),
            None,
        )
        # BG fingersticks must not inflate CGM coverage. Generic uploads need
        # a type column explicitly marking CGM versus bolus.
        cgm_file = filename.lower().startswith("cgm")
        bolus_file = filename.lower().startswith("bolus")
        if not ((glucose and cgm_file) or (bolus and bolus_file) or "type" in headers):
            skipped.append("CSV outside supported CGM/bolus schema")
            continue
        for line_no, values in enumerate(rows[header_at + 1 :], header_at + 2):
            if not any(v.strip() for v in values):
                continue
            if len(values) != len(headers):
                raise ValueError(f"Malformed CSV row {line_no}; nothing was imported")
            row = dict(zip(headers, values, strict=True))
            kind = normalize(row.get("type", "cgm" if cgm_file else "bolus"))
            if kind not in {"cgm", "bolus"}:
                continue
            column = glucose if kind == "cgm" else bolus
            if not column:
                raise ValueError(
                    "Recognized event without an explicit glucose/delivered-insulin column"
                )
            ts = timestamp(row["timestamp"], zone, date_order)
            val = number(row[column])
            if kind == "cgm" and "mmol/l" in column:
                val *= 18.0182
            if not (0 < val <= 1000 if kind == "cgm" else 0 <= val <= 200):
                raise ValueError(f"Out-of-bounds value at row {line_no}")
            carbs = next(
                (
                    number(row[h])
                    for h in ("carbs (g)", "carbs input (g)", "carbohydrates (g)")
                    if row.get(h, "").strip()
                ),
                None,
            )
            if carbs is not None and not 0 <= carbs <= 1000:
                raise ValueError("Out-of-bounds recorded carbs")
            records.append((kind, ts, round(val, 5), carbs))
    if not records:
        raise ValueError(
            "No supported records. Export CGM/bolus CSVs or use the documented normalized schema."
        )
    return records, skipped


def week_bounds(now=None, offset=0):
    today = (now or datetime.now(UTC)).astimezone(BERLIN).date()
    end_date = today - timedelta(days=today.weekday() + 7 * offset)
    start_date = end_date - timedelta(days=7)
    return tuple(
        int(datetime.combine(d, time(), BERLIN).timestamp())
        for d in (start_date, end_date)
    )


def weekly_summary(readings, boluses, start, end, low=70, high=180):
    """Each reading covers at most five minutes; gaps remain unobserved.

    Intervals split at actual local-hour boundaries, including DST. Episodes
    stop at missing data and require 15 observed consecutive minutes high.
    """
    weights = []
    periods = {"day": [0.0, 0.0], "night": [0.0, 0.0]}
    range_seconds = {"below": 0, "in": 0, "above": 0}
    daily = {}
    episodes = []
    episode = None
    for i, (ts, val) in enumerate(readings):
        right = min(
            ts + 300, readings[i + 1][0] if i + 1 < len(readings) else ts + 300, end
        )
        left = max(ts, start)
        if right <= left:
            continue
        duration = right - left
        weights.append((val, duration))
        category = "below" if val < low else "above" if val > high else "in"
        range_seconds[category] += duration
        cursor = left
        while cursor < right:
            local = datetime.fromtimestamp(cursor, BERLIN)
            boundary = min(right, cursor + 3600 - local.minute * 60 - local.second)
            segment = boundary - cursor
            period = "night" if local.hour < 6 else "day"
            periods[period][0] += segment
            periods[period][1] += segment if category == "above" else 0
            day = daily.setdefault(local.date().isoformat(), [0, 0])
            day[0] += segment
            day[1] += segment if category == "in" else 0
            cursor = boundary
        if category == "above":
            if episode and episode[1] == left:
                episode[1] = right
            else:
                if episode:
                    episodes.append(episode)
                episode = [left, right]
        elif episode:
            episodes.append(episode)
            episode = None
    if episode:
        episodes.append(episode)
    episodes = [e for e in episodes if e[1] - e[0] >= 900]
    observed = sum(w for _, w in weights)
    mean = sum(v * w for v, w in weights) / observed if observed else None
    sd = (
        math.sqrt(sum(w * (v - mean) ** 2 for v, w in weights) / observed)
        if observed
        else None
    )
    selected_boluses = [
        dict(timestamp=t, units=v, carbs=c) for t, v, c in boluses if start <= t < end
    ]
    # These are associations with high-episode starts, never meal detection.
    review = []
    for left, right in sorted(episodes, key=lambda e: e[1] - e[0], reverse=True)[:5]:
        recorded = [
            b
            for b in selected_boluses
            if left <= b["timestamp"] <= min(right, left + 3600)
        ]
        review.append(
            {
                "start": left,
                "end": right,
                "minutes": (right - left) / 60,
                "boluses_within_first_hour": recorded,
            }
        )
    return {
        "start": start,
        "end": end,
        "label": datetime.fromtimestamp(start, BERLIN).date().isoformat(),
        "coverage": round(observed / (end - start) * 100, 2),
        "observed_hours": round(observed / 3600, 2),
        "mean": round(mean, 2) if mean is not None else None,
        "cv": round(sd / mean * 100, 2) if mean else None,
        **{
            f"{k}_percent": round(v / observed * 100, 2) if observed else None
            for k, v in range_seconds.items()
        },
        "high_hours": round(range_seconds["above"] / 3600, 2),
        "high_episodes": len(episodes),
        "longest_high_minutes": max(((b - a) / 60 for a, b in episodes), default=0)
        if observed
        else None,
        "periods": {
            k: {
                "observed_hours": round(v[0] / 3600, 2),
                "above_percent": round(v[1] / v[0] * 100, 2) if v[0] else None,
            }
            for k, v in periods.items()
        },
        "daily": [
            {
                "date": d,
                "in_percent": round(v[1] / v[0] * 100, 2),
                "observed_hours": round(v[0] / 3600, 2),
            }
            for d, v in sorted(daily.items())
        ],
        "recorded_boluses": len(selected_boluses),
        "review_events": review,
    }


def comparison(readings, boluses, now=None, low=70, high=180):
    weeks = [
        weekly_summary(readings, boluses, *week_bounds(now, i), low, high)
        for i in range(4)
    ]
    current, previous = weeks[:2]
    deltas = {
        k: round(current[k] - previous[k], 2)
        if current[k] is not None and previous[k] is not None
        else None
        for k in (
            "coverage",
            "mean",
            "cv",
            "in_percent",
            "above_percent",
            "below_percent",
            "high_hours",
            "high_episodes",
            "longest_high_minutes",
        )
    }
    comparable = min(current["coverage"], previous["coverage"]) >= 70
    facts = []
    if comparable:
        for k, label in (
            ("in_percent", "Time in range"),
            ("above_percent", "Time above range"),
            ("below_percent", "Time below range"),
        ):
            facts.append(
                {
                    "id": k,
                    "text": f"{label}: {current[k]:.1f}% versus {previous[k]:.1f}% ({deltas[k]:+.1f} percentage points).",
                }
            )
    facts.append(
        {
            "id": "coverage",
            "text": f"Coverage: {current['coverage']:.1f}% this week and {previous['coverage']:.1f}% last week. Missing periods are not filled in.",
        }
    )
    facts.append(
        {
            "id": "meal_uncertainty",
            "text": "Recorded boluses do not establish meal times. These data cannot prove that a meal bolus was forgotten or late.",
        }
    )
    report = {
        "weeks": weeks,
        "deltas": deltas,
        "comparable": comparable,
        "low": low,
        "high": high,
        "facts": facts,
        "schema": 1,
    }
    report["revision"] = hashlib.sha256(
        json.dumps(report, sort_keys=True).encode()
    ).hexdigest()
    return report
