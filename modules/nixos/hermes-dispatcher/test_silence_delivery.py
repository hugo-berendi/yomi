"""An internal broker event answered with the silence marker reaches no Matrix room.

The Codex app-server reports each finished agentMessage through the gateway's interim
callback. That callback posts commentary or closes the stream segment, and neither
step consults the silence hold, so the bare marker used to be sent before the final
filter ran. These tests run the patched callback taken from the built Hermes source.
"""

import ast
import asyncio
import os
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
import unittest.mock

SOURCE = os.environ.get("CIEL_HERMES_SOURCE")
MARKER = "[SILENT]"
INTERNAL = "internal_notification"  # what display_kind_for_event gives an internal wake

if SOURCE:
    sys.path.insert(0, SOURCE)


def interim_callback(display_kind, consumer):
    """The patched closure from the gateway turn runner, bound to a fake turn context."""
    path = Path(SOURCE) / "gateway/run_turn_runner.py"
    node = next(
        n
        for n in ast.walk(ast.parse(path.read_text()))
        if isinstance(n, ast.FunctionDef) and n.name == "interim_assistant_cb"
    )
    module = ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[]))
    ctx = SimpleNamespace(
        _run_still_current=lambda: True,
        persist_user_display_kind=display_kind,
        _status_adapter=None,
        _status_thread_metadata=None,
    )
    namespace = {
        "ctx": ctx,
        "local_viewer_route": False,
        "stts": None,
        "stream_consumer": consumer,
        "self": SimpleNamespace(),
    }
    exec(compile(module, str(path), "exec"), namespace)
    return namespace["interim_assistant_cb"]


class RecordingConsumer:
    def __init__(self):
        self.calls = []

    def on_commentary(self, text):
        self.calls.append(("commentary", text))

    def on_segment_break(self):
        self.calls.append(("segment_break",))


@unittest.skipUnless(SOURCE, "Requires built Hermes source")
class InterimCallbackTests(unittest.TestCase):
    def run_callback(self, kind, text, already_streamed):
        consumer = RecordingConsumer()
        interim_callback(kind, consumer)(text, already_streamed=already_streamed)
        return consumer.calls

    def test_internal_event_marker_is_not_forwarded(self):
        for streamed in (False, True):
            with self.subTest(already_streamed=streamed):
                self.assertEqual(self.run_callback(INTERNAL, MARKER, streamed), [])
                self.assertEqual(
                    self.run_callback(INTERNAL, f"\n{MARKER}\n", streamed), []
                )

    def test_internal_event_with_a_real_message_is_forwarded(self):
        calls = self.run_callback(INTERNAL, "Der Worker braucht eine Freigabe.", False)
        self.assertEqual(calls, [("commentary", "Der Worker braucht eine Freigabe.")])
        self.assertEqual(
            self.run_callback(INTERNAL, "Der Worker braucht eine Freigabe.", True),
            [("segment_break",)],
        )

    def test_text_that_only_contains_the_marker_is_forwarded(self):
        for text in (
            f"Antwort mit {MARKER} mittendrin",
            f"{MARKER} und noch eine Frage?",
            f"Ergebnis.\n\n```\n{MARKER}\n```",
            f"`{MARKER}`",
        ):
            with self.subTest(text=text):
                self.assertEqual(
                    self.run_callback(INTERNAL, text, False), [("commentary", text)]
                )

    def test_owner_turns_are_never_gated(self):
        # Hugo's own message and a turn with no recorded origin keep the upstream path,
        # where the final filter replaces a bare marker with a visible notice.
        for kind in (None, "", "user"):
            with self.subTest(kind=kind):
                self.assertEqual(
                    self.run_callback(kind, MARKER, False), [("commentary", MARKER)]
                )

    def test_internal_wake_events_get_the_gated_display_kind(self):
        # What ciel_watch hands the gateway is MessageEvent(internal=True); the kind it
        # persists must be the one the callback gates on, and a user event must not be.
        from gateway.response_filters import display_kind_for_event

        wake = SimpleNamespace(internal=True, metadata={})
        owner = SimpleNamespace(internal=False, metadata={})
        with unittest.mock.patch.dict(
            sys.modules,
            {
                "gateway.session_display": SimpleNamespace(
                    admission_display=lambda event: {}
                )
            },
        ):
            self.assertEqual(display_kind_for_event(wake), INTERNAL)
            self.assertIsNone(display_kind_for_event(owner))


def stream_consumer_types():
    try:
        from gateway.stream_consumer import GatewayStreamConsumer, StreamConsumerConfig
    except Exception:  # Hermes' runtime dependencies are not in the check environment
        return None
    return GatewayStreamConsumer, StreamConsumerConfig


@unittest.skipUnless(
    SOURCE and stream_consumer_types(), "Requires Hermes' runtime dependencies"
)
class CodexRouteDeliveryTests(unittest.TestCase):
    """The real stream consumer fed the way the Codex app-server feeds it."""

    def deliver(self, kind, deltas, final, already_streamed):
        consumer_type, config = stream_consumer_types()
        from unittest.mock import AsyncMock, MagicMock

        adapter = MagicMock()
        adapter.REQUIRES_EDIT_FINALIZE = False
        adapter.MAX_MESSAGE_LENGTH = 4096
        adapter.send = AsyncMock(
            return_value=SimpleNamespace(success=True, message_id="m")
        )
        adapter.edit_message = AsyncMock(
            return_value=SimpleNamespace(success=True, message_id="m")
        )
        adapter.delete_message = AsyncMock(return_value=True)

        async def turn():
            consumer = consumer_type(adapter, "!room", config())
            task = asyncio.create_task(consumer.run())
            await asyncio.sleep(0.1)
            callback = interim_callback(kind, consumer)
            for delta in deltas:
                consumer.on_delta(delta)
            callback(final, already_streamed=already_streamed)
            await asyncio.sleep(0.4)
            consumer.finish()
            await asyncio.wait_for(task, 5)

        asyncio.run(turn())
        return [
            call.kwargs.get("content")
            for mock in (adapter.send, adapter.edit_message)
            for call in mock.call_args_list
        ]

    def test_marker_reaches_no_room_on_either_codex_shape(self):
        # Deltas then the completed item, and the completed item alone.
        for deltas, streamed in (([MARKER], True), ([], False)):
            with self.subTest(deltas=deltas):
                self.assertEqual(self.deliver(INTERNAL, deltas, MARKER, streamed), [])

    def test_real_reply_still_reaches_the_room(self):
        text = "Rückfrage: soll der Worker weitermachen?"
        sent = self.deliver(INTERNAL, [text], text, True)
        self.assertIn(text, sent)

    def test_owner_turn_is_unchanged_by_the_gate(self):
        # Reproduces the old behaviour for non-internal turns on purpose: the gate
        # must not widen beyond internal events.
        self.assertEqual(self.deliver(None, [MARKER], MARKER, True), [MARKER])


if __name__ == "__main__":
    unittest.main()
