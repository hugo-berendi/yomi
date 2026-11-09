import json
from pathlib import Path
import tempfile
import unittest

from matrix_profile import update_profile


class MatrixProfileTests(unittest.TestCase):
    def test_upload_sets_own_avatar_with_authenticated_requests(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "matrix-auth.json").write_text(
                json.dumps(
                    {
                        "user_id": "@bot:matrix.example.org",
                        "device_id": "test-device",
                        "access_token": "test-token",
                    }
                )
            )
            image = root / "avatar.png"
            image.write_bytes(b"\x89PNG\r\n\x1a\nfixture")
            calls = []

            def call(base, endpoint, payload, **kwargs):
                calls.append((endpoint, payload, kwargs))
                self.assertEqual(kwargs["token"], "test-token")
                return 200, {"content_uri": "mxc://matrix.example.org/image"}

            settings = {
                "homeserver": "http://127.0.0.1:8432",
                "userId": "@bot:matrix.example.org",
            }
            update_profile(root, settings, name="Test Bot", avatar=image, call=call)
            self.assertEqual(
                calls[0][0], "profile/%40bot%3Amatrix.example.org/displayname"
            )
            self.assertEqual(calls[1][0], "/_matrix/media/v3/upload")
            self.assertEqual(calls[1][2]["content_type"], "image/png")
            self.assertEqual(
                calls[2][1], {"avatar_url": "mxc://matrix.example.org/image"}
            )
            self.assertEqual(calls[2][2]["method"], "PUT")
            image.write_text("This is not an image")
            with self.assertRaises(ValueError):
                update_profile(root, settings, avatar=image, call=call)
            self.assertEqual(len(calls), 3)
