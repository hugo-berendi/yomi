import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).with_name("memory.py")
SPEC = importlib.util.spec_from_file_location("diabetes_memory", MODULE_PATH)
memory = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(memory)


def week(
    label,
    index,
    *,
    coverage=100,
    observed_hours=10,
    metric=70,
    hour_minutes=120,
    high_dates=None,
    low_dates=None,
    range_minutes=60,
):
    hourly = [
        {
            "hour": hour,
            "observed_minutes": hour_minutes if hour == 8 else 0,
            "above_minutes": range_minutes if hour == 8 else 0,
            "below_minutes": range_minutes if hour == 8 else 0,
            "high_dates": high_dates or [],
            "low_dates": low_dates or [],
        }
        for hour in range(24)
    ]
    return {
        "label": label,
        "start": f"2026-01-{index + 1:02d}",
        "end": f"2026-01-{index + 7:02d}",
        "coverage": coverage,
        "observed_hours": observed_hours,
        "in_percent": metric,
        "above_percent": metric,
        "below_percent": metric,
        "hourly": hourly,
    }


class MemoryTests(unittest.TestCase):
    def test_empty_and_sparse_weeks_do_not_create_facts(self):
        result = memory.build_memory([week("week 1", 0, coverage=0)])

        self.assertEqual(result["available_weeks"], 0)
        self.assertEqual(result["eligible_weeks"], 0)
        self.assertEqual(result["facts"], [])
        self.assertEqual(result["retrieved_ids"], [])

    def test_trend_compares_equal_weighted_observed_hours_and_reports_percentage_points(
        self,
    ):
        weeks = [week(f"W{i}", i, metric=90 if i < 4 else 70) for i in range(8)]

        result = memory.build_memory(weeks)
        fact = next(f for f in result["facts"] if f["id"] == "memory_trend_in_percent")

        self.assertIn("+20.0 percentage points", fact["text"])
        self.assertIn("4/4 eligible", fact["text"])
        self.assertEqual(
            fact["evidence"]["method"],
            "observed-hours-weighted weekly percentages",
        )
        self.assertEqual(
            [w["label"] for w in fact["evidence"]["recent_weeks"]],
            ["W0", "W1", "W2", "W3"],
        )

    def test_zero_delta_says_unchanged(self):
        weeks = [week(f"W{i}", i, metric=70) for i in range(8)]

        fact = next(
            f
            for f in memory.build_memory(weeks)["facts"]
            if f["id"] == "memory_trend_in_percent"
        )

        self.assertIn("remained unchanged", fact["text"])
        self.assertNotIn("increased", fact["text"])

    def test_trend_omitted_when_either_calendar_block_has_fewer_than_three_eligible_weeks(
        self,
    ):
        weeks = [week(f"W{i}", i, coverage=69 if i < 2 else 100) for i in range(8)]

        result = memory.build_memory(weeks)

        self.assertFalse(
            any(f["id"] == "memory_trend_in_percent" for f in result["facts"])
        )

    def test_recurrence_needs_three_distinct_dates_in_at_least_three_eligible_weeks(
        self,
    ):
        highs = ["2026-01-02", "2026-01-03", "2026-01-04"]
        weeks = [week(f"W{i}", i, high_dates=highs) for i in range(3)]

        fact = next(
            f
            for f in memory.build_memory(weeks)["facts"]
            if f["id"] == "memory_recur_above_08"
        )

        self.assertIn("08:00–09:00", fact["text"])
        self.assertIn("3 of 3 eligible weeks", fact["text"])
        self.assertEqual(fact["evidence"]["weeks"][0]["matched_date_count"], 3)

    def test_recurrence_ignores_hours_with_less_than_120_observed_minutes(self):
        highs = ["2026-01-02", "2026-01-03", "2026-01-04"]
        weeks = [week(f"W{i}", i, hour_minutes=20, high_dates=highs) for i in range(3)]

        result = memory.build_memory(weeks)

        self.assertFalse(
            any(f["id"] == "memory_recur_above_08" for f in result["facts"])
        )

    def test_hashes_are_stable_and_revision_changes_when_old_evidence_changes(self):
        weeks = [week(f"W{i}", i, metric=90 if i < 4 else 70) for i in range(26)]
        first = memory.build_memory(weeks)
        same = memory.build_memory(weeks)
        changed_weeks = list(weeks)
        changed_weeks[20] = {**weeks[20], "start": "2025-12-01"}
        changed = memory.build_memory(changed_weeks)

        self.assertEqual(first, same)
        self.assertNotEqual(first["revision"], changed["revision"])
        self.assertTrue(all(f["revision"] for f in first["facts"]))

    def test_sub_resolution_change_does_not_claim_increase_or_decrease(self):
        weeks = [week(f"W{i}", i, metric=90.01 if i < 4 else 90) for i in range(8)]
        fact = next(
            f
            for f in memory.build_memory(weeks)["facts"]
            if f["id"] == "memory_trend_in_percent"
        )
        self.assertIn("remained unchanged", fact["text"])


if __name__ == "__main__":
    unittest.main()
