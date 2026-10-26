"""Synthetic session and authentication recovery checks."""

import json
from pathlib import Path
import tempfile
import unittest

from app import create_app, database, get_state, init_db
from glooko_sync import AuthenticationRequired, save_credentials, sync


class SessionTests(unittest.TestCase):
    def test_verification_pauses_automatic_login_until_local_reauthentication(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            init_db(root)
            save_credentials(root, "synthetic@example.invalid", "private-only", "UTC")

            def challenge(_):
                raise AuthenticationRequired()

            self.assertEqual(
                sync(root, fetch=challenge, now=1000), "authentication required"
            )

            def forbidden(_):
                self.fail("must not cause repeated verification emails")

            self.assertEqual(
                sync(root, fetch=forbidden, now=100000), "authentication required"
            )
            payload = b"Type,Timestamp,Glucose (mg/dL)\ncgm,2020-01-01T00:00:00Z,100\n"
            self.assertEqual(
                sync(root, fetch=lambda _: payload, now=100100, interactive=True),
                "synced",
            )
            with database(root) as db:
                self.assertIsNone(get_state(db, "glooko")["error_code"])

    def test_session_is_atomic_private_and_reusable(self):
        from glooko_sync import save_browser_state, load_browser_state

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = {
                "cookies": [
                    {
                        "name": "session",
                        "value": "synthetic-private-cookie",
                        "domain": ".my.glooko.com",
                    }
                ],
                "origins": [],
            }
            save_browser_state(root, state)
            self.assertEqual(
                (root / "glooko-session.json").stat().st_mode & 0o777, 0o600
            )
            self.assertEqual(load_browser_state(root), state)
            self.assertFalse((root / "glooko-session.tmp").exists())

    def test_credentials_update_invalidates_old_session_and_disconnect_removes_it(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = create_app(root)
            client = app.test_client()
            headers = {"Authorization": "Bearer " + (root / "access-token").read_text()}
            session = root / "glooko-session.json"
            session.write_text(json.dumps({"cookies": [], "origins": []}))
            save_credentials(root, "synthetic@example.invalid", "private-only", "UTC")
            self.assertFalse(session.exists())
            session.write_text("{}")
            client.post("/glooko", headers=headers, data={"action": "disconnect"})
            self.assertFalse(session.exists())

    def test_session_keeps_glooko_subdomains_and_discards_third_parties(self):
        from glooko_sync import save_browser_state, load_browser_state

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            save_browser_state(
                root,
                {
                    "cookies": [
                        {
                            "domain": ".eu.my.glooko.com",
                            "name": "session",
                            "value": "synthetic",
                        },
                        {
                            "domain": "other.invalid",
                            "name": "tracker",
                            "value": "exclude",
                        },
                    ],
                    "origins": [
                        {"origin": "https://eu.my.glooko.com", "localStorage": []},
                        {"origin": "https://other.invalid", "localStorage": []},
                    ],
                },
            )
            state = load_browser_state(root)
            self.assertEqual(len(state["cookies"]), 1)
            self.assertEqual(len(state["origins"]), 1)
            self.assertEqual(state["cookies"][0]["domain"], ".eu.my.glooko.com")
