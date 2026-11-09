"""Check the chat-hygiene settings and the wake path against the real Hermes source."""

import ast
import asyncio
import importlib.util
import inspect
import json
import os
from pathlib import Path
import unittest

SOURCE = os.environ.get("CIEL_HERMES_SOURCE")
SETTINGS = os.environ.get("CIEL_HERMES_SETTINGS")


def method(path, cls_name, name):
    tree = ast.parse(Path(path).read_text())
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef) and node.name == cls_name:
            for item in node.body:
                if (
                    isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef))
                    and item.name == name
                ):
                    return item
    raise AssertionError(f"{cls_name}.{name} not found in {path}")


@unittest.skipUnless(SOURCE and SETTINGS, "Requires built Hermes source and settings")
class ChatHygieneTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(SOURCE)
        self.settings = json.loads(Path(SETTINGS).read_text())

    def test_matrix_shows_no_tool_bubbles(self):
        spec = importlib.util.spec_from_file_location(
            "upstream_display_config", self.root / "gateway/display_config.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(
            module.resolve_tool_progress(self.settings, "matrix"), ("off", True)
        )

    def test_progress_gate_keeps_clarify_and_subagent_failures(self):
        # tool_progress only gates tool.started bubbles; the failure notice and
        # the clarify prompt are handled before that gate.
        body = ast.unparse(
            method(
                self.root / "gateway/run_turn_progress.py",
                "GatewayTurnProgressMixin",
                "progress_callback",
            )
        )
        failure = body.index("subagent.complete")
        gate = body.index("not ctx.tool_progress_enabled")
        self.assertLess(failure, gate)

    def test_transcript_echo_is_off(self):
        self.assertIs(self.settings["stt"]["echo_transcripts"], False)
        config = (self.root / "gateway/config.py").read_text()
        self.assertIn('stt_setting("stt_echo_transcripts", "echo_transcripts")', config)

    def test_hidden_echo_still_hands_the_transcript_to_ciel(self):
        node = (
            method(
                self.root / "gateway/run_inbound.py",
                "GatewayInboundMixin",
                "_enrich_inbound_voice",
            )
            if "class GatewayInboundMixin"
            in (self.root / "gateway/run_inbound.py").read_text()
            else None
        )
        if node is None:
            tree = ast.parse((self.root / "gateway/run_inbound.py").read_text())
            node = next(
                n
                for n in ast.walk(tree)
                if isinstance(n, ast.AsyncFunctionDef)
                and n.name == "_enrich_inbound_voice"
            )
        node.returns = None
        for arg in node.args.args + node.args.kwonlyargs:
            arg.annotation = None
        namespace = {}
        exec(compile(ast.Module([node], []), "upstream", "exec"), namespace)
        enrich = namespace["_enrich_inbound_voice"]
        echoed = []

        class Runner:
            async def _enrich_message_with_transcription(self, text, paths):
                return 'Hugo sagte: "Bitte den Login prüfen"', [
                    "Bitte den Login prüfen"
                ]

            def _should_echo_stt_transcripts(self):
                return False

            async def _echo_stt_transcripts(self, *args, **kwargs):
                echoed.append(args)

        text = asyncio.run(enrich(Runner(), None, None, "", ["/voice.ogg"]))
        self.assertIn("Bitte den Login prüfen", text)
        self.assertEqual(echoed, [])


@unittest.skipUnless(SOURCE, "Requires built Hermes source")
class WakeContractTests(unittest.TestCase):
    def test_wake_api_and_matrix_source_helpers_exist(self):
        root = Path(SOURCE)
        tree = ast.parse((root / "gateway/wake.py").read_text())
        wake = next(
            n
            for n in tree.body
            if isinstance(n, ast.AsyncFunctionDef) and n.name == "deliver_wake"
        )
        self.assertEqual([a.arg for a in wake.args.args], ["adapter"])
        self.assertTrue({"text", "source"} <= {a.arg for a in wake.args.kwonlyargs})
        adapter = root / "../../../share/hermes/plugins/platforms/matrix/adapter.py"
        source = adapter.read_text()
        for helper in ("async def _resolve_room_identity", "async def _is_dm_room"):
            self.assertIn(helper, source)
        build = method(
            root / "gateway/platforms/base.py", "BasePlatformAdapter", "build_source"
        )
        params = {a.arg for a in build.args.args + build.args.kwonlyargs}
        self.assertTrue(
            {"chat_id", "chat_name", "chat_type", "user_id", "chat_topic", "guild_id"}
            <= params
        )
        # Our source must pass only parameters build_source accepts.
        from ciel_watch import owner_source

        used = {
            k.arg
            for n in ast.walk(ast.parse(inspect.getsource(owner_source)))
            if isinstance(n, ast.Call) and getattr(n.func, "attr", "") == "build_source"
            for k in n.keywords
        }
        self.assertTrue(used <= params)


if __name__ == "__main__":
    unittest.main()
