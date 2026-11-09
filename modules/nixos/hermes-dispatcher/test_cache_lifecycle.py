"""Exercise actual upstream methods without importing the whole gateway."""

import ast
from contextlib import suppress
import logging
import os
from pathlib import Path
import threading
from types import SimpleNamespace
import unittest


@unittest.skipUnless(
    os.environ.get("CIEL_HERMES_SOURCE"), "Requires built Hermes source"
)
class LifecycleTests(unittest.TestCase):
    def test_signature_change_releases_writer_before_async_cleanup(self):
        path = Path(os.environ["CIEL_HERMES_SOURCE"]) / "gateway/session_execution.py"
        cls = next(
            n
            for n in ast.parse(path.read_text()).body
            if isinstance(n, ast.ClassDef) and n.name == "GatewaySessionAgentMixin"
        )
        methods = [
            n
            for n in cls.body
            if isinstance(n, ast.FunctionDef)
            and n.name in {"_lookup_cached_agent", "_release_evicted_agent"}
        ]
        future = ast.ImportFrom(
            module="__future__", names=[ast.alias(name="annotations")], level=0
        )
        module = ast.fix_missing_locations(
            ast.Module(body=[future, *methods], type_ignores=[])
        )
        namespace = {"suppress": suppress, "logger": logging.getLogger(__name__)}
        exec(compile(module, str(path), "exec"), namespace)
        calls = []
        old = SimpleNamespace(_close_codex_session=lambda: calls.append("close-writer"))
        cache = {"session": (old, "old-signature", 1, "sid")}
        fake = SimpleNamespace(
            _ctx=SimpleNamespace(session_key="session"),
            _CachedAgentLookup=SimpleNamespace,
            _pop_cached_agent_for_eviction=lambda: cache.pop("session")[0],
            _runner=SimpleNamespace(
                _release_evicted_agent_soft=lambda agent: None,
                _spawn_release_thread=lambda *args, **kwargs: calls.append(
                    "spawn-cleanup"
                ),
            ),
        )
        result = namespace["_lookup_cached_agent"](
            fake, "new-signature", threading.RLock(), cache, 20, None, False, 1
        )
        self.assertIs(result.evicted, old)
        self.assertNotIn("session", cache)
        namespace["_release_evicted_agent"](fake, old)
        self.assertEqual(calls, ["close-writer", "spawn-cleanup"])


if __name__ == "__main__":
    unittest.main()
