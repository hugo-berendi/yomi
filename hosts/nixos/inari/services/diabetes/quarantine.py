"""Persistent quarantine for records with suspiciously future timestamps."""

import hashlib
import json


def init_quarantine(db):
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS quarantined_records (
            kind TEXT NOT NULL,
            ts INTEGER NOT NULL,
            revision TEXT NOT NULL,
            payload TEXT NOT NULL,
            first_seen INTEGER NOT NULL,
            reason TEXT NOT NULL,
            PRIMARY KEY(kind, ts, revision)
        )
        """
    )


def _canonical(records):
    unique = sorted(set(records), key=_record_sort_key)
    return json.dumps(unique, separators=(",", ":"), ensure_ascii=True)


def _record_sort_key(record):
    kind, ts, value, carbs = record
    return (kind, ts, value, -1 if carbs is None else carbs)


def _notice(kind, count):
    label = "CGM" if kind == "cgm" else "bolus"
    return (
        f"Withheld {count} {label} entries with future or previously flagged timestamps "
        "pending timestamp verification. Original records remain stored privately; "
        "excluded from statistics."
    )


def partition_records(db, records, observed_at):
    grouped = {}
    for record in records:
        kind, ts, _value, _carbs = record
        grouped.setdefault((kind, ts), set()).add(tuple(record))

    if not grouped:
        return [], []

    keys = sorted(grouped)
    existing = set()
    # Bound the ledger lookup to the timestamps in this reading.
    for kind in {key[0] for key in keys}:
        timestamps = [ts for group_kind, ts in keys if group_kind == kind]
        low, high = min(timestamps), max(timestamps)
        existing.update(
            (kind, row[0])
            for row in db.execute(
                "SELECT DISTINCT ts FROM quarantined_records "
                "WHERE kind = ? AND ts BETWEEN ? AND ?",
                (kind, low, high),
            )
        )

    valid = []
    held_counts = {}
    for key in keys:
        kind, ts = key
        group = grouped[key]
        if ts > observed_at + 300 or key in existing:
            payload = _canonical(group)
            revision = hashlib.sha256(payload.encode()).hexdigest()
            db.execute(
                "INSERT OR IGNORE INTO quarantined_records "
                "(kind, ts, revision, payload, first_seen, reason) "
                "VALUES (?, ?, ?, ?, ?, 'future_timestamp')",
                (kind, ts, revision, payload, observed_at),
            )
            held_counts[kind] = held_counts.get(kind, 0) + len(group)
        else:
            valid.extend(sorted(group, key=_record_sort_key))

    notices = [_notice(kind, held_counts[kind]) for kind in sorted(held_counts)]
    return valid, notices
