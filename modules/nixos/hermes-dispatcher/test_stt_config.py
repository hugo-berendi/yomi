"""Voice transcription must not inherit Hermes' English-only language default."""

import ast
import json
import os
from pathlib import Path
import unittest


SOURCE = os.environ.get("CIEL_HERMES_SOURCE")
SETTINGS = os.environ.get("CIEL_HERMES_SETTINGS")


def literal_stt_defaults(root):
    tree = ast.parse((root / "hermes_cli/config_defaults.py").read_text())
    config = next(
        node.value
        for node in tree.body
        if isinstance(node, ast.Assign)
        and any(getattr(t, "id", "") == "DEFAULT_CONFIG" for t in node.targets)
    )
    stt = next(
        value
        for key, value in zip(config.keys, config.values)
        if isinstance(key, ast.Constant) and key.value == "stt"
    )
    return ast.literal_eval(stt)


def merge(base, override):
    # Same precedence as Hermes' config loader: the user's file wins per key.
    out = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(out.get(key), dict):
            out[key] = merge(out[key], value)
        else:
            out[key] = value
    return out


def language_resolver(root):
    """Compile the real upstream resolver, not a copy of its rules."""
    functions = {}
    for rel, wanted in (
        ("tools/tts_command_provider.py", "_get_provider_section"),
        ("tools/transcription_tools.py", "_resolve_stt_language"),
    ):
        tree = ast.parse((root / rel).read_text())
        functions[wanted] = next(
            n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == wanted
        )
    module = ast.fix_missing_locations(
        ast.Module(
            body=[
                ast.ImportFrom(
                    module="__future__",
                    names=[ast.alias(name="annotations")],
                    level=0,
                ),
                *functions.values(),
            ],
            type_ignores=[],
        )
    )
    namespace = {
        "os": os,
        "Optional": None,
        "Any": None,
        "LOCAL_STT_LANGUAGE_ENV": "HERMES_LOCAL_STT_LANGUAGE",
    }
    # _resolve_stt_language calls the provider-section helper by this alias.
    namespace["_get_stt_section"] = None
    exec(compile(module, "upstream-stt", "exec"), namespace)
    namespace["_get_stt_section"] = namespace["_get_provider_section"]
    return namespace["_resolve_stt_language"]


@unittest.skipUnless(SOURCE and SETTINGS, "Requires built Hermes source and settings")
class SttConfigTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(SOURCE)
        self.defaults = literal_stt_defaults(self.root)
        self.ours = json.loads(Path(SETTINGS).read_text()).get("stt", {})
        self.resolve = language_resolver(self.root)
        os.environ.pop("HERMES_LOCAL_STT_LANGUAGE", None)

    def test_upstream_default_forces_english(self):
        # This is the bug: a German clip decoded with language="en" comes back
        # as English text. If upstream drops the default, review stt.nix.
        self.assertEqual(self.resolve("local", self.defaults), "en")

    def test_our_config_decodes_german_not_english(self):
        merged = merge(self.defaults, self.ours)
        self.assertEqual(self.resolve("local", merged), "de")

    def test_model_is_a_prefetched_local_directory(self):
        # A bare size name triggers a Hugging Face download on the first message.
        model = Path(self.ours.get("local", {}).get("model", ""))
        self.assertTrue(model.is_absolute())
        for name in ("config.json", "model.bin", "tokenizer.json", "vocabulary.txt"):
            self.assertTrue((model / name).is_file(), name)

    def test_engine_stays_local_and_cpu_pinned(self):
        self.assertEqual(self.ours.get("provider"), "local")
        self.assertEqual(self.ours.get("local", {}).get("device"), "cpu")
        self.assertEqual(self.ours.get("local", {}).get("compute_type"), "int8")


if __name__ == "__main__":
    unittest.main()
