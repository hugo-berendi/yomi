"""Small stdio MCP facade; no arbitrary shell, RPC, project paths or credentials."""

import json
from pathlib import Path
import sys

from broker_client import broker_call
from local_tools import LocalTools


def tool(name, description, properties=None, required=None):
    reads = {
        "ciel_projects",
        "ciel_task_status",
        "ciel_skills_list",
        "ciel_skill_read",
        "ciel_memory_read",
    }
    return {
        "name": name,
        "description": description,
        "annotations": {
            "readOnlyHint": name in reads,
            "destructiveHint": name == "ciel_stop_task",
            "idempotentHint": True,
            "openWorldHint": name
            not in {
                "ciel_skills_list",
                "ciel_skill_read",
                "ciel_memory_read",
                "ciel_memory_write",
            },
        },
        "inputSchema": {
            "type": "object",
            "properties": properties or {},
            "required": required or [],
            "additionalProperties": False,
        },
    }


STRING = {"type": "string"}
TOOLS = [
    tool("ciel_projects", "List registered T3 repositories authorized for Ciel."),
    tool(
        "ciel_start_task",
        "Queue one authorized coding problem through T3. Reuse task_key on retries. Stops before merge/deploy. Omit room_id to discover the unique encrypted owner DM automatically.",
        {k: STRING for k in ["project_id", "task_key", "description", "room_id"]},
        ["project_id", "task_key", "description"],
    ),
    tool(
        "ciel_task_status",
        "Read a Ciel-owned task. A completed agent run is not proof of a green PR.",
        {"task_key": STRING},
        ["task_key"],
    ),
    tool(
        "ciel_task_reply",
        "Send Hugo's clarification to a Ciel-owned task. Reuse request_id on retries.",
        {k: STRING for k in ["task_key", "request_id", "message"]},
        ["task_key", "request_id", "message"],
    ),
    tool(
        "ciel_stop_task",
        "Stop a Ciel-owned task and delegated children, preserving its worktree.",
        {k: STRING for k in ["task_key", "request_id"]},
        ["task_key", "request_id"],
    ),
    tool(
        "ciel_skills_list",
        "Read Hugo's installed skill catalog directly, without a shell sandbox.",
    ),
    tool(
        "ciel_skill_read",
        "Read SKILL.md or a referenced resource from one installed skill.",
        {"skill": STRING, "path": STRING},
        ["skill"],
    ),
    tool(
        "ciel_memory_read",
        "Read curated preferences or project facts with their revision token.",
        {"kind": {"enum": ["preferences", "projects"]}},
        ["kind"],
    ),
    tool(
        "ciel_memory_write",
        "Replace curated English memory entries after reading them. Facts need source and date; never save secrets or foreign conversations.",
        {
            "kind": {"enum": ["preferences", "projects"]},
            "etag": STRING,
            "entries": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {k: STRING for k in ["fact", "source", "date"]},
                    "required": ["fact", "source", "date"],
                    "additionalProperties": False,
                },
            },
        },
        ["kind", "etag", "entries"],
    ),
]
OPERATIONS = dict(
    zip(
        [
            "ciel_projects",
            "ciel_start_task",
            "ciel_task_status",
            "ciel_task_reply",
            "ciel_stop_task",
        ],
        ["projects", "start", "status", "reply", "stop"],
    )
)


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    local = LocalTools(config)
    for line in sys.stdin:
        if len(line) > 100000:
            raise ValueError("MCP request too large")
        request = json.loads(line)
        if "id" not in request:
            continue
        try:
            method = request["method"]
            if method == "initialize":
                result = {
                    "protocolVersion": request.get("params", {}).get(
                        "protocolVersion", "2024-11-05"
                    ),
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "ciel", "version": "1"},
                }
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": TOOLS}
            elif method == "tools/call":
                params = request["params"]
                name, args = params["name"], params.get("arguments", {})
                schema = next(
                    (t["inputSchema"] for t in TOOLS if t["name"] == name), None
                )
                if (
                    not schema
                    or not isinstance(args, dict)
                    or set(args) - set(schema["properties"])
                    or set(schema["required"]) - set(args)
                ):
                    raise ValueError("Unknown tool or invalid arguments")
                value = (
                    broker_call(config["socket"], OPERATIONS[name], args)
                    if name in OPERATIONS
                    else local.handle(name, args)
                )
                result = {
                    "content": [
                        {
                            "type": "text",
                            "text": value
                            if isinstance(value, str)
                            else json.dumps(value, ensure_ascii=False),
                        }
                    ]
                }
            else:
                raise ValueError("Unsupported MCP method")
        except (ValueError, FileNotFoundError) as exc:
            result = {"isError": True, "content": [{"type": "text", "text": str(exc)}]}
        except Exception:
            result = {
                "isError": True,
                "content": [
                    {
                        "type": "text",
                        "text": "Ciel tool unavailable; do not assume success or repeat with a new operation key.",
                    }
                ],
            }
        print(
            json.dumps({"jsonrpc": "2.0", "id": request["id"], "result": result}),
            flush=True,
        )


if __name__ == "__main__":
    main()
