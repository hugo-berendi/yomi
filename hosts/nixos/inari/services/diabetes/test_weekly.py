import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest.mock import patch

from analysis import weekly_summary
from app import database, init_db


class WeeklyTests(unittest.TestCase):
    def test_timestamp_warning_persists_without_latest_import_notices(self):
        from analysis import comparison
        from report_email import presentation

        report = comparison([], [], datetime(2026, 10, 26, 8, tzinfo=UTC))
        report["data_quality"] = {
            "quarantined_cgm_groups": 2,
            "quarantined_bolus_groups": 0,
        }
        view = presentation(report, None, [])
        self.assertTrue(view["timestamp_attention"])
        self.assertTrue(any("2 CGM" in n for n in view["notices"]))
        self.assertTrue(
            any("verify the CGM timestamps" in q for q in view["questions"])
        )

    def test_brief_preserves_exclusion_counts_across_export_files(self):
        from analysis import comparison
        from report_email import presentation

        report = comparison([], [], datetime(2026, 10, 26, 8, tzinfo=UTC))
        notice = "Excluded 11 CGM entries with ambiguous local clock-change timestamps."
        view = presentation(report, None, [notice, notice])
        self.assertTrue(any("22 CGM" in item for item in view["notices"]))

    def test_brief_does_not_turn_missing_previous_week_into_zero_episodes(self):
        from analysis import comparison, week_bounds
        from report_email import presentation

        now = datetime(2026, 10, 26, 8, tzinfo=UTC)
        start, _ = week_bounds(now)
        report = comparison([(start + i * 300, 60) for i in range(4)], [], now)
        view = presentation(report, None, [])
        self.assertIn("unavailable", view["highlights"][0]["text"].lower())

    def test_hour_chart_weights_two_hour_cells_and_keeps_gaps_unknown(self):
        import math
        from report_charts import hour_values

        values = hour_values(
            [
                {"hour": 0, "observed_minutes": 30, "above_minutes": 30},
                {"hour": 1, "observed_minutes": 90, "above_minutes": 0},
                {"hour": 2, "observed_minutes": 60, "above_minutes": 0},
            ],
            "above",
        )
        self.assertEqual(values[0], 25)
        self.assertEqual(values[1], 0)
        self.assertTrue(math.isnan(values[2]))

    def test_mail_is_a_brief_with_distinct_charts_and_no_repeated_facts(self):
        from analysis import comparison
        from weekly import render

        now = datetime(2026, 10, 26, 8, tzinfo=UTC)
        report = comparison([], [], now)
        report["facts"] += [
            {"id": f"synthetic_{i}", "text": "Repeated technical evidence " * 20}
            for i in range(40)
        ]
        message = render(
            report,
            {
                "sender": "report@example.invalid",
                "recipient": "patient@example.invalid",
            },
            now,
            quality=["CSV outside supported CGM/bolus schema"] * 10,
        )
        plain = message.get_body(preferencelist=("plain",)).get_content()
        body = message.get_body(preferencelist=("html",)).get_content()
        self.assertLess(len(plain), 4500)
        self.assertNotIn("Repeated technical evidence", body)
        self.assertNotIn("sudo", body)
        self.assertIn("Data quality", body)
        self.assertIn("Unavailable", plain)
        images = [
            part for part in message.walk() if part.get_content_type() == "image/png"
        ]
        self.assertEqual(len(images), 3)
        for part in images:
            self.assertTrue(part.get_payload(decode=True).startswith(b"\x89PNG"))
            self.assertIn("cid:" + part["Content-ID"].strip("<>"), body)

    def test_low_patterns_and_supported_totals(self):
        summary = weekly_summary(
            [(0, 60), (300, 60), (600, 60)], [(100, 2, 20), (400, 1, None)], 0, 86400
        )
        self.assertEqual(summary.get("low_episodes"), 1)
        self.assertEqual(summary.get("recorded_bolus_units"), 3)
        self.assertEqual(summary.get("recorded_carbs_g"), 20)
        self.assertEqual(summary.get("boluses_with_carbs"), 1)
        self.assertEqual(summary.get("hourly", [{}])[1].get("below_minutes"), 15)

    def test_missing_insulin_is_unavailable(self):
        summary = weekly_summary([], [], 0, 86400)
        self.assertIsNone(summary.get("recorded_bolus_units"))
        self.assertIsNone(summary.get("recorded_carbs_g"))

    def test_ai_review_failure_is_logged_and_report_continues(self):
        import io
        from contextlib import redirect_stderr
        from analysis import comparison
        from weekly import run_weekly

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            config = dict(
                recipient="patient@example.invalid",
                sender="report@example.invalid",
                host="localhost",
                port=587,
            )
            now = datetime(2026, 10, 26, 8, tzinfo=UTC)
            report = comparison([], [], now) | {"comparable": True}

            def review(report, url):
                raise TimeoutError("model offline")

            submitted = []
            stderr = io.StringIO()
            with (
                patch("weekly.sync", return_value="not configured"),
                patch("weekly.build_report", return_value=report),
                redirect_stderr(stderr),
            ):
                result = run_weekly(
                    root,
                    config,
                    now,
                    submit=lambda message, cfg: submitted.append(message),
                    review=review,
                )
            self.assertEqual(result["status"], "submitted")
            self.assertEqual(len(submitted), 1)
            self.assertIn(
                "AI review failed: TimeoutError: model offline", stderr.getvalue()
            )

    def test_mail_is_multipart_and_uncertain_is_never_retried(self):
        from weekly import run_weekly

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            messages = []

            def submit(message, config):
                messages.append(message)
                raise TimeoutError("sensitive exception")

            config = dict(
                recipient="patient@example.invalid",
                sender="report@example.invalid",
                host="localhost",
                port=587,
            )
            now = datetime(2026, 10, 26, 8, tzinfo=UTC)
            with patch("weekly.sync", return_value="not configured"):
                self.assertEqual(
                    run_weekly(
                        root, config, now, submit=submit, review=lambda r, u: {}
                    )["status"],
                    "uncertain",
                )
                # A revision and a process restart must not reopen the weekly slot.
                with database(root) as db:
                    db.execute(
                        "INSERT INTO records VALUES ('cgm',1792400000,100,NULL,0)"
                    )
                self.assertEqual(
                    run_weekly(root, config, now, submit=submit)["status"], "uncertain"
                )
            self.assertEqual(len(messages), 1)
            self.assertIn(
                "text/plain", [p.get_content_type() for p in messages[0].walk()]
            )
            self.assertIn(
                "text/html", [p.get_content_type() for p in messages[0].walk()]
            )
            self.assertIn(
                "image/png", [p.get_content_type() for p in messages[0].walk()]
            )
            self.assertNotIn(
                "sensitive exception",
                (root / "journal.sqlite").read_bytes().decode(errors="ignore"),
            )

    def test_berlin_due_time_in_summer_and_winter(self):
        from weekly import due

        for before, after in [
            ("2026-07-06T06:59:00+00:00", "2026-07-06T07:00:00+00:00"),
            ("2026-10-26T07:59:00+00:00", "2026-10-26T08:00:00+00:00"),
        ]:
            self.assertFalse(due(datetime.fromisoformat(before)))
            self.assertTrue(due(datetime.fromisoformat(after)))

    def test_invalid_recipient_prevents_any_delivery(self):
        from weekly import run_weekly

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            self.assertEqual(
                run_weekly(root, {}, datetime(2026, 10, 26, 8, tzinfo=UTC))["status"],
                "not configured",
            )

    def test_rejected_delivery_backs_off_then_retries(self):
        from weekly import run_weekly, Rejected

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            config = dict(
                recipient="patient@example.invalid",
                sender="report@example.invalid",
                host="localhost",
            )
            now = datetime(2026, 10, 26, 8, tzinfo=UTC)
            with patch("weekly.sync", return_value="not configured"):
                result = run_weekly(
                    root,
                    config,
                    now,
                    submit=lambda m, c: (_ for _ in ()).throw(Rejected()),
                )
                self.assertEqual(result["status"], "rejected")
                result = run_weekly(
                    root, config, now, submit=lambda m, c: self.fail("must back off")
                )
                self.assertEqual(result["status"], "rejected")
                result = run_weekly(
                    root,
                    config,
                    datetime(2026, 10, 26, 15, tzinfo=UTC),
                    submit=lambda m, c: None,
                )
                self.assertEqual(result["status"], "submitted")

    def test_model_failure_still_submits(self):
        from weekly import run_weekly
        from analysis import week_bounds

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            now = datetime(2026, 10, 26, 8, tzinfo=UTC)
            start, end = week_bounds(now, 1)[0], week_bounds(now)[1]
            with database(root) as db:
                db.executemany(
                    "INSERT INTO records VALUES ('cgm',?,100,NULL,0)",
                    [(t,) for t in range(start, end, 300)],
                )
            messages = []

            def failed_model(r, u):
                raise ValueError("private failure")

            with patch("weekly.sync", return_value="failed"):
                result = run_weekly(
                    root,
                    dict(
                        recipient="patient@example.invalid",
                        sender="report@example.invalid",
                        host="localhost",
                    ),
                    now,
                    submit=lambda m, c: messages.append(m),
                    review=failed_model,
                )
            self.assertEqual(result["status"], "submitted")
            self.assertIn(
                "Local AI unavailable",
                messages[0].get_body(preferencelist=("plain",)).get_content(),
            )

    def test_crash_reservation_blocks_resend(self):
        from weekly import run_weekly

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            config = dict(
                recipient="patient@example.invalid",
                sender="report@example.invalid",
                host="localhost",
            )
            now = datetime(2026, 10, 26, 8, tzinfo=UTC)
            with patch("weekly.sync", return_value="failed"):
                with self.assertRaises(SystemExit):
                    run_weekly(
                        root,
                        config,
                        now,
                        submit=lambda m, c: (_ for _ in ()).throw(SystemExit()),
                    )
                self.assertEqual(
                    run_weekly(
                        root, config, now, submit=lambda m, c: self.fail("duplicate")
                    )["status"],
                    "uncertain",
                )

    def test_authentication_challenge_is_distinct_and_preserves_history(self):
        from glooko_sync import AuthenticationRequired, save_credentials, sync
        from app import get_state

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            save_credentials(root, "synthetic@example.invalid", "synthetic-only", "UTC")

            def challenge(credentials):
                raise AuthenticationRequired()

            self.assertEqual(
                sync(root, fetch=challenge, now=1000), "authentication required"
            )
            with database(root) as db:
                state = get_state(db, "glooko")
            self.assertEqual(state["error_code"], "authentication_required")
            self.assertEqual(sync(root, fetch=challenge, now=1100), "not due")

    def test_implicit_tls_smtp_and_acknowledged_send(self):
        from weekly import smtp_submit

        class SMTP:
            def __init__(self, host, port, timeout, context):
                self.host = host

            def ehlo(self):
                pass

            def send_message(self, message):
                return {}

            def close(self):
                raise OSError("QUIT failed after acceptance")

        with (
            patch("weekly.smtplib.SMTP_SSL", SMTP),
            patch(
                "weekly.smtplib.SMTP",
                side_effect=AssertionError("must use implicit TLS"),
            ),
        ):
            smtp_submit(
                None, {"host": "synthetic.invalid", "port": 465, "implicit_tls": True}
            )

    def test_report_refresh_bypasses_success_cadence_but_not_failure_backoff(self):
        from glooko_sync import save_credentials, sync

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            save_credentials(root, "synthetic@example.invalid", "synthetic-only", "UTC")
            payload = b"Type,Timestamp,Glucose (mg/dL)\ncgm,2020-01-01T00:00:00Z,100\n"
            self.assertEqual(sync(root, fetch=lambda c: payload, now=1000), "synced")

            def failed(c):
                raise ValueError("private error")

            self.assertEqual(sync(root, fetch=failed, now=1100, refresh=True), "failed")
            self.assertEqual(
                sync(root, fetch=lambda c: payload, now=1200, refresh=True), "not due"
            )

    def test_concurrent_backup_publication(self):
        from app import snapshot_database
        from concurrent.futures import ThreadPoolExecutor

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            with ThreadPoolExecutor(max_workers=4) as pool:
                list(pool.map(lambda _: snapshot_database(root), range(20)))
            import sqlite3

            with sqlite3.connect(root / "backup.sqlite") as db:
                self.assertEqual(
                    db.execute("PRAGMA integrity_check").fetchone()[0], "ok"
                )
