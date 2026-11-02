import json
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).parents[1] / "scripts/ops"))
import t3code_workspace as workspace


def git(directory, *args):
    return subprocess.run(
        ["git", "-C", str(directory), *args],
        check=True,
        capture_output=True,
        text=True,
    )


class WorkspaceTests(unittest.TestCase):
    def make_repo(self, root):
        repo = root / "repo"
        repo.mkdir()
        git(repo, "init", "-q")
        git(repo, "config", "user.name", "Test User")
        git(repo, "config", "user.email", "test@example.invalid")
        (repo / "tracked.txt").write_text("base\n")
        executable = repo / "run.sh"
        executable.write_text("#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)
        git(repo, "add", ".")
        git(repo, "commit", "-qm", "base")
        return repo

    def test_prepare_receive_restores_dirty_snapshot_and_git_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            (repo / "tracked.txt").write_text("unstaged\n")
            git(repo, "add", "tracked.txt")
            (repo / "tracked.txt").write_text("staged-then-unstaged\n")
            (repo / "run.sh").unlink()
            (repo / "untracked.txt").write_text("untracked\n")
            (repo / "link").symlink_to("untracked.txt")
            archive = root / "snapshot.tar"
            workspace.prepare(repo, "run-1", archive)

            target = root / "workspaces"
            workspace.receive(archive, target, "run-1")
            restored = target / "run-1"
            self.assertEqual(
                (restored / "tracked.txt").read_text(), "staged-then-unstaged\n"
            )
            self.assertFalse((restored / "run.sh").exists())
            self.assertEqual((restored / "untracked.txt").read_text(), "untracked\n")
            self.assertTrue((restored / "link").is_symlink())
            self.assertEqual(
                git(restored, "log", "-1", "--format=%an").stdout.strip(), "Test User"
            )
            manifest = json.loads((restored / ".git/t3-test/manifest.json").read_text())
            self.assertEqual(
                manifest["commit"], git(repo, "rev-parse", "HEAD").stdout.strip()
            )

    def test_prepare_rejects_tracked_secret_without_explicit_selection(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = self.make_repo(Path(directory))
            secret = repo / ".env"
            secret.write_text("TOKEN=secret\n")
            git(repo, "add", secret.name)
            with self.assertRaises(workspace.WorkspaceError):
                workspace.prepare(repo, "run-1", Path(directory) / "snapshot.tar")
            workspace.prepare(
                repo,
                "run-1",
                Path(directory) / "selected.tar",
                include_paths=[".env"],
            )

    def test_prepare_rejects_symlink_chain_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            (repo / "folder").mkdir()
            (repo / "inside").mkdir()
            (repo / "folder/link").symlink_to("../inside")
            # Lexically stays inside the root, but resolving link before '..'
            # walks above it. Checking each link's spelling misses this case.
            (repo / "escape").symlink_to("folder/link/../..")
            with self.assertRaises(workspace.WorkspaceError):
                workspace.prepare(repo, "run-1", root / "snapshot.tar")

    def test_receive_rejects_traversal_and_unsafe_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "bad.tar"
            with tarfile.open(archive, "w") as tar:
                for name, content in (
                    ("manifest.json", b"{}"),
                    ("git.bundle", b"not a bundle"),
                    ("tree/../../escape", b"bad"),
                ):
                    info = tarfile.TarInfo(name)
                    info.size = len(content)
                    tar.addfile(info, __import__("io").BytesIO(content))
            with self.assertRaises(workspace.WorkspaceError):
                workspace.receive(archive, Path(directory) / "root", "run-1")

    def test_runs_serialize_on_global_workspace_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            archive = root / "snapshot.tar"
            workspace.prepare(repo, "run-1", archive)
            work_root = root / "workspaces"
            workspace.receive(archive, work_root, "run-1")
            first = threading.Thread(
                target=workspace.run,
                args=(
                    work_root,
                    "run-1",
                    5,
                    [sys.executable, "-c", "import time; time.sleep(.2)"],
                ),
            )
            first.start()
            for _ in range(50):
                if (work_root / "run-1" / ".git/t3-test/run.active").exists():
                    break
                time.sleep(0.01)
            started = time.monotonic()
            second = threading.Thread(
                target=workspace.run,
                args=(work_root, "run-1", 5, [sys.executable, "-c", "exit(0)"]),
            )
            second.start()
            first.join()
            second.join()
            self.assertGreaterEqual(time.monotonic() - started, 0.15)

    def test_run_records_timeout_and_cleanup_stays_inside_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = self.make_repo(root)
            archive = root / "snapshot.tar"
            workspace.prepare(repo, "run-1", archive)
            work_root = root / "workspaces"
            workspace.receive(archive, work_root, "run-1")
            result = workspace.run(
                work_root,
                "run-1",
                0.1,
                [sys.executable, "-c", "import time; time.sleep(10)"],
            )
            self.assertTrue(result["timed_out"])
            self.assertNotEqual(result["exit_code"], 0)
            self.assertTrue((work_root / "run-1" / ".git/t3-test/run.json").exists())
            with self.assertRaises(workspace.WorkspaceError):
                workspace.cleanup(work_root, "../run-1")
            workspace.cleanup(work_root, "run-1")
            self.assertFalse((work_root / "run-1").exists())


if __name__ == "__main__":
    unittest.main()
