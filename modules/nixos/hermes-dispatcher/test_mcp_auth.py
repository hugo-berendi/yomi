import hashlib
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import urlencode

from t3_mcp_auth import McpAuth, b64


class McpAuthTests(unittest.TestCase):
    def test_pairing_pkce_form_exchange_is_private_and_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            calls, authorization = [], {}

            def post(url, data, headers):
                calls.append(url)
                if url.endswith("/register"):
                    result = {"client_id": "registered"}
                elif url.endswith("/decision"):
                    authorization.update(data["authorization"])
                    self.assertEqual(data["decision"]["code"], "dummy-pairing")
                    result = {
                        "redirectTo": authorization["redirect_uri"]
                        + "?"
                        + urlencode(
                            {
                                "code": "authorization-code",
                                "state": authorization["state"],
                                "iss": "http://127.0.0.1:8501",
                            }
                        )
                    }
                else:
                    self.assertEqual(
                        headers["Content-Type"], "application/x-www-form-urlencoded"
                    )
                    self.assertEqual(
                        b64(hashlib.sha256(data["code_verifier"].encode()).digest()),
                        authorization["code_challenge"],
                    )
                    result = {
                        "access_token": "dummy-private-token",
                        "token_type": "Bearer",
                        "expires_in": 3600,
                    }
                return {"Content-Type": "application/json"}, json.dumps(result)

            config = {
                "stateDirectory": directory,
                "baseUrl": "http://127.0.0.1:8501",
                "t3": "/t3",
                "baseDirectory": "/owner/.t3",
            }
            issued = SimpleNamespace(stdout=json.dumps({"credential": "dummy-pairing"}))
            with patch("t3_mcp_auth.subprocess.run", return_value=issued) as cli:
                auth = McpAuth(config, post)
                first = auth.credentials()
                self.assertEqual(auth.credentials(), first)
                self.assertEqual(cli.call_count, 1)
                argv = cli.call_args.args[0]
                self.assertNotIn("dummy-pairing", argv)
                self.assertNotIn("access:write", argv)
            self.assertEqual(len(calls), 3)
            self.assertEqual(
                (Path(directory) / "t3-mcp-auth.json").stat().st_mode & 0o777, 0o600
            )

    def test_credentials_never_go_to_a_remote_plaintext_origin(self):
        with self.assertRaisesRegex(ValueError, "loopback"):
            McpAuth({"stateDirectory": "/unused", "baseUrl": "http://remote.example"})
