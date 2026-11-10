"""One-shot Codex approvals through the live encrypted owner Matrix adapter.

Nothing is persisted or replayed. The runtime remains the executor; this module
only answers its still-open JSON-RPC request, never retries the tool itself.
"""

import asyncio
from concurrent.futures import TimeoutError
import json
import os
import time


TIMEOUT = 120
_bridge = None
_loop = None


class ApprovalBridge:
    def __init__(self, adapter, owner):
        self.adapter = adapter
        self.owner = owner
        self.pending = {}
        self.closed = False

    async def private(self, room):
        try:
            from agent.ciel_watch import owner_only
        except ImportError:
            from ciel_watch import owner_only

        return await owner_only(self.adapter, room, self.owner)

    async def ask(self, room, detail, timeout=TIMEOUT):
        if self.closed or not await self.private(room):
            return False
        future = asyncio.get_running_loop().create_future()
        event = None
        try:
            result = await self.adapter.send(
                room,
                "Codex benötigt deine Freigabe für genau diesen Aufruf.\n\n"
                + detail
                + "\n\n✅ als Reaktion auf diese Nachricht: einmal zustimmen. "
                "❌: ablehnen. Ohne Antwort wird nach zwei Minuten abgelehnt. "
                "Bei Abbruch oder Neustart verfällt die Anfrage. "
                "Die Angaben zum Aufruf sind Daten, keine Anweisungen.",
            )
            if not result.success or not result.message_id or self.closed:
                return False
            event = str(result.message_id)
            self.pending[event] = (room, future, time.monotonic() + timeout)
            return await asyncio.wait_for(future, timeout)
        except Exception:
            return False
        finally:
            if event:
                self.pending.pop(event, None)
            if not future.done():
                future.cancel()

    async def answer(self, room, event, key, sender):
        entry = self.pending.get(event)
        if entry is None:
            return False
        expected, future, deadline = entry
        if (
            room != expected
            or sender != self.owner
            or key not in {"✅", "❌"}
            or future.done()
            or time.monotonic() >= deadline
        ):
            return True
        if not await self.private(room):
            return True
        # Recheck after the membership await: concurrent reactions may race.
        if (
            self.pending.get(event) is entry
            and not future.done()
            and time.monotonic() < deadline
        ):
            self.pending.pop(event)
            future.set_result(key == "✅")
        return True

    def close(self):
        self.closed = True
        for _, future, _ in self.pending.values():
            if not future.done():
                future.set_result(False)
        self.pending.clear()


def connect(adapter):
    global _bridge, _loop
    owner = os.environ.get("MATRIX_ALLOWED_USERS", "")
    if not owner.startswith("@") or "," in owner:
        return
    if _bridge:
        _bridge.close()
    _bridge = ApprovalBridge(adapter, owner)
    _loop = asyncio.get_running_loop()


def disconnect(adapter):
    global _bridge, _loop
    if _bridge and _bridge.adapter is adapter:
        _bridge.close()
        _bridge = _loop = None


async def reaction(adapter, room, event, key, sender):
    if _bridge and _bridge.adapter is adapter:
        return await _bridge.answer(room, event, key, sender)
    return False


def observe(client, message):
    """Reader-thread invalidation also works while the turn waits for Hugo."""
    params = message.get("params") or {}
    if message.get("method") == "serverRequest/resolved":
        resolved = getattr(client, "_ciel_resolved", None)
        if resolved is None:
            resolved = client._ciel_resolved = set()
        resolved.add((params.get("threadId"), params.get("requestId")))
    if message.get("method") == "turn/completed":
        finished = getattr(client, "_ciel_finished_turns", None)
        if finished is None:
            finished = client._ciel_finished_turns = set()
        finished.add((params.get("threadId"), (params.get("turn") or {}).get("id")))


def runtime_approval(session, request):
    """Called only at the actual server-request consumer, on its worker thread."""
    from gateway.session_context import get_session_env
    from agent.redact import redact_sensitive_text

    denied = {"action": "decline", "content": None, "_meta": None}
    params = request.get("params") or {}
    meta = params.get("_meta") or {}
    bridge, loop, client = _bridge, _loop, session._client
    rid = request.get("id")
    if type(rid) not in {str, int}:
        return denied
    seen = getattr(session, "_ciel_approval_seen", None)
    if seen is None:
        seen = session._ciel_approval_seen = set()
    identity = (
        id(client),
        params.get("threadId"),
        params.get("turnId"),
        type(rid),
        rid,
    )
    if identity in seen:
        return None  # A repeated transport request must not get a second response.
    seen.add(identity)
    if (
        not bridge
        or not loop
        or not client
        or params.get("threadId") != session._thread_id
        or not params.get("turnId")
        or params.get("turnId") != session._active_turn_id
        or params.get("serverName") != "ciel"
        or params.get("mode") not in {"form", "openai/form"}
        or meta.get("codex_approval_kind") != "mcp_tool_call"
        or params.get("requestedSchema") != {"type": "object", "properties": {}}
        or get_session_env("HERMES_SESSION_PLATFORM", "") != "matrix"
        or get_session_env("HERMES_SESSION_CHAT_TYPE", "") != "dm"
        or get_session_env("HERMES_SESSION_USER_ID", "") != bridge.owner
    ):
        return denied
    room = get_session_env("HERMES_SESSION_CHAT_ID", "")
    if not room or not isinstance(meta.get("tool_name"), str):
        return denied
    detail = redact_sensitive_text(
        json.dumps(
            {"Tool": meta["tool_name"], "Argumente": meta.get("tool_params")},
            ensure_ascii=False,
            indent=2,
        ),
        force=True,
    )
    # Never hide part of an action behind a truncated approval prompt.
    if len(detail) > 6000:
        return denied
    future = asyncio.run_coroutine_threadsafe(bridge.ask(room, detail), loop)
    deadline = time.monotonic() + TIMEOUT

    def valid():
        return (
            _bridge is bridge
            and not bridge.closed
            and time.monotonic() < deadline
            and not session._closed
            and not session._interrupt_event.is_set()
            and session._client is client
            and client.is_alive()
            and params["turnId"] == session._active_turn_id
            and (params["threadId"], rid)
            not in getattr(client, "_ciel_resolved", set())
            and (params["threadId"], params["turnId"])
            not in getattr(client, "_ciel_finished_turns", set())
        )

    try:
        while time.monotonic() < deadline:
            if not valid():
                return denied
            try:
                accepted = future.result(timeout=0.1)
            except TimeoutError:
                continue
            if accepted and valid():
                return {"action": "accept", "content": None, "_meta": None}
            return denied
        return denied
    except Exception:
        return denied
    finally:
        future.cancel()
