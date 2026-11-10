"""Ciel's choice between a text reply and a Matrix voice message.

Ciel opens a reply with [[voice]] when it should be spoken. The gateway removes the
marker on every path, synthesizes the rest with Hermes' own text_to_speech_tool
(configured for local Piper in speech.nix) and sends it as a voice bubble instead of
the text. Anything that goes wrong, or any reply that does not suit speech, is
delivered as the ordinary text reply, so the marker never costs Hugo a message.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import tempfile
from contextlib import suppress
from pathlib import Path

logger = logging.getLogger(__name__)


def failed_voice_text(text: str) -> str:
    return (
        "Audio konnte nicht zugestellt werden. Hier ist die Antwort als Text:\n\n"
        + text
    )


MARKER = re.compile(r"\A\s*\[\[voice\]\][ \t]*\n?", re.IGNORECASE)
# Speech is for short conversational replies. Code, links and exact output read
# better as text; the prompt says so, these checks keep a slip from being spoken.
MAX_CHARS = 700
UNSPEAKABLE = re.compile(
    r"```|`|https?://|www\.|MEDIA:|^\s*(?:[-*]|\d+[.)])\s", re.MULTILINE
)
LEDGER_SIZE = 2000

_in_flight: set[str] = set()
# Also kept in memory, so a failing ledger write cannot re-open an event within this process.
_spoken: set[str] = set()


def split_marker(response: str) -> tuple[bool, str]:
    """(wants_voice, text without the marker)."""
    if not isinstance(response, str):
        return False, response
    match = MARKER.match(response)
    if not match:
        return False, response
    return True, response[match.end() :].strip()


def suits_speech(text: str) -> bool:
    return (
        bool(text)
        and len(text) <= MAX_CHARS
        and re.search(r"[A-Za-zÄÖÜäöüß]", text) is not None
        and UNSPEAKABLE.search(text) is None
    )


def _eligible(event, text: str) -> bool:
    source = event.source
    return (
        getattr(source.platform, "value", None) == "matrix"
        and getattr(source, "chat_type", None) == "dm"
        and not getattr(event, "internal", False)
        and bool(getattr(event, "message_id", None))
        and suits_speech(text)
    )


def ledger_path() -> Path:
    home = os.environ.get("HERMES_HOME") or str(Path.home() / ".hermes")
    return Path(home) / "ciel_voice_sent.json"


def _read(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return []
    return [str(x) for x in data] if isinstance(data, list) else []


def _record(path: Path, key: str) -> None:
    keys = [k for k in _read(path) if k != key] + [key]
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name, suffix=".tmp")
    with os.fdopen(fd, "w") as handle:
        json.dump(keys[-LEDGER_SIZE:], handle)
    os.replace(tmp, path)


async def _speak(runner, event, text: str, synthesize) -> bool:
    """Synthesize and send; True only when the platform confirmed the upload."""
    paths: list[str] = []
    stage = "synthesis"
    try:
        result = json.loads(await asyncio.to_thread(synthesize, text))
        paths = [
            str(p) for p in (result.get("file_paths") or [result.get("file_path")]) if p
        ]
        paths = [p for p in paths if os.path.isfile(p)]
        # A long reply split into several files could half-deliver; send text instead.
        if not result.get("success") or len(paths) != 1:
            logger.warning(
                "Ciel voice synthesis produced no single deliverable audio file"
            )
            return False
        stage = "matrix delivery"
        adapter = runner._delivery_adapter_for(event.source)
        send = getattr(adapter, "send_voice", None)
        if not callable(send):
            logger.warning("Ciel voice adapter has no send_voice method")
            return False
        anchor = runner._reply_anchor_for_event(event)
        meta = dict(runner._thread_metadata_for_source(event.source, anchor) or {})
        meta["notify"] = True
        sent = await send(
            chat_id=event.source.chat_id,
            audio_path=paths[0],
            reply_to=anchor,
            metadata=meta,
        )
        success = bool(getattr(sent, "success", False))
        if not success:
            logger.warning("Ciel voice Matrix delivery was not confirmed")
        return success
    except Exception as exc:
        # Do not log provider errors or tracebacks: they may contain the private reply.
        logger.warning("Ciel voice %s failed (%s)", stage, type(exc).__name__)
        return False
    finally:
        for path in paths:
            with suppress(OSError):
                os.unlink(path)


async def prepare_reply(runner, event, response, *, synthesize=None, ledger=None):
    """The text still to be sent: the reply without its marker, or None once spoken."""
    wants_voice, text = split_marker(response)
    path = Path(ledger) if ledger else ledger_path()
    key = str(getattr(event, "message_id", None))
    # A replayed inbound event must not be answered again once its reply went out
    # as audio, whatever the new attempt decided: that would be a second reply.
    if getattr(event, "message_id", None) and (
        key in _in_flight or key in _spoken or key in _read(path)
    ):
        return None
    if not wants_voice:
        return response
    if not _eligible(event, text):
        return text
    if synthesize is None:
        from agent.ciel_voice_tts import synthesize_german as synthesize
    _in_flight.add(key)
    try:
        if not await _speak(runner, event, text, synthesize):
            return failed_voice_text(text)
        _spoken.add(key)
        with suppress(OSError):
            _record(path, key)
        with suppress(Exception):
            runner._note_bot_reply(event.source)
        return None
    finally:
        _in_flight.discard(key)
