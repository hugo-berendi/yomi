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
