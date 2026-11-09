"""Policy-facing adapter: T3 controls use MCP; only quota/forge reads use RPC."""

SUPPLEMENT_READS = {
    "subscribeServerConfig",
    "pullRequests.detail",
    "pullRequests.activity",
    "pullRequests.summary",
}


class T3Backend:
    def __init__(self, native, supplement):
        self.native, self.supplement = native, supplement

    def __call__(self, operation, payload=None, *, first=False):
        payload = payload or {}
        if operation in SUPPLEMENT_READS:
            return self.supplement(operation, payload, first=first)
        if operation == "orchestration.subscribeShell":
            projects, cursor, seen = [], None, set()
            while True:
                args = {
                    "limit": 100,
                    **({"cursor": cursor} if cursor is not None else {}),
                }
                page = self.native.call("t3_project_list", args)
                projects.extend(page["projects"])
                cursor = page["nextCursor"]
                if cursor is None:
                    return {"kind": "snapshot", "snapshot": {"projects": projects}}
                if cursor in seen:
                    raise ValueError("T3 project pagination did not advance")
                seen.add(cursor)
        if operation == "orchestration.launchThread":
            args = {
                key: payload[key]
                for key in [
                    "projectId",
                    "title",
                    "modelSelection",
                    "runtimeMode",
                    "interactionMode",
                    "workspaceStrategy",
                ]
            }
            args.update(
                {
                    "clientRequestId": payload["commandId"],
                    "message": payload["initialMessage"]["text"],
                }
            )
            return self.native.call("t3_thread_launch", args, key=payload["commandId"])
        if operation == "orchestration.getThreadProjection":
            args = {
                "threadId": payload["threadId"],
                "view": "messages",
                "limit": 25,
                "maxCharsPerItem": 8000,
                "runLimit": 5,
            }
            items, cursor = [], None
            for _ in range(20):
                result = self.native.call("t3_thread_read", args)
                items.extend(result["items"])
                if not result.get("hasMore"):
                    break
                next_cursor = result["nextPosition"]
                if next_cursor is None or next_cursor == cursor:
                    raise ValueError("T3 thread pagination did not advance")
                cursor = next_cursor
                args = {**args, "afterPosition": cursor}
            else:
                raise ValueError(
                    "T3 task history exceeds the bounded read; no completion assumed"
                )
            runs = [{**run, "id": run["runId"]} for run in result["recentRuns"]]
            if runs and max(runs, key=lambda run: run["ordinal"])["status"] in {
                "failed",
                "waiting",
            }:
                current = self.native.call(
                    "t3_thread_configure", {"threadId": payload["threadId"]}
                )
                for run in runs:
                    run["modelSelection"] = current["modelSelection"]
            messages = [
                {"role": "assistant", "text": item["text"]}
                for item in items
                if item.get("type") == "assistant_message"
                and item.get("text")
                and item.get("status") not in {"running", "pending"}
                and item.get("runId")
                == (max(runs, key=lambda run: run["ordinal"])["id"] if runs else None)
            ]
            return {
                "thread": result["thread"],
                "runs": runs,
                "messages": messages,
                # This only permits a quota check. Recovery still requires fresh
                # positive exhaustion evidence; a pending user/approval request wins.
                "quota_recovery_eligible": result["thread"].get("status") == "waiting"
                and result["thread"].get("pendingRequestCount") == 0,
            }
        if operation == "orchestration.dispatchCommand":
            command, thread = payload["commandId"], payload["threadId"]
            if payload["type"] == "thread.stop":
                return self.native.call(
                    "t3_thread_interrupt",
                    {
                        "threadId": thread,
                        "clientRequestId": command,
                        "stop": True,
                        "reason": payload["reason"],
                    },
                    key=command,
                )
            if payload["type"] == "message.dispatch":
                selection = payload.get("modelSelection")
                if selection:
                    self.native.call(
                        "t3_thread_configure",
                        {"threadId": thread, "modelSelection": selection},
                        key=command + ":model",
                    )
                return self.native.call(
                    "t3_thread_send",
                    {
                        "threadId": thread,
                        "clientRequestId": command,
                        "message": payload["text"],
                        "mode": "queue",
                    },
                    key=command,
                )
        raise ValueError("Unsupported Ciel T3 operation; no internal API fallback")
