"""Synthetic fixtures only: no personal health data in the repository."""

import io
import json
import os
import sqlite3
import tempfile
import time
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch
import zipfile

from analysis import comparison, parse_export, timestamp, week_bounds, weekly_summary
from app import (
    DexcomReader,
    ai_review,
    build_report,
    create_app,
    database,
    import_records,
    get_state,
)
from glooko_sync import sync, sync_lock


def archive(name, text):
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w") as file:
        file.writestr(name, text)
    return output.getvalue()


class AnalysisTests(unittest.TestCase):
    def test_berlin_dst_weeks(self):
        self.assertEqual(
            week_bounds(datetime(2026, 3, 30, 12, tzinfo=UTC))[1]
            - week_bounds(datetime(2026, 3, 30, 12, tzinfo=UTC))[0],
            167 * 3600,
        )
        start, end = week_bounds(datetime(2026, 10, 26, 12, tzinfo=UTC))
        self.assertEqual(end - start, 169 * 3600)
        self.assertEqual(
            weekly_summary([(t, 100) for t in range(start, end, 300)], [], start, end)[
                "coverage"
            ],
            100,
        )

    def test_ambiguous_local_time_rejected(self):
        for value in ("2026-10-25 02:30", "2026-03-29 02:30"):
            with self.assertRaises(ValueError):
                timestamp(value, "Europe/Berlin")
        self.assertEqual(
            timestamp("2026-10-25T02:30:00+02:00"), timestamp("2026-10-25T00:30:00Z")
        )

    def test_metadata_semicolon_mmol_and_utc(self):
        rows, skipped = parse_export(
            archive(
                "cgm_data_1.csv",
                "Name;Synthetic only\nTimestamp;Glucose (mmol/L);Serial Number\n2026-09-01T12:00:00Z;5,5;ignored\n",
            )
        )
        self.assertEqual(len(rows), 1)
        self.assertAlmostEqual(rows[0][2], 99.1001, places=3)
        self.assertEqual(skipped, [])

    def test_generic_schema_requires_type(self):
        with self.assertRaises(ValueError):
            parse_export(b"Timestamp,Glucose (mg/dL)\n2026-09-01T12:00:00Z,100\n")
        rows, _ = parse_export(
            b"Timestamp,Type,Glucose (mg/dL)\n2026-09-01T12:00:00Z,cgm,100\n"
        )
        self.assertEqual(rows[0][0], "cgm")

    def test_german_glooko_export(self):
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as file:
            file.writestr(
                "cgm_data_1.csv",
                "Name,Synthetic\nZeitstempel,CGM-Glukosewert (mg/dl),Seriennummer\n"
                '01.09.2026 12:00,"100,0",ignored\n',
            )
            file.writestr(
                "Insulin data/bolus_data_1.csv",
                "Name,Synthetic\nZeitstempel,Insulin-Typ,Kohlenhydrataufnahme (g),"
                "Abgegebenes Insulin (E),Anfängliche Abgabe (E),Verzögerte Abgabe (E)\n"
                '01.09.2026 12:00,Normal,"20,0","1,25","1,00","0,25"\n',
            )
            for filename, header in (
                ("basal_data_1.csv", "Abgegebenes Insulin (E)"),
                ("insulin_data_1.csv", "Bolus gesamt (U)"),
                ("bg_data_1.csv", "Glukosewert (mg/dl)"),
            ):
                file.writestr(filename, f"Zeitstempel,{header}\n01.09.2026 12:00,10\n")
        rows, skipped = parse_export(output.getvalue(), "Europe/Berlin")
        ts = timestamp("2026-09-01T10:00:00Z")
        self.assertEqual(rows, [("cgm", ts, 100.0, None), ("bolus", ts, 1.25, 20.0)])
        self.assertEqual(len(skipped), 3)

    def test_german_glooko_mmol(self):
        rows, _ = parse_export(
            archive(
                "cgm_data_1.csv",
                "Zeitstempel;CGM-Glukosewert (mmol/l)\n01.09.2026 12:00;5,5\n",
            ),
            "Europe/Berlin",
        )
        self.assertAlmostEqual(rows[0][2], 99.1001, places=3)

    def test_glooko_out_of_range_code_leaves_gap(self):
        rows, notices = parse_export(
            archive(
                "cgm_data_1.csv",
                "Zeitstempel,CGM-Glukosewert (mg/dl)\n"
                '01.09.2026 12:00,"100,0"\n'
                '01.09.2026 12:05,"2001,0"\n'
                '01.09.2026 12:10,"100,0"\n',
            ),
            "Europe/Berlin",
        )
        self.assertEqual(len(rows), 2)
        self.assertEqual(len(notices), 1)
        self.assertIn("2001", notices[0])
        result = weekly_summary(
            [(r[1], r[2]) for r in rows], [], rows[0][1], rows[0][1] + 900
        )
        self.assertEqual(result["coverage"], 66.67)

    def test_bolus_and_carbs(self):
        rows, _ = parse_export(
            archive(
                "bolus_data_1.csv",
                "Timestamp,Insulin Delivered (U),Carbs (g)\n2026-09-01T12:00:00Z,1.25,20\n",
            )
        )
        self.assertEqual(rows[0][2:], (1.25, 20.0))

    def test_nan_and_bad_rows_rejected(self):
        for row in (
            "2026-09-01T12:00:00Z,nan",
            "bad time,100",
            "2026-09-01T12:00:00Z,100,extra",
        ):
            with self.assertRaises(ValueError):
                parse_export(
                    archive("cgm_data.csv", "Timestamp,Glucose (mg/dL)\n" + row)
                )

    def test_gap_ends_episode(self):
        readings = [(0, 200), (300, 200), (600, 200), (1800, 200), (2100, 200)]
        result = weekly_summary(readings, [], 0, 3600)
        self.assertEqual(result["high_episodes"], 1)
        self.assertEqual(result["longest_high_minutes"], 15)
        self.assertEqual(result["coverage"], 41.67)
        self.assertEqual(result["above_percent"], 100)

    def test_week_boundary_is_clipped(self):
        result = weekly_summary([(-120, 200), (180, 100)], [], 0, 300)
        self.assertEqual(result["above_percent"], 60)
        self.assertEqual(result["in_percent"], 40)
        self.assertEqual(result["coverage"], 100)

    def test_ranges_and_weighted_mean(self):
        result = weekly_summary(
            [(0, 70), (300, 180), (600, 60), (900, 190)], [], 0, 1200
        )
        self.assertEqual(result["in_percent"], 50)
        self.assertEqual(result["below_percent"], 25)
        self.assertEqual(result["mean"], 125)

    def test_comparison_percentage_points_not_percent_change(self):
        now = datetime(2026, 9, 21, 12, tzinfo=UTC)
        start, end = week_bounds(now)
        previous, _ = week_bounds(now, 1)
        readings = [
            (t, 100 if t < start or t < start + (end - start) / 2 else 200)
            for t in range(previous, end, 300)
        ]
        report = comparison(readings, [], now)
        self.assertEqual(report["deltas"]["in_percent"], -50)
        self.assertTrue(report["comparable"])

    def test_no_data_is_not_good_control(self):
        report = comparison([], [])
        self.assertIsNone(report["weeks"][0]["in_percent"])
        self.assertFalse(report["comparable"])

    def test_ai_rejects_unverified_output(self):
        report = comparison([], [])
        for answer in (
            {"fact_ids": ["invented"], "question_ids": []},
            {"fact_ids": ["coverage"], "question_ids": [], "dose": 2},
        ):
            with patch(
                "app.http_json",
                return_value={
                    "choices": [{"message": {"content": json.dumps(answer)}}]
                },
            ):
                with self.assertRaises(ValueError):
                    ai_review(report, "http://localhost")

    def test_ai_accepts_fenced_json_but_still_validates_ids(self):
        answer = '```json\n{"fact_ids":["coverage"],"question_ids":["late"]}\n```'
        with patch(
            "app.http_json",
            return_value={"choices": [{"message": {"content": answer}}]},
        ):
            self.assertEqual(
                ai_review(comparison([], []), "http://localhost")["fact_ids"],
                ["coverage"],
            )


class AppTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.app = create_app(
            self.root, {"TESTING": True, "SESSION_COOKIE_SECURE": False}
        )
        self.client = self.app.test_client()
        self.headers = {
            "Authorization": "Bearer " + (self.root / "access-token").read_text()
        }

    def tearDown(self):
        self.temp.cleanup()

    def connect_glooko(self):
        response = self.client.post(
            "/glooko",
            headers=self.headers,
            data={
                "action": "connect",
                "email": "synthetic@example.invalid",
                "password": "test-private-password",
                "timezone": "UTC",
            },
        )
        self.assertEqual(response.status_code, 302)

    def test_glooko_connection_is_private_and_can_disconnect(self):
        self.assertEqual(self.client.post("/glooko", data={}).status_code, 302)
        self.connect_glooko()
        path = self.root / "glooko-credentials.json"
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        page = self.client.get("/", headers=self.headers)
        self.assertEqual(page.status_code, 200)
        self.assertNotIn(b"test-private-password", page.data)
        self.assertNotIn(b"synthetic@example.invalid", page.data)
        self.client.post("/glooko", headers=self.headers, data={"action": "disconnect"})
        self.assertFalse(path.exists())
        self.assertEqual(sync(self.root), "not configured")

    def test_glooko_sync_schedule_deduplication_and_retry(self):
        self.connect_glooko()
        payload = archive(
            "cgm_data.csv", "Timestamp,Glucose (mg/dL)\n2026-09-01T12:00:00Z,100\n"
        )
        with patch("glooko_sync.download_export") as unused:
            self.assertEqual(
                sync(self.root, fetch=lambda _: payload, now=2000000000), "synced"
            )
            self.assertEqual(sync(self.root, fetch=unused, now=2000000300), "not due")
            unused.assert_not_called()
        self.assertEqual(
            sync(self.root, fetch=lambda _: payload, now=2000086400), "synced"
        )
        with database(self.root) as db:
            state = get_state(db, "glooko")
            self.assertEqual(state["added"], 0)
            self.assertEqual(
                db.execute("SELECT count(*) FROM records").fetchone()[0], 1
            )
        self.client.post("/glooko", headers=self.headers, data={"action": "retry"})
        self.assertEqual(
            sync(self.root, fetch=lambda _: payload, now=2000086500), "synced"
        )

    def test_glooko_failure_preserves_data_and_redacts_exception(self):
        self.connect_glooko()
        with database(self.root) as db:
            import_records(db, [("cgm", 1000, 100, None)])

        def failure(_):
            raise RuntimeError("secret-password and private health data")

        self.assertEqual(sync(self.root, fetch=failure, now=2000000000), "failed")
        with database(self.root) as db:
            state = get_state(db, "glooko")
            self.assertNotIn("secret-password", json.dumps(state))
            self.assertEqual(state["next_attempt"], 2000021600)
            self.assertNotIn("success", state)
            self.assertEqual(
                db.execute("SELECT count(*) FROM records").fetchone()[0], 1
            )
        self.assertEqual(sync(self.root, fetch=failure, now=2000000300), "not due")

    def test_glooko_conflict_rolls_back_and_parallel_sync_is_skipped(self):
        self.connect_glooko()
        with database(self.root) as db:
            import_records(db, [("cgm", 1000, 100, None)])
        payload = b"Timestamp,Type,Glucose (mg/dL)\n1970-01-01T00:20:00Z,cgm,100\n1970-01-01T00:16:40Z,cgm,200\n"
        self.assertEqual(
            sync(self.root, fetch=lambda _: payload, now=2000000000), "failed"
        )
        with database(self.root) as db:
            self.assertEqual(
                db.execute("SELECT count(*) FROM records").fetchone()[0], 1
            )
        with sync_lock(self.root):
            self.assertEqual(sync(self.root), "already running")
            self.assertEqual(
                self.client.post(
                    "/glooko", headers=self.headers, data={"action": "disconnect"}
                ).status_code,
                400,
            )

    def test_private_routes_and_read_token_scope(self):
        self.assertEqual(self.client.get("/").status_code, 302)
        self.assertEqual(self.client.get("/api/glucose").status_code, 401)
        read = {"Authorization": "Bearer " + (self.root / "read-token").read_text()}
        self.assertEqual(self.client.get("/api/glucose", headers=read).status_code, 200)
        self.assertEqual(self.client.post("/api/tick", headers=read).status_code, 401)
        self.assertEqual(self.client.get("/report.json", headers=read).status_code, 302)

    def test_session_posts_need_csrf(self):
        with self.client.session_transaction() as session:
            session["authenticated"] = True
            session["csrf"] = "expected"
        self.assertEqual(self.client.post("/settings", data={}).status_code, 403)

    def test_import_is_atomic_and_idempotent(self):
        with database(self.root) as db:
            self.assertEqual(import_records(db, [("cgm", 1000, 100, None)]), 1)
        with database(self.root) as db:
            self.assertEqual(import_records(db, [("cgm", 1000, 100, None)]), 0)
        with self.assertRaises(ValueError), database(self.root) as db:
            import_records(db, [("cgm", 1100, 100, None), ("cgm", 1000, 120, None)])
        with database(self.root) as db:
            self.assertEqual(
                db.execute("SELECT COUNT(*) FROM records").fetchone()[0], 1
            )

    def test_distinct_boluses_in_same_minute(self):
        rows = [("bolus", 1000, 1.0, 10.0), ("bolus", 1000, 2.0, None)]
        with database(self.root) as db:
            self.assertEqual(import_records(db, rows), 2)
            self.assertEqual(import_records(db, rows[::-1]), 0)
            self.assertEqual(
                [
                    tuple(r)
                    for r in db.execute(
                        "SELECT value,carbs FROM records ORDER BY event_index"
                    )
                ],
                [(1.0, 10.0), (2.0, None)],
            )
        with self.assertRaises(ValueError), database(self.root) as db:
            import_records(db, rows[:1])

    def test_legacy_records_migration(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            with sqlite3.connect(root / "journal.sqlite") as db:
                db.execute(
                    "CREATE TABLE records (kind TEXT, ts INTEGER, value REAL, carbs REAL, PRIMARY KEY(kind,ts))"
                )
                db.execute("INSERT INTO records VALUES ('bolus',1000,1,10)")
            create_app(root, {"TESTING": True})
            create_app(root, {"TESTING": True})
            with database(root) as db:
                self.assertEqual(import_records(db, [("bolus", 1000, 1, 10)]), 0)

    def test_import_ui_and_escape_notes(self):
        payload = archive(
            "cgm_data.csv", "Timestamp,Glucose (mg/dL)\n2026-09-01T12:00:00Z,100\n"
        )
        response = self.client.post(
            "/import",
            headers=self.headers,
            data={"export": (io.BytesIO(payload), "data.zip")},
        )
        self.assertEqual(response.status_code, 200)
        self.client.post(
            "/action",
            headers=self.headers,
            data={
                "action": "note",
                "action_id": "test-note-123456789",
                "text": "<script>alert(1)</script>",
            },
        )
        response = self.client.get("/", headers=self.headers)
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"&lt;script&gt;", response.data)
        self.assertIn("no-store", response.headers["Cache-Control"])

    def test_double_submit_does_not_decrement_twice(self):
        with database(self.root) as db:
            db.execute("UPDATE supplies SET stock=10 WHERE kind='Pod'")
        data = {
            "action": "supply",
            "action_id": "test-change-123456789",
            "kind": "Pod",
            "operation": "change",
        }
        for _ in range(2):
            self.assertEqual(
                self.client.post(
                    "/action", data=data, headers=self.headers
                ).status_code,
                302,
            )
        with database(self.root) as db:
            self.assertEqual(
                db.execute("SELECT stock FROM supplies WHERE kind='Pod'").fetchone()[0],
                9,
            )

    def test_invalid_action_rolls_back_idempotency_key(self):
        data = {
            "action": "supply",
            "action_id": "test-change-123456789",
            "kind": "Pod",
            "operation": "change",
        }
        self.assertEqual(
            self.client.post("/action", data=data, headers=self.headers).status_code,
            400,
        )
        with database(self.root) as db:
            self.assertEqual(
                db.execute("SELECT COUNT(*) FROM actions").fetchone()[0], 0
            )

    def test_jobs_no_credentials_no_external_calls(self):
        with patch(
            "app.http_json", side_effect=AssertionError("Must not contact services")
        ):
            result = self.app.extensions["tick"]()
            self.assertEqual(result["errors"], [])

    def test_plot_is_authenticated_and_renders(self):
        with database(self.root) as db:
            report = build_report(db)
        response = self.client.get(
            "/plot.png?week=" + report["weeks"][0]["label"], headers=self.headers
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data.startswith(b"\x89PNG"))

    def test_stale_glucose_is_unavailable(self):
        reader = DexcomReader("unused")
        reader.fetched = time.time()
        reader.cached = {"timestamp": time.time() - 601, "value": 100, "trend": "→"}
        self.assertFalse(reader.read()["available"])
        reader.cached["timestamp"] = time.time() - 30
        self.assertTrue(reader.read()["available"])

    def connected_app(self):
        (self.root / "home-assistant-token").write_text("synthetic-test-token")
        with patch.dict(os.environ, {"CREDENTIALS_DIRECTORY": str(self.root)}):
            app = create_app(self.root, {"TESTING": True})
        with database(self.root) as db:
            db.execute(
                "INSERT OR REPLACE INTO settings VALUES ('notify_service', ?)",
                (json.dumps("mobile_app_test"),),
            )
        return app

    @patch("app.time.time", return_value=1790503200)
    def test_notification_failure_retries_then_deduplicates(self, _clock):
        app = self.connected_app()
        with patch("app.http_json", side_effect=OSError("offline")):
            self.assertTrue(app.extensions["tick"]()["errors"])
        with database(self.root) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM sent").fetchone()[0], 0)
        with patch("app.http_json", return_value=[]) as send:
            app.extensions["tick"]()
            app.extensions["tick"]()
            self.assertEqual(send.call_count, 1)
        with sqlite3.connect(self.root / "backup.sqlite") as snapshot:
            self.assertEqual(
                snapshot.execute("PRAGMA integrity_check").fetchone()[0], "ok"
            )
            self.assertEqual(
                snapshot.execute("SELECT COUNT(*) FROM sent").fetchone()[0], 1
            )

    def test_high_reminder_requires_new_readings_and_deduplicates(self):
        app = self.connected_app()
        with database(self.root) as db:
            db.execute("INSERT INTO settings VALUES ('high_notifications', 'true')")
        base = 1790503200  # Sunday, independent of CI's weekday/time.
        with patch("app.http_json", return_value=[]) as send:
            for elapsed in range(0, 2401, 300):
                reading = {
                    "available": True,
                    "value": 220,
                    "timestamp": base + elapsed,
                    "age_seconds": 0,
                }
                with (
                    patch("app.time.time", return_value=base + elapsed),
                    patch.object(
                        app.extensions["dexcom"], "read", return_value=reading
                    ),
                ):
                    app.extensions["tick"]()
            self.assertEqual(
                send.call_count, 2
            )  # One weekly upload notice, one high reminder.

    def test_stale_readings_reset_high_tracking(self):
        app = self.connected_app()
        with database(self.root) as db:
            db.execute("INSERT INTO settings VALUES ('high_notifications', 'true')")
        reading = {
            "available": True,
            "value": 220,
            "timestamp": time.time() - 500,
            "age_seconds": 500,
        }
        with (
            patch("app.http_json", return_value=[]),
            patch.object(app.extensions["dexcom"], "read", return_value=reading),
        ):
            app.extensions["tick"]()
        with database(self.root) as db:
            self.assertEqual(
                db.execute("SELECT value FROM state WHERE key='high'").fetchone()[0],
                "null",
            )


if __name__ == "__main__":
    unittest.main()
