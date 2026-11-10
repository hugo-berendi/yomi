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
        "ciel_tasks",
        "ciel_task_requests",
        "ciel_task_history",
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
# Explicit model choice. All three together or none; the broker checks an
# allowlist and T3's live catalog and reads the stored configuration back
# before any run starts. A wish in the description text selects nothing.
MODEL = {
    "provider": {"enum": ["claudeAgent", "codex"]},
    "model": STRING,
    "effort": {"enum": ["low", "medium", "high"]},
}
TOOLS = [
    tool("ciel_projects", "List registered T3 repositories authorized for Ciel."),
    tool(
        "ciel_start_task",
        "Queue one authorized coding problem through T3. Reuse task_key on retries. Stops before merge/deploy. intent defaults to implementation_pr (PR with exact-head checks and review is required); pass readonly_test only when Hugo explicitly asked for a test or inspection that must change nothing: the worker then makes no commit, PR or CI run and the task ends with its observed outcome, unverified by the forge. Omit room_id to discover the unique encrypted owner DM automatically. Independent tasks run in parallel, each in its own worktree, up to the broker's slot limit; the rest queue and start by themselves. Set depends_on (task keys that must be ready or merged first) or a shared serial_group (never run together) when tasks touch the same work. Pass provider, model and effort together only when Hugo chose them; the task then never runs under another model or effort and waits instead of substituting. Events (questions, completion, failure) reach you automatically as internal events; no watching or polling is needed.",
        {
            **{
                k: STRING
                for k in [
                    "project_id",
                    "task_key",
                    "description",
                    "room_id",
                    "serial_group",
                ]
            },
            "depends_on": {"type": "array", "items": STRING},
            "intent": {"enum": ["implementation_pr", "readonly_test"]},
            **MODEL,
        },
        ["project_id", "task_key", "description"],
    ),
    tool(
        "ciel_task_requests",
        "List open structured worker questions of Ciel-owned tasks, with task, thread, run, a short request handle and the questions. Approvals are not listed; only Hugo grants them in T3.",
        {"task_key": STRING},
    ),
    tool(
        "ciel_task_answer",
        "Answer one open worker question through T3's input-request interface. This continues the same run and never starts a new one. Answer every question of the request (keys are the question ids; a list only for multi-select). Reuse request_id on retries. The result states whether T3 accepted it and the run continues.",
        {
            "task_key": STRING,
            "request": STRING,
            "request_id": STRING,
            "answers": {
                "type": "object",
                "additionalProperties": {
                    "anyOf": [STRING, {"type": "array", "items": STRING}]
                },
            },
        },
        ["task_key", "request", "request_id", "answers"],
    ),
    tool(
        "ciel_task_history",
        "Read one bounded page of a Ciel-owned task's thread messages. Page with after_position = next_position.",
        {"task_key": STRING, "after_position": {"type": "integer", "minimum": 0}},
        ["task_key"],
    ),
    tool(
        "ciel_task_solve",
        "Mark a Ciel-owned T3 thread solved. Succeeds only when the run finished, no question or follow-up is open, and the forge shows the PR merged or green on its exact head with an approving review. Otherwise returns the blockers. Stopped tasks stay stopped.",
        {k: STRING for k in ["task_key", "request_id"]},
        ["task_key", "request_id"],
    ),
    tool(
        "ciel_task_status",
        "Read a Ciel-owned task. A completed agent run is not proof of a green PR.",
        {"task_key": STRING},
        ["task_key"],
    ),
    tool(
        "ciel_tasks",
        "List every Ciel-owned task with slot usage, queue reasons, observation errors and undelivered owner notices. Queued, preparing or running is not a verified result.",
    ),
    tool(
        "ciel_task_reply",
        "Send an addition to a Ciel-owned task as a thread message. For a task still waiting to start, it is stored and included in the first prompt. Refused while a worker question is open; use ciel_task_answer then. provider/model/effort (all three) deliberately change the thread's configuration before sending. Reuse request_id on retries. A task parked on a blocker (signing, permission, quota, decision) accepts a reply only with authorizes_blocker set to the fingerprint from its notice, after Hugo explicitly answered; worker text never counts. One accepted reply continues it once.",
        {
            **{
                k: STRING
                for k in ["task_key", "request_id", "message", "authorizes_blocker"]
            },
            **MODEL,
        },
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
            "ciel_tasks",
            "ciel_task_reply",
            "ciel_stop_task",
            "ciel_task_requests",
            "ciel_task_answer",
            "ciel_task_history",
            "ciel_task_solve",
        ],
        [
            "projects",
            "start",
            "status",
            "tasks",
            "reply",
            "stop",
            "requests",
            "answer",
            "history",
            "solve",
        ],
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
