import json
import socket


def broker_call(path, operation, arguments=None):
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(45)
        connection.connect(path)
        connection.sendall(
            json.dumps({"operation": operation, "arguments": arguments or {}}).encode()
            + b"\n"
        )
        with connection.makefile("rb") as stream:
            line = stream.readline(1_000_001)
        if len(line) > 1_000_000:
            raise ValueError("Broker response too large")
        result = json.loads(line)
        if "error" in result:
            raise ValueError(result["error"])
        return result["result"]
