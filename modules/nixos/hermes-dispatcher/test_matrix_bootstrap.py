import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from matrix_bootstrap import bootstrap, validate_auth


class MatrixBootstrapTests(unittest.TestCase):
    settings = {
        "homeserver": "http://127.0.0.1:8432",
        "userId": "@hermes:matrix.example.org",
    }
    auth = {
        "user_id": "@hermes:matrix.example.org",
        "access_token": "test-token",
        "device_id": "test-device",
    }

    def test_registration_challenge_persists_token_and_is_not_repeated(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "registration-token").write_text("test-registration-token")
            calls = []

            def call(base, endpoint, payload):
                calls.append(payload)
                # Recovery material must exist before the first remote mutation.
                saved = json.loads((root / "matrix-registration.json").read_text())
                self.assertEqual(payload["password"], saved["password"])
                if "auth" not in payload:
                    return 401, {
                        "session": "test-session",
                        "flows": [{"stages": ["m.login.registration_token"]}],
                    }
                self.assertEqual(
                    payload["auth"],
                    {
                        "type": "m.login.registration_token",
                        "session": "test-session",
                        "token": "test-registration-token",
                    },
                )
                return 200, self.auth

            with patch.dict(os.environ, CREDENTIALS_DIRECTORY=str(root)):
                bootstrap(root, self.settings, call)
                bootstrap(root, self.settings, call)
            self.assertEqual(len(calls), 2)
            self.assertEqual(
                json.loads((root / "matrix-auth.json").read_text()), self.auth
            )
            self.assertEqual((root / "matrix-auth.json").stat().st_mode & 0o777, 0o600)

    def test_lost_registration_response_recovers_with_same_password_and_device(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def lost(base, endpoint, payload):
                raise TimeoutError("Response lost")

            with self.assertRaises(TimeoutError):
                bootstrap(root, self.settings, lost)
            original = json.loads((root / "matrix-registration.json").read_text())

            def recover(base, endpoint, payload):
                self.assertEqual(payload["password"], original["password"])
                self.assertEqual(payload["device_id"], original["device_id"])
                if endpoint == "register":
                    return 400, {"errcode": "M_USER_IN_USE"}
                return 200, self.auth

            bootstrap(root, self.settings, recover)
            self.assertTrue((root / "matrix-auth.json").exists())

    def test_wrong_identity_and_missing_device_fail_closed(self):
        for auth in (
            {**self.auth, "user_id": "@other:matrix.example.org"},
            {**self.auth, "device_id": ""},
        ):
            with self.assertRaises(ValueError):
                validate_auth(auth, self.settings["userId"])
