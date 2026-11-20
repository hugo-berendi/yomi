import os
import subprocess
import unittest
from pathlib import Path


class FlakeCheckTests(unittest.TestCase):
    def test_failed_output_enumeration_fails_check(self):
        script = Path(__file__).resolve().parents[1] / "scripts/ci/flake-check.sh"
        fake_nix = """
        nix() {
            case "${4:-}" in
                *"#$FAILED_OUTPUT.x86_64-linux")
                    return 23 ;;
            esac
        }
        export -f nix
        bash "$1"
        """
        for output in ("checks", "packages", "devShells"):
            with self.subTest(output=output):
                result = subprocess.run(
                    ["bash", "-c", fake_nix, "flake-check-test", script],
                    env={**os.environ, "FAILED_OUTPUT": output},
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(f"{output}.x86_64-linux", result.stderr)
