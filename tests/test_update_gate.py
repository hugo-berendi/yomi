import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/ci/update-gate.py"
spec = importlib.util.spec_from_file_location("update_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)

REV_A = "a" * 40
REV_B = "b" * 40
HASH_A = "sha256-" + "A" * 43 + "="
HASH_B = "sha256-" + "B" * 43 + "="
DIGEST_A = "1" * 64
DIGEST_B = "2" * 64


def lock(rev=REV_A, locked=None, original=None, inputs=None, extra_nodes=None):
    nixpkgs = {
        "locked": locked
        or {
            "type": "github",
            "owner": "NixOS",
            "repo": "nixpkgs",
            "rev": rev,
            "narHash": HASH_A,
            "lastModified": 1,
        },
        "original": original or {"type": "github", "owner": "NixOS", "repo": "nixpkgs"},
    }
    nodes = {"root": {"inputs": inputs or {"nixpkgs": "nixpkgs"}}, "nixpkgs": nixpkgs}
    nodes.update(extra_nodes or {})
    return json.dumps({"nodes": nodes, "root": "root", "version": 7})


def tarball(url):
    return {
        "type": "tarball",
        "url": url,
        "narHash": HASH_A,
        "lastModified": 1,
    }


def run(files_old, files_new, status=None):
    """Run the pure gate over dicts of path -> text; status defaults to M/A by presence."""
    paths = sorted(set(files_old) | set(files_new))
    status = status or {}
    entries = []
    for path in paths:
        default = "M" if path in files_old and path in files_new else "A"
        entries.append((status.get(path, default), path))
    return gate.check_changes(entries, files_old.__getitem__, files_new.__getitem__)


def lock_run(old, new):
    return run({"flake.lock": old}, {"flake.lock": new})


class FlakeLockTests(unittest.TestCase):
    def test_rev_bump_ok(self):
        reasons, summary = lock_run(lock(REV_A), lock(REV_B))
        self.assertEqual(reasons, [])
        self.assertEqual(summary, ["nixpkgs: aaaaaaa -> bbbbbbb"])

    def test_tarball_url_same_host_ok(self):
        old = lock(locked=tarball("https://releases.nixos.org/a/x.tar.zst"))
        new = lock(locked=tarball("https://releases.nixos.org/b/y.tar.zst"))
        self.assertEqual(lock_run(old, new)[0], [])

    def test_tarball_host_change_rejected(self):
        old = lock(locked=tarball("https://releases.nixos.org/a.tar.zst"))
        new = lock(locked=tarball("https://evil.example/a.tar.zst"))
        self.assertTrue(lock_run(old, new)[0])

    def test_tarball_scheme_change_rejected(self):
        old = lock(locked=tarball("https://releases.nixos.org/a.tar.zst"))
        new = lock(locked=tarball("http://releases.nixos.org/a.tar.zst"))
        self.assertTrue(lock_run(old, new)[0])

    def test_new_node_rejected(self):
        extra = {"evil": {"locked": {"type": "github", "owner": "x", "repo": "y"}}}
        self.assertTrue(lock_run(lock(), lock(extra_nodes=extra))[0])

    def test_changed_owner_rejected(self):
        locked = json.loads(lock())["nodes"]["nixpkgs"]["locked"]
        locked["owner"] = "attacker"
        self.assertTrue(lock_run(lock(), lock(locked=locked))[0])

    def test_changed_original_url_rejected(self):
        old = lock(original={"type": "git", "url": "https://a.example/r.git"})
        new = lock(original={"type": "git", "url": "https://b.example/r.git"})
        self.assertTrue(lock_run(old, new)[0])

    def test_changed_inputs_rejected(self):
        a = {
            "x": {"inputs": {"nixpkgs": ["nixpkgs"]}, "locked": tarball("https://h/a")}
        }
        b = {"x": {"inputs": {"nixpkgs": "nixpkgs"}, "locked": tarball("https://h/a")}}
        self.assertTrue(lock_run(lock(extra_nodes=a), lock(extra_nodes=b))[0])

    def test_invalid_json_rejected(self):
        self.assertTrue(lock_run(lock(), "{not json")[0])


PKG_OLD = f"""{{
  version = "1.2";
  src = fetchurl {{
    url = "https://example.org/a.tar.gz";
    hash = "{HASH_A}";
  }};
}}
"""


class PackageTests(unittest.TestCase):
    def pkg(self, new):
        return run({"pkgs/helium.nix": PKG_OLD}, {"pkgs/helium.nix": new})

    def test_version_and_hash_bump_ok(self):
        new = PKG_OLD.replace("1.2", "1.3").replace(HASH_A, HASH_B)
        reasons, summary = self.pkg(new)
        self.assertEqual(reasons, [])
        self.assertIn("pkgs/helium.nix: version 1.2 -> 1.3", summary)

    def test_url_change_rejected(self):
        self.assertTrue(self.pkg(PKG_OLD.replace("example.org", "evil.example"))[0])

    def test_src_rewrite_rejected(self):
        new = PKG_OLD.replace("fetchurl {", "fetchFromGitHub {")
        self.assertTrue(self.pkg(new)[0])

    def test_interpolated_version_rejected(self):
        self.assertTrue(self.pkg(PKG_OLD.replace("1.2", "${evil}"))[0])

    def test_bad_hash_rejected(self):
        self.assertTrue(self.pkg(PKG_OLD.replace(HASH_A, "sha256-short"))[0])

    def test_added_line_rejected(self):
        self.assertTrue(self.pkg(PKG_OLD + '  version = "9";\n')[0])

    def test_added_file_rejected(self):
        reasons, _ = run({}, {"pkgs/new.nix": PKG_OLD})
        self.assertTrue(reasons)

    def test_nested_pkgs_path_rejected(self):
        reasons, _ = run(
            {"pkgs/a/b.nix": PKG_OLD}, {"pkgs/a/b.nix": PKG_OLD.replace("1.2", "1.3")}
        )
        self.assertTrue(reasons)


IMAGES_OLD = f"""{{
  valheim = "ghcr.io/lloesche/valheim-server:v1@sha256:{DIGEST_A}";
}}
"""


class ImageTests(unittest.TestCase):
    def images(self, new):
        return run({gate.IMAGES: IMAGES_OLD}, {gate.IMAGES: new})

    def test_digest_bump_ok(self):
        self.assertEqual(self.images(IMAGES_OLD.replace(DIGEST_A, DIGEST_B))[0], [])

    def test_repo_swap_rejected(self):
        new = IMAGES_OLD.replace("ghcr.io/lloesche", "evil.example/x").replace(
            DIGEST_A, DIGEST_B
        )
        self.assertTrue(self.images(new)[0])

    def test_tag_change_rejected(self):
        new = IMAGES_OLD.replace(":v1", ":v2").replace(DIGEST_A, DIGEST_B)
        self.assertTrue(self.images(new)[0])


class PathPolicyTests(unittest.TestCase):
    def test_flake_nix_rejected(self):
        reasons, _ = run({"flake.nix": "a"}, {"flake.nix": "b"})
        self.assertTrue(reasons)

    def test_workflow_rejected_alongside_ok_lock(self):
        old = {"flake.lock": lock(REV_A), ".forgejo/workflows/x.yml": "a"}
        new = {"flake.lock": lock(REV_B), ".forgejo/workflows/x.yml": "b"}
        self.assertEqual(len(run(old, new)[0]), 1)

    def test_empty_diff_rejected(self):
        reasons, _ = gate.check_changes([], None, None)
        self.assertIn("nothing to merge", reasons[0])

    def test_oversize_rejected(self):
        def read(path):
            raise ValueError("file exceeds limit")

        reasons, _ = gate.check_changes([("M", "flake.lock")], read, read)
        self.assertTrue(reasons)


class CliTests(unittest.TestCase):
    def git(self, cwd, *args):
        subprocess.run(
            [
                "git",
                "-c",
                "user.name=t",
                "-c",
                "user.email=t@t",
                "-c",
                "commit.gpgsign=false",
                *args,
            ],
            cwd=cwd,
            check=True,
            capture_output=True,
        )

    def gate(self, cwd, base):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--base", base],
            cwd=cwd,
            capture_output=True,
            text=True,
        )
        return result.returncode, result.stdout

    def repo(self, base_files, new_files):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        cwd = Path(tmp.name)
        self.git(cwd, "init", "-q")
        for files, message in ((base_files, "base"), (new_files, "change")):
            for name, text in files.items():
                (cwd / name).parent.mkdir(parents=True, exist_ok=True)
                (cwd / name).write_text(text)
            self.git(cwd, "add", "-A")
            self.git(cwd, "commit", "-q", "-m", message, "--allow-empty")
            if message == "base":
                self.git(cwd, "tag", "base")
        return cwd

    def test_ok_exits_zero(self):
        cwd = self.repo({"flake.lock": lock(REV_A)}, {"flake.lock": lock(REV_B)})
        code, out = self.gate(cwd, "base")
        self.assertEqual(code, 0)
        self.assertTrue(json.loads(out)["ok"])

    def test_violation_exits_one(self):
        cwd = self.repo(
            {"flake.lock": lock(REV_A)}, {"flake.lock": lock(REV_B), "flake.nix": "x"}
        )
        code, out = self.gate(cwd, "base")
        self.assertEqual(code, 1)
        self.assertFalse(json.loads(out)["ok"])

    def test_empty_diff_exits_one(self):
        cwd = self.repo({"flake.lock": lock()}, {})
        self.assertEqual(self.gate(cwd, "base")[0], 1)

    def test_bad_ref_exits_two(self):
        cwd = self.repo({"flake.lock": lock()}, {"flake.lock": lock(REV_B)})
        code, out = self.gate(cwd, "no-such-ref")
        self.assertEqual(code, 2)
        self.assertFalse(json.loads(out)["ok"])


if __name__ == "__main__":
    unittest.main()
