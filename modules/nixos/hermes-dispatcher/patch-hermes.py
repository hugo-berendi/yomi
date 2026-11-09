"""Fail closed on upstream adapter changes instead of silently losing the boundary."""

from pathlib import Path
import sys


root = Path(sys.argv[1])
adapter = root / "plugins/platforms/signal/adapter.py"
source = adapter.read_text()
replacements = {
    "        self.client = httpx.AsyncClient(timeout=30.0, limits=platform_httpx_limits())": "        from .signal_unix import SignalUnixClient\n"
    "        self.client = SignalUnixClient(extra_socket_path(), self.account)",
    '        envelope_data = envelope.get("envelope", envelope)': "        from .signal_unix import self_note\n"
    "        if self_note(envelope, self.account) is None:\n"
    "            return\n"
    '        envelope_data = envelope.get("envelope", envelope)',
    '        if not chat_id or chat_id.startswith("group:") or not _looks_like_e164_number(chat_id):': "        if chat_id == self._account_normalized:\n"
    "            return chat_id\n"
    '        if not chat_id or chat_id.startswith("group:") or not _looks_like_e164_number(chat_id):',
}
for old, new in replacements.items():
    if source.count(old) != 1:
        raise SystemExit(f"Hermes Signal adapter changed: {old!r}")
    source = source.replace(old, new, 1)
source += '\n\ndef extra_socket_path():\n    import os\n    return os.environ["YOMI_SIGNAL_SOCKET"]\n'
adapter.write_text(source)
