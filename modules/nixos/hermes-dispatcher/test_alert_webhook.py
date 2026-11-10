"""Alert webhook configuration and the Codex limits of webhook turns."""

import ast
import json
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from alert_webhook import gateway_configuration

SECRET = "s" * 40
WEBHOOK = {
    "port": 8515,
    "routes": {
        "alert-triage": {"prompt": "x {context}"},
        "alert-notice": {"deliver_only": True, "prompt": "{message}"},
    },
}


class GatewayConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.state = root / "state"
        self.state.mkdir()
        self.credentials = root / "credentials"
        self.credentials.mkdir()
        (root / "config.json").write_text(
            json.dumps({"platforms": {"matrix": {"enabled": True}}})
        )
        self.settings = {
            "configuration": str(root / "config.json"),
            "matrix": {
                "homeserver": "http://hs",
                "userId": "@ciel:x",
                "allowedUser": "@hugo:x",
            },
            "alertWebhook": WEBHOOK,
        }

    def tearDown(self):
        self.temp.cleanup()

    def build(self, *, secret=SECRET, resolve=lambda config: "!dm:x"):
        if secret is not None:
            (self.credentials / "alert-webhook").write_text(secret + "\n")
        return gateway_configuration(
            self.settings,
            self.state,
            environ={"CREDENTIALS_DIRECTORY": str(self.credentials)},
            resolve=resolve,
        )

    def test_routes_bound_to_the_verified_room(self):
        seen = {}

        def resolve(config):
            seen.update(config)
            return "!dm:x"

        webhook = self.build(resolve=resolve)["platforms"]["webhook"]
        self.assertEqual(seen["matrixAuth"], str(self.state / "matrix-auth.json"))
        self.assertEqual(webhook["extra"]["host"], "127.0.0.1")
        for route in webhook["extra"]["routes"].values():
            self.assertEqual(route["deliver"], "matrix")
            self.assertEqual(route["deliver_extra"], {"chat_id": "!dm:x"})
            self.assertEqual(route["secret"], SECRET)
            self.assertNotEqual(route.get("mirror_to_session"), True)

    def test_static_configuration_never_holds_the_secret(self):
        self.build()
        self.assertNotIn(SECRET, Path(self.settings["configuration"]).read_text())

    def test_no_secret_no_webhook(self):
        self.assertNotIn("webhook", self.build(secret=None)["platforms"])
        self.assertNotIn("webhook", self.build(secret="short")["platforms"])

    def test_ambiguous_room_no_webhook(self):
        def resolve(config):
            raise ValueError("Expected one encrypted private chat with Hugo")

        configuration = self.build(resolve=resolve)
        self.assertNotIn("webhook", configuration["platforms"])
        self.assertTrue(
            configuration["platforms"]["matrix"]["enabled"], "chat keeps working"
        )

    def test_disabled(self):
        self.settings["alertWebhook"] = None
        self.assertNotIn("webhook", self.build()["platforms"])


@unittest.skipUnless(
    os.environ.get("CIEL_HERMES_SOURCE"), "Requires built Hermes source"
)
class WebhookTurnPolicyTests(unittest.TestCase):
    def setUp(self):
        import sys

        sys.path.insert(0, os.environ["CIEL_HERMES_SOURCE"])
        from agent import ciel_webhook_policy

        self.policy = ciel_webhook_policy

    def test_webhook_turns_lose_task_tools_and_shell(self):
        calls = []
        factory = self.policy.client_factory(
            SimpleNamespace(platform="webhook", user_id="webhook:alert-triage"),
            lambda **kwargs: calls.append(kwargs),
        )
        factory(codex_bin="codex", codex_home=None)
        args = calls[0]["extra_args"]
        for setting in (
            "mcp_servers.ciel.enabled=false",
            "features.shell_tool=false",
            "features.unified_exec=false",
        ):
            self.assertIn(setting, args)
        self.assertEqual(args[args.index("mcp_servers.ciel.enabled=false") - 1], "-c")

    def test_chat_turns_are_untouched(self):
        self.assertIsNone(
            self.policy.client_factory(
                SimpleNamespace(platform="matrix", user_id="@hugo:x"), object
            )
        )

    def test_patched_runtime_uses_the_policy(self):
        path = Path(os.environ["CIEL_HERMES_SOURCE"]) / "agent/codex_runtime.py"
        function = next(
            node
            for node in ast.parse(path.read_text()).body
            if isinstance(node, ast.FunctionDef)
            and node.name == "_ensure_codex_session"
        )
        source = ast.unparse(function)
        self.assertIn("ciel_client_factory(agent, CielCodexClient)", source)
        self.assertIn("'client_factory': ciel_factory", source)


if __name__ == "__main__":
    unittest.main()
