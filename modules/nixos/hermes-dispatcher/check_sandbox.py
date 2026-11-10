"""Offline sandbox integration check; run only in the disposable t3code-vm guest."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import pwd
import shlex
import shutil
import socket
import subprocess
import tempfile
import tomllib


FIXTURE_TEXT = "Ciel synthetic attachment: Prüfung, Größe, Übung, Äpfel"


def pdf_fixture():
    # Standard 14 fonts with WinAnsiEncoding map these cp1252 bytes to umlauts.
    text = FIXTURE_TEXT.encode("cp1252")
    stream = b"BT /F1 12 Tf 20 100 Td (" + text + b") Tj ET"
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 150] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
        b"<< /Length "
        + str(len(stream)).encode()
        + b" >>\nstream\n"
        + stream
        + b"\nendstream",
    ]
    data = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for number, obj in enumerate(objects, 1):
        offsets.append(len(data))
        data.extend(f"{number} 0 obj\n".encode() + obj + b"\nendobj\n")
    xref = len(data)
    data.extend(b"xref\n0 6\n0000000000 65535 f \n")
    for offset in offsets[1:]:
        data.extend(f"{offset:010d} 00000 n \n".encode())
    data.extend(
        f"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    )
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", type=Path)
    parser.add_argument(
        "--codex", help="Optional baseline executable for red/green comparison"
    )
    args = parser.parse_args()
    if socket.gethostname() != "t3code-vm" or os.geteuid() == 0:
        parser.error(
            "Run as the ordinary guest user on t3code-vm, never on a production host"
        )
    settings = json.loads(args.config.read_text())
    user = pwd.getpwuid(os.getuid()).pw_name
    parent = Path("/var/lib/ciel-sandbox-fixtures")
    subprocess.run(
        ["sudo", "-n", "install", "-d", "-m", "700", "-o", user, str(parent)],
        check=True,
    )
    with tempfile.TemporaryDirectory(prefix="check-", dir=parent) as directory:
        root = Path(directory)
        home = root / "home"
        home.mkdir()
        codex_home = root / "codex"
        codex_home.mkdir()
        shutil.copyfile(settings["codexConfig"], codex_home / "config.toml")
        codex_config = tomllib.loads((codex_home / "config.toml").read_text())
        profile = codex_config["default_permissions"]
        assert profile == ":read-only", profile
        # Codex wraps model commands as `/bin/sh -lc` unless login shells are off.
        shell = [
            "/bin/sh",
            "-lc" if codex_config.get("allow_login_shell", True) else "-c",
        ]
        fixture = (
            root
            / "hermes/cache/documents/native-inputs/Synthetic attachment fixture.pdf"
        )
        fixture.parent.mkdir(parents=True)
        fixture.write_bytes(pdf_fixture())
        secret = root / "unrelated-secret"
        secret.write_text("synthetic forbidden value")
        config_hash = hashlib.sha256(args.config.read_bytes()).hexdigest()
        results = []

        def sandbox(name, command, expected_exit=0):
            invocation = [
                "sudo",
                "-n",
                "systemd-run",
                "--quiet",
                "--wait",
                "--pipe",
                "--collect",
                f"--unit=ciel-sandbox-{root.name}-{name}",
            ]
            properties = settings["serviceConfig"] | {
                "User": user,
                "WorkingDirectory": str(home),
                "ReadWritePaths": [str(root)],
                "InaccessiblePaths": [str(secret)],
            }
            for key, value in properties.items():
                if isinstance(value, bool):
                    value = "yes" if value else "no"
                elif isinstance(value, list):
                    value = " ".join(value)
                invocation += ["-p", f"{key}={value}"]
            invocation += [
                "--setenv=HOME=" + str(home),
                "--setenv=CODEX_HOME=" + str(codex_home),
                "--setenv=PATH=" + settings["path"],
                args.codex or settings["codex"],
                "sandbox",
                "--permission-profile",
                profile,
                "--cd",
                str(home),
                "--",
                *command,
            ]
            result = subprocess.run(
                invocation,
                capture_output=True,
                text=True,
                encoding="utf-8",
                timeout=60,
            )
            results.append({"name": name, "exit_code": result.returncode})
            if result.returncode != expected_exit:
                raise AssertionError(
                    f"{name}: exit {result.returncode}\n{result.stderr}"
                )
            return result.stdout

        quoted = shlex.quote(str(fixture))
        # Reproduces the reported failure: the NixOS login profile replaces PATH.
        sandbox(
            "login-shell-path",
            ["/bin/sh", "-lc", "command -v file pdftotext"],
            expected_exit=1,
        )
        assert "PDF document" in sandbox("file", [*shell, f"file --brief {quoted}"])
        extracted = sandbox("extract", [*shell, f"pdftotext {quoted} -"])
        assert extracted.strip() == FIXTURE_TEXT, extracted
        # Test writes both inside the service's writable state and outside the cwd.
        # The outer unit allows them; Codex's read-only policy must reject them.
        # A reachable guest loopback listener makes a network escape observable.
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen(4)
            port = listener.getsockname()[1]
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                pass
            sandbox(
                "restrictions",
                [
                    settings["python"],
                    "-c",
                    "\n".join(
                        [
                            "import errno, pathlib, socket",
                            f"targets = {[str(home / 'forbidden'), str(root / 'forbidden'), str(fixture)]!r}",
                            "for target in targets:",
                            "    try:",
                            "        with open(target, 'ab'): pass",
                            "    except OSError as e:",
                            "        assert e.errno in (errno.EACCES, errno.EPERM, errno.EROFS), e",
                            "    else: raise AssertionError('write escaped sandbox')",
                            "try:",
                            f"    pathlib.Path({str(secret)!r}).read_text()",
                            "except PermissionError: pass",
                            "else: raise AssertionError('read escaped service mask')",
                            "try:",
                            "    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)",
                            "    s.settimeout(1)",
                            f"    s.connect(('127.0.0.1', {port}))",
                            "except OSError as e:",
                            "    assert e.errno in (errno.EACCES, errno.EPERM, errno.ENETUNREACH, errno.ECONNREFUSED, errno.ETIMEDOUT) or isinstance(e, TimeoutError), e",
                            "else: raise AssertionError('network escaped sandbox')",
                        ]
                    ),
                ],
            )
        assert fixture.read_bytes() == pdf_fixture()
        assert not (home / "forbidden").exists()
        assert not (root / "forbidden").exists()
        print(
            json.dumps(
                {
                    "config_sha256": config_hash,
                    "results": results,
                    "fixture": "synthetic PDF only",
                }
            )
        )
    print("Fixture cleanup complete")


if __name__ == "__main__":
    main()
