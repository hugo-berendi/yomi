"""Ciel's text-or-voice choice, run against the real module with fake delivery."""

import asyncio
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

import ciel_voice

SETTINGS = os.environ.get("CIEL_HERMES_SETTINGS")


def event(message_id="$e1", chat_type="dm", platform="matrix", internal=False):
    return SimpleNamespace(
        message_id=message_id,
        internal=internal,
        source=SimpleNamespace(
            platform=SimpleNamespace(value=platform),
            chat_type=chat_type,
            chat_id="!dm:x",
        ),
    )


class Adapter:
    def __init__(self, outcome=True):
        self.outcome = outcome
        self.sent = []

    async def send_voice(self, **kwargs):
        self.sent.append(kwargs)
        if isinstance(self.outcome, Exception):
            raise self.outcome
        return SimpleNamespace(success=self.outcome)


class Runner:
    def __init__(self, adapter):
        self.adapter = adapter
        self.noted = 0

    def _delivery_adapter_for(self, source):
        return self.adapter

    def _reply_anchor_for_event(self, event):
        return "$anchor"

    def _thread_metadata_for_source(self, source, anchor):
        return {"thread_id": "$t"}

    def _note_bot_reply(self, source):
        self.noted += 1


class VoiceTests(unittest.TestCase):
    def setUp(self):
        ciel_voice._spoken.clear()
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.ledger = Path(self.dir.name) / "ledger.json"
        self.made = []

    def synth(self, text):
        fd, path = tempfile.mkstemp(dir=self.dir.name, suffix=".ogg")
        os.close(fd)
        self.made.append((text, path))
        return json.dumps({"success": True, "file_path": path})

    def run_reply(self, response, ev=None, adapter=None, synth=None):
        adapter = adapter or Adapter()
        runner = Runner(adapter)
        out = asyncio.run(
            ciel_voice.prepare_reply(
                runner,
                ev or event(),
                response,
                synthesize=synth or self.synth,
                ledger=self.ledger,
            )
        )
        return out, adapter, runner

    def test_plain_text_is_untouched(self):
        out, adapter, _ = self.run_reply("Alles klar.")
        self.assertEqual(out, "Alles klar.")
        self.assertEqual(adapter.sent, [])

    def test_marked_reply_is_spoken_once_and_not_sent_as_text(self):
        out, adapter, runner = self.run_reply(
            "[[voice]] Das klingt nach einem guten Plan."
        )
        self.assertIsNone(out)
        self.assertEqual(self.made[0][0], "Das klingt nach einem guten Plan.")
        self.assertEqual(len(adapter.sent), 1)
        self.assertEqual(adapter.sent[0]["reply_to"], "$anchor")
        self.assertEqual(
            adapter.sent[0]["metadata"], {"thread_id": "$t", "notify": True}
        )
        self.assertEqual(runner.noted, 1)
        self.assertFalse(os.path.exists(self.made[0][1]), "temp audio left behind")

    def test_replayed_event_is_not_delivered_again(self):
        self.run_reply("[[voice]] Gern.")
        out, adapter, _ = self.run_reply("[[voice]] Gern.")
        self.assertIsNone(out)
        self.assertEqual(adapter.sent, [])
        # A different inbound message is a new decision.
        out, adapter, _ = self.run_reply("[[voice]] Gern.", ev=event("$e2"))
        self.assertIsNone(out)
        self.assertEqual(len(adapter.sent), 1)

    def test_replay_with_a_different_answer_stays_silent_once_spoken(self):
        self.run_reply("[[voice]] Gern.")
        out, adapter, _ = self.run_reply("Gern, als Text.")
        self.assertIsNone(out)
        self.assertEqual(adapter.sent, [])

    def test_unwritable_ledger_does_not_reopen_the_event(self):
        blocker = Path(self.dir.name) / "blocker"
        blocker.write_text("a file where the ledger directory should be")
        self.ledger = blocker / "ledger.json"
        self.run_reply("[[voice]] Gern.")
        out, adapter, _ = self.run_reply("[[voice]] Gern.")
        self.assertIsNone(out)
        self.assertEqual(adapter.sent, [])

    def test_tts_failure_falls_back_to_text_and_can_retry(self):

        def bad(text):
            return json.dumps({"success": False, "error": "no piper"})

        out, adapter, _ = self.run_reply("[[voice]] Gern.", synth=bad)
        self.assertEqual(out, "Gern.")
        self.assertEqual(adapter.sent, [])

        def crash(text):
            raise RuntimeError("boom")

        out, _, _ = self.run_reply("[[voice]] Gern.", synth=crash)
        self.assertEqual(out, "Gern.")
        # Nothing was recorded, so a later attempt may still speak.
        out, adapter, _ = self.run_reply("[[voice]] Gern.")
        self.assertIsNone(out)
        self.assertEqual(len(adapter.sent), 1)

    def test_send_failure_falls_back_to_text(self):
        for outcome in (False, RuntimeError("matrix down")):
            out, adapter, _ = self.run_reply(
                "[[voice]] Gern.", adapter=Adapter(outcome)
            )
            self.assertEqual(out, "Gern.")
            self.assertEqual(len(adapter.sent), 1)
        self.assertFalse(self.ledger.exists())
        self.assertTrue(all(not os.path.exists(p) for _, p in self.made))

    def test_unsuitable_replies_stay_text_without_the_marker(self):
        cases = [
            "[[voice]] Probier `git status` aus.",
            "[[voice]] Schau auf https://example.org nach.",
            "[[voice]] Zwei Schritte:\n- erst das\n- dann das",
            "[[voice]] " + "Ein langer Satz. " * 60,
            "[[voice]] 12345",
        ]
        for response in cases:
            out, adapter, _ = self.run_reply(response)
            self.assertEqual(out, response[len("[[voice]] ") :].strip())
            self.assertEqual(adapter.sent, [])
        self.assertEqual(self.made, [])

    def test_only_the_owner_dm_gets_speech(self):
        for ev in (
            event(chat_type="group"),
            event(platform="telegram"),
            event(internal=True),
            event(message_id=None),
        ):
            out, adapter, _ = self.run_reply("[[voice]] Gern.", ev=ev)
            self.assertEqual(out, "Gern.")
            self.assertEqual(adapter.sent, [])

    def test_marker_only_counts_at_the_start(self):
        out, _, _ = self.run_reply("Gern. [[voice]] noch etwas")
        self.assertEqual(out, "Gern. [[voice]] noch etwas")

    def test_several_audio_files_are_not_half_delivered(self):
        def two(text):
            paths = []
            for _ in range(2):
                fd, path = tempfile.mkstemp(dir=self.dir.name, suffix=".ogg")
                os.close(fd)
                paths.append(path)
            return json.dumps({"success": True, "file_paths": paths})

        out, adapter, _ = self.run_reply("[[voice]] Gern.", synth=two)
        self.assertEqual(out, "Gern.")
        self.assertEqual(adapter.sent, [])


@unittest.skipUnless(SETTINGS, "Requires the built Hermes settings")
class VoiceConfigTests(unittest.TestCase):
    def test_tts_is_the_local_piper_command_with_voice_delivery(self):
        tts = json.loads(Path(SETTINGS).read_text())["tts"]
        self.assertEqual(tts["provider"], "ciel-piper")
        provider = tts["providers"]["ciel-piper"]
        self.assertEqual(provider["type"], "command")
        self.assertIs(provider["voice_compatible"], True)
        self.assertEqual(provider["output_format"], "ogg")
        script = Path(provider["command"].split()[0])
        self.assertTrue(script.is_file())
        body = script.read_text()
        self.assertIn("de_DE-thorsten-high.onnx", body)
        self.assertIn("libopus", body)
        self.assertNotIn("http", body)


if __name__ == "__main__":
    unittest.main()
