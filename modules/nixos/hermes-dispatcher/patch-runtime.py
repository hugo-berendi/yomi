"""Keep the model choice at the Codex turn boundary; fail on upstream drift."""

from pathlib import Path
import sys


root = Path(sys.argv[1])
path = root / "agent/codex_runtime.py"
source = path.read_text()
old = """        turn = agent._codex_session.run_turn(
            user_input=user_message,
            model=wire_model, reasoning_effort=_codex_turn_effort(agent, wire_model),"""
new = """        from agent.ciel_routing import route_turn
        turn_model, turn_effort = route_turn(
            original_user_message, model=wire_model,
            effort=_codex_turn_effort(agent, wire_model))
        turn = agent._codex_session.run_turn(
            user_input=user_message,
            model=turn_model, reasoning_effort=turn_effort,"""
if source.count(old) != 1:
    raise SystemExit("Hermes Codex turn boundary changed; routing patch needs review")
path.write_text(source.replace(old, new, 1))

old = """    agent._codex_session = CodexAppServerSession(
        cwd=getattr(agent, "session_cwd", None) or str(resolve_agent_cwd()), approval_callback=approval_callback,"""
new = """    # Webhook turns (alert triage) run without Ciel's task tools or a shell.
    from agent.ciel_webhook_policy import client_factory as ciel_client_factory
    from agent.transports.codex_app_server import CodexAppServerClient as CielCodexClient
    ciel_factory = ciel_client_factory(agent, CielCodexClient)
    agent._codex_session = CodexAppServerSession(
        **({"client_factory": ciel_factory} if ciel_factory else {}),
        cwd=getattr(agent, "session_cwd", None) or str(resolve_agent_cwd()), approval_callback=approval_callback,"""
source = path.read_text()
if source.count(old) != 1:
    raise SystemExit(
        "Hermes Codex session construction changed; webhook policy patch needs review"
    )
path.write_text(source.replace(old, new, 1))

path = root / "plugins/platforms/matrix/adapter.py"
source = path.read_text()
old = """        self._wire_plugin_handlers(self._client)  # plugin-registered native handlers
        return True"""
new = """        self._wire_plugin_handlers(self._client)  # plugin-registered native handlers
        from agent.ciel_watch import watch
        self._ciel_watch_task = asyncio.create_task(watch(self))
        return True"""
if source.count(old) != 1:
    raise SystemExit(
        "Hermes Matrix connection changed; notification patch needs review"
    )
source = source.replace(old, new, 1)
old = """    async def disconnect(self) -> None:
        self._closing = True"""
new = """    async def disconnect(self) -> None:
        self._closing = True
        watch_task = getattr(self, "_ciel_watch_task", None)
        if watch_task is not None:
            watch_task.cancel()
            with suppress(asyncio.CancelledError):
                await watch_task
            self._ciel_watch_task = None"""
if source.count(old) != 1:
    raise SystemExit(
        "Hermes Matrix disconnect changed; notification patch needs review"
    )
path.write_text(source.replace(old, new, 1))

path = root / "gateway/session_execution.py"
source = path.read_text()
old = """            if not (cached and cached[1] == sig):
                return out"""
new = """            if not cached:
                return out
            if cached[1] != sig:
                out.evicted = self._pop_cached_agent_for_eviction()
                return out"""
if source.count(old) != 1:
    raise SystemExit("Hermes cache lookup changed; lifecycle patch needs review")
source = source.replace(old, new, 1)
old = """        self._runner._spawn_release_thread(
            self._runner._release_evicted_agent_soft, (agent,), f"agent-xproc-evict-{str(self._ctx.session_key)[:24]}","""
new = """        # Release this instance's Codex writer before the replacement resumes it.
        close_codex = getattr(agent, "_close_codex_session", None)
        if callable(close_codex):
            close_codex()
        self._runner._spawn_release_thread(
            self._runner._release_evicted_agent_soft, (agent,), f"agent-xproc-evict-{str(self._ctx.session_key)[:24]}","""
if source.count(old) != 1:
    raise SystemExit("Hermes cache teardown changed; lifecycle patch needs review")
path.write_text(source.replace(old, new, 1))

# The Codex app-server reports each finished agentMessage through the interim callback,
# which posts it as commentary or closes the stream segment. Both skip the stream
# consumer's silence hold, so an internal broker event answered with the bare silence
# marker reached Matrix before the whole-response filter ran. Drop it at the callback,
# with the same predicate and the same internal-event gate the final filter uses.
path = root / "gateway/run_turn_runner.py"
source = path.read_text()
old = """        def interim_assistant_cb(text: str, *, already_streamed: bool = False) -> None:
            if not ctx._run_still_current():
                return
"""
new = (
    old
    + """            from gateway.response_filters import (
                is_intentional_silence_response, is_machinery_display_kind)
            if (is_machinery_display_kind(ctx.persist_user_display_kind)
                    and is_intentional_silence_response(text)):
                if already_streamed and stream_consumer is not None:
                    # The held deltas sit in the consumer; a plain segment break would
                    # flush them, so ask for a break that discards exactly the marker.
                    stream_consumer.on_silent_segment_break()
                return
"""
)
if source.count(old) != 1:
    raise SystemExit("Hermes interim callback changed; silence patch needs review")
