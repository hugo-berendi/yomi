import json
from pathlib import Path
import tempfile
import unittest
from matrix_rooms import private_room


class PrivateRoomTests(unittest.TestCase):
    def test_discovery_requires_exact_owner_bot_membership_and_encryption(self):
        with tempfile.TemporaryDirectory() as directory:
            auth = Path(directory) / "auth.json"
            auth.write_text(
                json.dumps(
                    {
                        "user_id": "@ciel:example.org",
                        "access_token": "test-token",
                        "device_id": "test-device",
                    }
                )
            )
            config = {
                "matrixAuth": str(auth),
                "matrix": {
                    "userId": "@ciel:example.org",
                    "allowedUser": "@hugo:example.org",
                    "homeserver": "http://127.0.0.1",
                },
            }
            members = {"@ciel:example.org": {}, "@hugo:example.org": {}}

            def request(base, path, payload, **kwargs):
                self.assertEqual(kwargs["method"], "GET")
                if path == "joined_rooms":
                    return 200, {"joined_rooms": ["!dm:example.org"]}
                if path.endswith("joined_members"):
                    return 200, {"joined": members}
                return 200, {"algorithm": "m.megolm.v1.aes-sha2"}

            self.assertEqual(private_room(config, call=request), "!dm:example.org")
            members["@other:example.org"] = {}
            with self.assertRaises(ValueError):
                private_room(config, call=request)
