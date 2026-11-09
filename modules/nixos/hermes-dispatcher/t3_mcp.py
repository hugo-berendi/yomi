"""Streamable HTTP MCP client with durable mutation receipts across restarts."""

import hashlib
import json
from urllib.error import HTTPError

from t3_mcp_auth import decode_json, post_json


READS = {
    "t3_project_list",
    "t3_thread_read",
    "t3_thread_configure",
    "t3_pending_request",
    "orchestrator_capabilities",
}
WRITES = {
    "t3_thread_launch",
    "t3_thread_send",
    "t3_thread_interrupt",
    "t3_thread_configure",
    "t3_pending_request",
    "t3_thread_organize",
}


def is_mutation(name, args):
    """Reads may repeat freely; every write needs a durable receipt key."""
    if name == "t3_thread_configure":
        return "modelSelection" in args
    if name == "t3_pending_request":
        # list/read only observe; respond answers a worker's question.
        return args.get("action") not in {"list", "read"}
    return name not in READS


class NativeMcp:
    def __init__(self, config, auth, store, post=post_json):
        self.config, self.auth, self.store, self.post = config, auth, store, post
        self.session = None
        self.generation = None
        self.mutation_generation = None
        self.offered = None
        self.store.db.execute(
            "CREATE TABLE IF NOT EXISTS mcp_calls (key TEXT PRIMARY KEY, digest TEXT NOT NULL, generation TEXT NOT NULL, result TEXT)"
        )
        self.store.db.commit()

    def request(self, method, params):
        credentials = self.auth.credentials()
        if (
            self.mutation_generation is not None
            and credentials["generation"] != self.mutation_generation
        ):
            raise ValueError(
                "MCP login changed during an uncertain mutation; reconcile before retrying"
            )
        if credentials["generation"] != self.generation:
            self.generation, self.session = credentials["generation"], None

        def send(body, session=None):
            headers = {
                "Accept": "application/json, text/event-stream",
                "Authorization": "Bearer " + credentials["access_token"],
            }
            if session:
                headers.update(
                    {"Mcp-Session-Id": session, "MCP-Protocol-Version": "2025-06-18"}
                )
            received, raw = self.post(
                self.config["baseUrl"].rstrip("/") + "/mcp", body, headers
            )
            return received, decode_json(received, raw)

        def initialize():
            headers, result = send(
                {
                    "jsonrpc": "2.0",
                    "id": 0,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2025-06-18",
                        "capabilities": {},
                        "clientInfo": {"name": "ciel-task-broker", "version": "1"},
                    },
                }
            )
            if (
                not result
                or "error" in result
                or result["result"]["protocolVersion"] != "2025-06-18"
            ):
                raise ValueError("T3 MCP initialization was not accepted")
            self.session = next(
                (v for k, v in headers.items() if k.lower() == "mcp-session-id"), None
            )
            if not self.session:
                raise ValueError("T3 MCP returned no transport session")
            send(
                {"jsonrpc": "2.0", "method": "notifications/initialized"}, self.session
            )

        if self.session is None:
            initialize()
        body = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
        try:
            _, result = send(body, self.session)
        except HTTPError as exc:
            if exc.code != 404:
                raise
            # Transport sessions may disappear on a T3 restart. Auth identity stays.
            initialize()
            _, result = send(body, self.session)
        if not result or "error" in result or "result" not in result:
            raise ValueError("T3 MCP request failed; no success assumed")
        return result["result"]

    def tools(self):
        """Tool names this T3 server offers to the broker's own MCP session."""
        if self.offered is None:
            listed = self.request("tools/list", {})
            self.offered = {tool["name"] for tool in listed.get("tools", [])}
        return self.offered

    def call(self, name, args, key=None):
        mutation = is_mutation(name, args)
        if name not in READS | WRITES or mutation and key is None:
            raise ValueError(
                "Unsupported MCP operation or missing durable mutation key"
            )
        digest = hashlib.sha256(
            json.dumps([name, args], sort_keys=True).encode()
        ).hexdigest()
        if key:
            row = self.store.db.execute(
                "SELECT * FROM mcp_calls WHERE key=?", (key,)
            ).fetchone()
            if row and row["digest"] != digest:
                raise ValueError(
                    "MCP operation key already belongs to different arguments"
                )
            if row and row["result"] is not None:
                return json.loads(row["result"])
            generation = self.auth.credentials()["generation"]
            if row and row["generation"] != generation:
                raise ValueError(
                    "MCP result uncertain across a new login; reconcile the existing task before retrying"
                )
            self.store.db.execute(
                "INSERT OR IGNORE INTO mcp_calls VALUES(?,?,?,NULL)",
                (key, digest, generation),
            )
            self.store.db.commit()
        self.mutation_generation = generation if key else None
        try:
            result = self.request("tools/call", {"name": name, "arguments": args})
        finally:
            self.mutation_generation = None
        if result.get("isError"):
            # Avoid echoing server errors that might contain sensitive tool arguments.
            raise ValueError("T3 MCP tool refused the operation; no success assumed")
        value = result.get("structuredContent")
        if value is None:
            value = json.loads(
                "".join(
                    p.get("text", "")
                    for p in result.get("content", [])
                    if p["type"] == "text"
                )
            )
        if key:
            self.store.db.execute(
                "UPDATE mcp_calls SET result=? WHERE key=?", (json.dumps(value), key)
            )
            self.store.db.commit()
        return value
