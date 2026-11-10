"""A silenced internal broker event is told apart from missing output before the fallback.

The gateway turns an empty final reply into "Processing completed but no response was
generated". These tests run the real decision code from the built Hermes source and pin
that the bare silence marker is settled as an intentional no-send first, while empty
output on an ordinary request still gets the failure notice.
"""

import ast
import asyncio
import logging
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

SOURCE = os.environ.get("CIEL_HERMES_SOURCE")
MARKER = "[SILENT]"
INTERNAL = "internal_notification"
NO_RESPONSE = "gateway.errors.no_response"
UNEXPECTED_SILENCE = "gateway.errors.unexpected_silence"

if SOURCE:
    sys.path.insert(0, SOURCE)


def parse(name):
    path = Path(SOURCE) / name
    return path, ast.parse(path.read_text())


def functions(name, owner, wanted):
    """The wanted methods of one upstream class (or module functions when owner is None)."""
    path, tree = parse(name)
    scope = (
        tree
        if owner is None
        else next(
            n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == owner
        )
    )
    return path, [
        n
        for n in scope.body
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.name in wanted
    ]


def load(name, owner, wanted, namespace):
    path, nodes = functions(name, owner, wanted)
    assert {n.name for n in nodes} == set(wanted), (name, wanted)
    future = ast.ImportFrom(
        module="__future__", names=[ast.alias(name="annotations")], level=0
    )
    if owner is None:
        body = [future, *nodes]
    else:
        body = [
            future,
            ast.ClassDef(
                name="Loaded",
                bases=[],
                keywords=[],
                body=nodes,
                decorator_list=[],
                type_params=[],
            ),
        ]
    module = ast.fix_missing_locations(ast.Module(body=body, type_ignores=[]))
    exec(compile(module, str(path), "exec"), namespace)
    return namespace


@unittest.skipUnless(SOURCE, "Requires built Hermes source")
class SilenceBeforeFallbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # The real empty-output fallback, with only its locale lookup and error
        # classifiers replaced by plain values.
        run = {
            "t": lambda key, **kw: key,
            "logger": logging.getLogger("test"),
            "is_context_overflow_failure_result": lambda *a, **k: False,
            "_looks_like_gateway_provider_error": lambda text: False,
            "_is_gateway_hidden_reasoning_incomplete_turn": lambda result: False,
        }
        load("gateway/run.py", None, ["_normalize_empty_agent_response"], run)
        fake_run = SimpleNamespace(
            _normalize_empty_agent_response=run["_normalize_empty_agent_response"],
            _is_gateway_hidden_reasoning_incomplete_turn=lambda result: False,
            _sanitize_gateway_final_response=lambda platform, text: text,
            _should_clear_resume_pending_after_turn=lambda result: False,
        )
        fake_run_turn = SimpleNamespace(
            _unexpected_silence_reply=lambda: UNEXPECTED_SILENCE
        )
        sys.modules["gateway.run"] = fake_run
        sys.modules["gateway.run_turn"] = fake_run_turn
        cls.addClassCleanup(sys.modules.pop, "gateway.run", None)
        cls.addClassCleanup(sys.modules.pop, "gateway.run_turn", None)
        persistence = {
            "logger": logging.getLogger("test"),
            "time": __import__("time"),
            "automatic_notices_allowed": lambda source: True,
            "diagnostic_wake_muted": lambda event: False,
            "suppress": __import__("contextlib").suppress,
            "Optional": __import__("typing").Optional,
        }
        load(
            "gateway/run_turn_persistence.py",
            "GatewayTurnPersistenceMixin",
            [
                "_hmwa_shape_agent_response",
                "_hmwa_deliver_turn_response",
                "_is_intentional_silence",
            ],
            persistence,
        )
        config = {}
        load(
            "gateway/run_config_loaders.py",
            "GatewayConfigLoadersMixin",
            ["_silence_allowed_for_source"],
            config,
        )

        class Gateway(persistence["Loaded"], config["Loaded"]):
            def __init__(self):
                self.transport = []

            def _delivery_adapter_for(self, source):
                return SimpleNamespace(
                    send=lambda *a, **k: self.transport.append((a, k))
                )

            def _should_send_voice_reply(self, *a, **k):
                return False

            def _room_allow_silence(self, source):
                return None

        cls.gateway = Gateway()

    def shape(self, final, kind, *, api_calls=1, reply_expected=None):
        """What the gateway decides for a completed Codex turn: (text, intentional silence)."""
        # The result shape agent/codex_runtime._turn_result gives a finished turn.
        result = {
            "final_response": final,
            "messages": [],
            "api_calls": api_calls,
            "completed": True,
            "partial": False,
            "interrupted": False,
            "error": None,
        }
        source = SimpleNamespace(chat_id="!room", platform="matrix")
        entry = SimpleNamespace(session_id="s1")
        response, silent, _ = asyncio.run(
            self.gateway._hmwa_shape_agent_response(
                result,
                source,
                [],
                entry,
                None,
                "q",
                1,
                "s1",
                "matrix",
                0.0,
                persist_user_display_kind=kind,
                reply_expected=reply_expected,
            )
        )
        # What the turn runner hands the platform adapter; empty or None means no send.
        delivered = asyncio.run(
            self.gateway._hmwa_deliver_turn_response(
                SimpleNamespace(),
                source,
                entry,
                None,
                1,
                result,
                [],
                response,
                "",
                silent,
            )
        )
        return delivered, silent

    def test_silenced_internal_event_is_a_no_send_not_missing_output(self):
        delivered, silent = self.shape(MARKER, INTERNAL)
        self.assertTrue(silent)
        self.assertFalse(delivered)  # no text, so no warning and no placeholder
        self.assertEqual(self.gateway.transport, [])

    def test_meaningful_internal_result_is_delivered(self):
        text = "Der Worker braucht eine Freigabe für den Push."
        self.assertEqual(self.shape(text, INTERNAL), (text, False))

    def test_internal_reply_quoting_the_marker_is_delivered(self):
        text = f"Ich habe {MARKER} bewusst nicht verwendet, weil es neu ist."
        self.assertEqual(self.shape(text, INTERNAL), (text, False))

    def test_missing_output_on_a_request_from_hugo_still_fails_visibly(self):
        self.assertEqual(self.shape("", None), (NO_RESPONSE, False))

    def test_missing_output_on_an_internal_event_is_still_reported(self):
        # Only the explicit marker is a no-send. An empty reply stays an error, so a
        # broken wake cannot disappear silently.
        self.assertEqual(self.shape("", INTERNAL), (NO_RESPONSE, False))

    def test_bare_marker_answering_hugo_is_not_swallowed(self):
        self.assertEqual(self.shape(MARKER, None), (UNEXPECTED_SILENCE, False))

    def test_hugos_reply_mentioning_the_marker_is_delivered(self):
        text = f"Das Kürzel {MARKER} nutze ich nur für Broker-Ereignisse."
        self.assertEqual(self.shape(text, None), (text, False))


if __name__ == "__main__":
    unittest.main()
