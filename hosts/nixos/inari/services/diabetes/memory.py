"""Deterministic evidence cards from a bounded set of weekly summaries."""

import hashlib
import json


def _digest(value):
    encoded = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    )
    return hashlib.sha256(encoded.encode()).hexdigest()


def _fact(identifier, kind, text, evidence):
    result = {"id": identifier, "kind": kind, "text": text, "evidence": evidence}
    result["revision"] = _digest(result)
    return result


def _week_evidence(week, metric=None):
    entry = {
        "label": week["label"],
        "coverage": week["coverage"],
        "observed_hours": week["observed_hours"],
    }
    if metric is not None:
        entry["metric_percent"] = week[metric]
    return entry


def _weighted_percent(weeks, metric):
    total_hours = sum(week["observed_hours"] for week in weeks)
    return sum(week[metric] * week["observed_hours"] for week in weeks) / total_hours


def _trend_facts(weeks, low, high):
    facts = []
    metrics = (
        ("in_percent", "time in range"),
        ("above_percent", "time above range"),
        ("below_percent", "time below range"),
    )
    for metric, description in metrics:
        blocks = []
        for block in (weeks[:4], weeks[4:8]):
            eligible = [
                week
                for week in block
                if week["coverage"] >= 70 and week["observed_hours"] > 0
            ]
            if len(eligible) < 3:
                break
            blocks.append(eligible)
        if len(blocks) != 2:
            continue
        recent, prior = (_weighted_percent(block, metric) for block in blocks)
        delta = recent - prior
        evidence = {
            "recent_weeks": [_week_evidence(week, metric) for week in blocks[0]],
            "prior_weeks": [_week_evidence(week, metric) for week in blocks[1]],
            "recent_percent": round(recent, 1),
            "prior_percent": round(prior, 1),
            "delta_percentage_points": round(delta, 1) or 0.0,
            "low": low,
            "high": high,
            "method": "observed-hours-weighted weekly percentages",
        }
        if round(delta, 1) == 0:
            change = f"remained unchanged at the displayed precision ({recent:.1f}%)"
        elif delta > 0:
            change = f"increased (+{delta:.1f} percentage points) from {prior:.1f}% to {recent:.1f}%"
        else:
            change = f"decreased ({delta:.1f} percentage points) from {prior:.1f}% to {recent:.1f}%"
        text = (
            f"{description.capitalize()} {change}, comparing the latest four calendar weeks "
            f"({len(blocks[0])}/4 eligible) with the prior four ({len(blocks[1])}/4 eligible)."
        )
        facts.append(_fact(f"memory_trend_{metric}", "trend", text, evidence))
    return facts


def _recurrence_facts(weeks, low, high):
    facts = []
    for direction, date_key, id_part, threshold_key in (
        ("above", "high_dates", "above", "above_minutes"),
        ("below", "low_dates", "below", "below_minutes"),
    ):
        for hour in range(24):
            eligible = []
            matched = []
            for index, week in enumerate(weeks):
                if week["coverage"] < 70:
                    continue
                hourly = next(
                    (entry for entry in week["hourly"] if entry["hour"] == hour), None
                )
                if hourly is None or hourly["observed_minutes"] < 120:
                    continue
                dates = sorted(set(hourly[date_key]))
                is_match = len(dates) >= 3 and hourly[threshold_key] >= 45
                item = {
                    "label": week["label"],
                    "coverage": week["coverage"],
                    "hour_observed_minutes": hourly["observed_minutes"],
                    "range_minutes": hourly[threshold_key],
                    "matched_date_count": len(dates),
                    "matched": is_match,
                    "dates": dates,
                    "week_index": index,
                }
                eligible.append(item)
                if is_match:
                    matched.append(item)
            if len(matched) < 3:
                continue
            recent_count = sum(
                item["matched"] for item in eligible if item["week_index"] < 4
            )
            prior_count = sum(
                item["matched"] for item in eligible if 4 <= item["week_index"] < 8
            )
            recent_eligible = sum(item["week_index"] < 4 for item in eligible)
            prior_eligible = sum(4 <= item["week_index"] < 8 for item in eligible)
            latest = matched[0]
            evidence = {
                "weeks": [
                    {
                        key: value
                        for key, value in item.items()
                        if key not in ("week_index", "dates")
                    }
                    for item in eligible
                ],
                "latest_matched_week": latest["label"],
                "recent_four_calendar_weeks": {
                    "matched": recent_count,
                    "eligible": recent_eligible,
                },
                "prior_four_calendar_weeks": {
                    "matched": prior_count,
                    "eligible": prior_eligible,
                },
                "low": low,
                "high": high,
            }
            text = (
                f"{direction.capitalize()} range readings recurred during Berlin time "
                f"{hour:02d}:00–{(hour + 1) % 24:02d}:00 "
                f"in {len(matched)} of {len(eligible)} eligible weeks; the latest matched week was "
                f"{latest['label']}. Recent four calendar weeks: {recent_count}/{recent_eligible} matched; "
                f"prior four: {prior_count}/{prior_eligible} matched."
            )
            card = _fact(
                f"memory_recur_{id_part}_{hour:02d}", "recurrence", text, evidence
            )
            card["_retrieval"] = {
                "latest_index": latest["week_index"],
                "recent_matches": sum(
                    item["matched"] and item["week_index"] < 4 for item in eligible
                ),
                "total_matches": len(matched),
            }
            facts.append(card)
    return facts


def build_memory(weeks, low=70, high=180):
    """Build versioned, deterministic cards from newest-first weekly summaries."""
    weeks = list(weeks[:26])
    facts = _trend_facts(weeks, low, high) + _recurrence_facts(weeks, low, high)
    trends = [fact for fact in facts if fact["kind"] == "trend"]
    recurrences = [fact for fact in facts if fact["kind"] == "recurrence"]
    recurrences.sort(
        key=lambda fact: (
            0
            if fact["_retrieval"]["latest_index"] == 0
            else 1
            if fact["_retrieval"]["latest_index"] < 4
            else 2,
            -fact["_retrieval"]["total_matches"],
            fact["id"],
        )
    )
    selected = (trends + recurrences)[:6]
    retrieved_ids = [fact["id"] for fact in selected]
    public_facts = [
        {key: value for key, value in fact.items() if not key.startswith("_")}
        for fact in facts
    ]
    payload = {
        "schema": 1,
        "window_weeks": 26,
        "available_weeks": sum(week["coverage"] > 0 for week in weeks),
        "eligible_weeks": sum(week["coverage"] >= 70 for week in weeks),
        "facts": public_facts,
        "retrieved_ids": retrieved_ids,
    }
    payload["revision"] = _digest({"memory": payload, "source_weeks": weeks})
    return payload
