"""The one place that touches Hermes' TTS tool, so tests can replace it."""

from __future__ import annotations

from gateway.platforms.base import build_auto_tts_output_path
from gateway.config import Platform
from tools.tts_text_normalize import _strip_markdown_for_tts
from tools.tts_tool import text_to_speech_tool


def synthesize_german(text: str) -> str:
    spoken = _strip_markdown_for_tts(text)
    return text_to_speech_tool(
        text=spoken, output_path=build_auto_tts_output_path(Platform.MATRIX)
    )
