"""Synthetic evidence history, late-upload invalidation and Qwen retrieval."""

import json
from pathlib import Path
import tempfile
import unittest
from datetime import UTC, datetime
from unittest.mock import patch

from analysis import week_bounds
from app import ai_review, build_report, database, init_db


class MemoryIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        init_db(self.root)
        self.now = datetime(2026, 10, 26, 12, tzinfo=UTC)

    def tearDown(self):
        self.temporary.cleanup()

    def populate(self):
        rows = []
        for offset in range(8):
            start, end = week_bounds(self.now, offset)
            rows.extend(
                (ts, 100 if offset < 4 else 200)
                for ts in range(start, end - 86400, 300)
            )
        with database(self.root) as db:
            db.executemany("INSERT INTO records VALUES ('cgm',?,?,NULL,0)", rows)

    def test_missing_history_is_explicit(self):
        with database(self.root) as db:
            report = build_report(db, self.now)
            self.assertTrue(
                "memory" in report, "report must include longitudinal memory"
            )
            self.assertEqual(report["memory"]["available_weeks"], 0)
            self.assertEqual(report["memory"]["retrieved_ids"], [])

    def test_late_upload_revises_current_evidence_and_preserves_old_card(self):
        self.populate()
        with database(self.root) as db:
            first = build_report(db, self.now)
            self.assertTrue(
                "memory" in first, "report must include longitudinal memory"
            )
            old = db.execute(
                "SELECT revision,payload FROM memory_cards WHERE id='memory_trend_in_percent' AND active=1"
            ).fetchone()
            self.assertIsNotNone(old)
            count = db.execute("SELECT count(*) FROM memory_cards").fetchone()[0]
            same = build_report(db, self.now)
            self.assertEqual(first["revision"], same["revision"])
            self.assertEqual(
                count, db.execute("SELECT count(*) FROM memory_cards").fetchone()[0]
            )
            start, end = week_bounds(self.now, 6)
            db.executemany(
                "INSERT INTO records VALUES ('cgm',?,100,NULL,0)",
                [(ts,) for ts in range(end - 86400, end, 300)],
            )
            revised = build_report(db, self.now)
            self.assertEqual(first["weeks"], revised["weeks"])
            self.assertNotEqual(first["revision"], revised["revision"])
            self.assertNotEqual(
                first["memory"]["revision"], revised["memory"]["revision"]
            )
            archived = db.execute(
                "SELECT payload,active FROM memory_cards WHERE id='memory_trend_in_percent' AND revision=?",
                (old[0],),
            ).fetchone()
            self.assertEqual(archived[0], old[1])
            self.assertEqual(archived[1], 0)
            self.assertEqual(
                db.execute(
                    "SELECT count(*) FROM memory_cards WHERE id='memory_trend_in_percent' AND active=1"
                ).fetchone()[0],
                1,
            )

    def test_model_receives_only_current_allowlisted_memory_facts(self):
        self.populate()
        with database(self.root) as db:
            report = build_report(db, self.now)
        prompts = []

        def model(url, payload, **kwargs):
            prompts.append(json.loads(payload["messages"][0]["content"]))
            return {
                "choices": [
                    {
                        "message": {
                            "content": json.dumps(
                                {
                                    "fact_ids": ["coverage", "memory_trend_in_percent"],
                                    "question_ids": ["patterns"],
                                }
                            )
                        }
                    }
                ]
            }

        with patch("app.http_json", model):
            selected = ai_review(report, "http://synthetic.invalid")
        self.assertIn("memory_trend_in_percent", selected["fact_ids"])
        self.assertIn("memory_trend_in_percent", {f["id"] for f in prompts[0]["facts"]})
        self.assertEqual(set(prompts[0]), {"facts", "questions", "instruction"})

    def test_history_slices_preserve_glucose_carry_and_bolus_boundaries(self):
        from analysis import weekly_history

        start, end = week_bounds(self.now)
        rows = [(start - 60, 120), (start + 120, 180), (end - 60, 90), (end + 10, 140)]
        boluses = [
            (start - 1, 7, None),
            (start, 2, 10),
            (end - 1, 1, None),
            (end, 9, None),
        ]
        summary = weekly_history(rows, boluses, self.now, count=1)[0]
        self.assertEqual(summary["observed_hours"], 0.13)
        self.assertEqual(summary["in_percent"], 100)
        self.assertEqual(summary["recorded_boluses"], 2)
        self.assertEqual(summary["recorded_bolus_units"], 3)
