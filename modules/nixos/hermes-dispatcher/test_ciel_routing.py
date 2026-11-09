import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from ciel_routing import choose, route_turn


class RoutingTests(unittest.TestCase):
    def test_routine_requires_positive_evidence(self):
        for text in (
            "Hallo Ciel!",
            "Danke",
            "Übersetze diesen Satz ins Englische: Guten Morgen.",
            "Korrigiere den Tippfehler im Button-Label",
        ):
            with self.subTest(text=text):
                self.assertEqual(choose(text), "routine")
        for text in ("Mach das", "Ja", "Warum geht das nicht?", "Fix it", "", None):
            with self.subTest(text=text):
                self.assertEqual(choose(text), "standard")

    def test_risk_overrides_short_or_routine_sounding_requests(self):
        for text in (
            "Übersetze den Plan zur Datenbankmigration",
            "Fix auth",
            "Ändere die Firewall",
            "Plane die Architektur",
            "Ein Security-Review bitte",
            "Lösche alle Daten",
        ):
            with self.subTest(text=text):
                self.assertEqual(choose(text), "complex")

    def test_manual_selection_is_preserved_and_log_has_no_prompt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = root / "routing.json"
            config.write_text(
                json.dumps(
                    {
                        "baseline": {"model": "sol", "effort": "medium"},
                        "routes": {
                            "routine": {"model": "luna", "effort": "low"},
                            "standard": {"model": "sol", "effort": "medium"},
                            "complex": {"model": "sol", "effort": "high"},
                        },
                    }
                )
            )
            ledger = root / "routes.jsonl"
            with patch.dict(
                os.environ,
                CIEL_ROUTING_CONFIG=str(config),
                CIEL_ROUTE_LEDGER=str(ledger),
            ):
                self.assertEqual(
                    route_turn("Hallo Ciel!", model="sol", effort="medium"),
                    ("luna", "low"),
                )
                self.assertEqual(
                    route_turn("Hallo Ciel!", model="other", effort="high"),
                    ("other", "high"),
                )
            entry = json.loads(ledger.read_text().splitlines()[0])
            self.assertEqual(entry["tier"], "routine")
            self.assertNotIn("Hallo", ledger.read_text())
