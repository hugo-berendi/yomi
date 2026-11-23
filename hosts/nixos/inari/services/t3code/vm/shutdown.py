"""Request ACPI shutdown and let systemd enforce its stop timeout."""

import json
import socket
import time
from pathlib import Path

path = Path("/var/lib/t3code-vm/qmp.sock")
try:
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(2)
        connection.connect(str(path))
        connection.recv(4096)
        for command in ["qmp_capabilities", "system_powerdown"]:
            connection.sendall(json.dumps({"execute": command}).encode() + b"\n")
            connection.recv(4096)
        connection.settimeout(25)
        deadline = time.monotonic() + 25
        while time.monotonic() < deadline and connection.recv(4096):
            pass
except (OSError, TimeoutError):
    pass