path.write_text(source.replace(old, new, 1))

# A dropped, already streamed marker stays in the consumer's buffer. Flushed at a plain
# segment break it would be sent, and left there it would prefix the next message of the
# turn ("[SILENT]<reply>", no tool boundary between them). The callback queues a break
# of its own that discards a buffer holding exactly the marker before the tick can push
# it. The intent travels in the queue item, so an earlier tool-boundary break cannot
# consume it.
path = root / "gateway/stream_consumer.py"
source = path.read_text()
for old, new in (
    (
        "_NEW_SEGMENT = object()\n",
        "_NEW_SEGMENT = object()\n_SILENT_SEGMENT = object()\n",
    ),
    (
        """    def on_segment_break(self) -> None:
        \"\"\"Finalize the current stream segment and start a fresh message.\"\"\"
        self._queue.put(_NEW_SEGMENT)
""",
        """    def on_segment_break(self) -> None:
        \"\"\"Finalize the current stream segment and start a fresh message.\"\"\"
        self._queue.put(_NEW_SEGMENT)

    def on_silent_segment_break(self) -> None:
        \"\"\"Segment break that discards a buffer holding only a silence marker.\"\"\"
        self._queue.put(_SILENT_SEGMENT)
""",
    ),
    (
        """            if item is _NEW_SEGMENT:
                tick.got_segment_break = True
                return tick
""",
        """            if item is _NEW_SEGMENT:
                tick.got_segment_break = True
                return tick
            if item is _SILENT_SEGMENT:
                if _is_intentional_silence_response(self._clean_for_display(self._accumulated)):
                    self._accumulated = self._stream_ledger = ""
                tick.got_segment_break = True
                return tick
""",
    ),
):
    if source.count(old) != 1:
        raise SystemExit("Hermes segment queue changed; silence patch needs review")
    source = source.replace(old, new, 1)
path.write_text(source)


# Keep approvals at the JSON-RPC consumer; the model cannot answer its own prompt.
def replace_once(relative, old, new):
    path = root / relative
    source = path.read_text()
    if source.count(old) != 1:
        raise SystemExit(f"Hermes approval boundary changed: {relative}")
    path.write_text(source.replace(old, new, 1))


replace_once(
    "agent/transports/codex_app_server_session.py",
    '        method = req.get("method", "")\n        rid = req.get("id")',
    """        method = req.get("method", "")
        if method == "mcpServer/elicitation/request":
            from agent.runtime_approvals import runtime_approval
            response = runtime_approval(self, req)
            if response is not None:
                client.respond(req.get("id"), response)
            return
        rid = req.get("id")""",
)
replace_once(
    "agent/transports/codex_app_server.py",
    "    def _dispatch(self, msg: dict) -> None:\n",
    """    def _dispatch(self, msg: dict) -> None:
        from agent.runtime_approvals import observe
        observe(self, msg)
""",
)
replace_once(
    "plugins/platforms/matrix/adapter.py",
    "        self._wire_plugin_handlers(self._client)  # plugin-registered native handlers",
    """        from agent.runtime_approvals import connect
        connect(self)
        self._wire_plugin_handlers(self._client)  # plugin-registered native handlers""",
)
replace_once(
    "plugins/platforms/matrix/adapter.py",
    "    async def disconnect(self) -> None:\n        self._closing = True",
    """    async def disconnect(self) -> None:
        from agent.runtime_approvals import disconnect
        disconnect(self)
        self._closing = True""",
)
replace_once(
    "plugins/platforms/matrix/adapter.py",
    "        for handler in (self._handle_approval_reaction, self._handle_model_picker_reaction,",
    """        from agent.runtime_approvals import reaction
        if await reaction(self, room_id, reacts_to, key, sender):
            return
        for handler in (self._handle_approval_reaction, self._handle_model_picker_reaction,""",
)

# Voice reply: Ciel opens a reply with [[voice]] to have it spoken. The marker has to be
# gone before any later step sees the text, and a spoken reply must not also go out as
# text, so the decision sits at the head of final delivery. A failure returns the text.
path = root / "gateway/run_turn_persistence.py"
source = path.read_text()
old = """        adapter = self._delivery_adapter_for(source)
        # Auto voice reply (TTS audio before the text) unless streaming TTS already delivered audio."""
new = """        if not agent_result.get("already_sent"):
            from agent.ciel_voice import prepare_reply
            response = await prepare_reply(self, event, response)
            if response is None:
                return None
        adapter = self._delivery_adapter_for(source)
        # Auto voice reply (TTS audio before the text) unless streaming TTS already delivered audio."""
if source.count(old) != 1:
    raise SystemExit("Hermes final delivery changed; voice patch needs review")
path.write_text(source.replace(old, new, 1))

# The queued-follow-up lane sends the finished reply itself, before the hook above runs,
# so a marked reply would reach Hugo as text with the marker in it. Strip it there; that
# lane stays text-only.
path = root / "gateway/run_turn.py"
source = path.read_text()
old = """        first_response = _delivery_result.get("final_response", "")
"""
new = (
    old
    + """        from agent.ciel_voice import split_marker
        first_response = split_marker(first_response)[1]
"""
)
if source.count(old) != 1:
    raise SystemExit("Hermes queued first response changed; voice patch needs review")
path.write_text(source.replace(old, new, 1))
