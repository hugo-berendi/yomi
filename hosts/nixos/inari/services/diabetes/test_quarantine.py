import importlib.util
from pathlib import Path
import sqlite3
import unittest


MODULE_PATH = Path(__file__).with_name("quarantine.py")
SPEC = importlib.util.spec_from_file_location("diabetes_quarantine", MODULE_PATH)
quarantine = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(quarantine)


class QuarantineTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        quarantine.init_quarantine(self.db)

    def tearDown(self):
        self.db.close()

    def test_mixed_valid_and_future_records_are_partitioned_and_notified(self):
        records = [("cgm", 1000, 120, 0), ("cgm", 1301, 140, 0)]
        valid, notices = quarantine.partition_records(self.db, records, 1000)
        self.assertEqual(valid, [records[0]])
        self.assertEqual(len(notices), 1)
        self.assertTrue(notices[0].startswith("Withheld 1 CGM"))

    def test_future_record_stays_held_after_time_passes(self):
        record = ("cgm", 1301, 140, 0)
        quarantine.partition_records(self.db, [record], 1000)
        valid, notices = quarantine.partition_records(self.db, [record], 2000)
        self.assertEqual(valid, [])
        self.assertTrue(notices[0].startswith("Withheld 1 CGM"))

    def test_overlapping_identical_groups_deduplicate_and_first_seen_is_immutable(self):
        record = ("cgm", 1301, 140, 0)
        _valid, notices = quarantine.partition_records(self.db, [record, record], 1000)
        quarantine.partition_records(self.db, [record], 1100)
        rows = self.db.execute("SELECT first_seen FROM quarantined_records").fetchall()
        self.assertEqual(rows, [(1000,)])
        self.assertTrue(notices[0].startswith("Withheld 1 CGM"))

    def test_future_bolus_timestamp_group_is_held_together(self):
        records = [("bolus", 1400, 2.0, 0), ("bolus", 1400, 1.0, 15)]
        valid, notices = quarantine.partition_records(self.db, records, 1000)
        self.assertEqual(valid, [])
        self.assertTrue(notices[0].startswith("Withheld 2 bolus"))
        self.assertEqual(
            self.db.execute("SELECT COUNT(*) FROM quarantined_records").fetchone()[0], 1
        )

    def test_none_and_numeric_carbs_sort_and_preserve_values(self):
        records = [("bolus", 1400, 1, None), ("bolus", 1400, 1, 15)]
        valid, notices = quarantine.partition_records(self.db, records, 1000)
        self.assertEqual(valid, [])
        self.assertTrue(notices[0].startswith("Withheld 2 bolus"))
        payload = self.db.execute("SELECT payload FROM quarantined_records").fetchone()[
            0
        ]
        self.assertIn("null", payload)
        self.assertIn("15", payload)

        valid_records = [("bolus", 1000, 1, None), ("bolus", 1000, 1, 15)]
        valid, notices = quarantine.partition_records(self.db, valid_records, 1000)
        self.assertEqual(valid, valid_records)
        self.assertEqual(notices, [])

    def test_revised_payload_same_key_is_preserved_as_an_immutable_version(self):
        original = ("cgm", 1301, 140, 0)
        revised = ("cgm", 1301, 145, 0)
        quarantine.partition_records(self.db, [original], 1000)
        quarantine.partition_records(self.db, [revised], 1100)
        rows = self.db.execute(
            "SELECT first_seen, payload FROM quarantined_records ORDER BY revision"
        ).fetchall()
        self.assertEqual(len(rows), 2)
        self.assertEqual({row[0] for row in rows}, {1000, 1100})


if __name__ == "__main__":
    unittest.main()
