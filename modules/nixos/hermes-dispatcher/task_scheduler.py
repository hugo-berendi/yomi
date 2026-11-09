"""Slot accounting and queue eligibility for Ciel's coding tasks.

Every task runs in its own T3 worktree, so independent tasks may run side by
side. The scheduler only decides when a queued task may start; it never starts
anything itself.
"""

import json

TERMINAL = {
    "completed",
    "failed",
    "cancelled",
    "interrupted",
    "rolled_back",
    "stopped",
    "ready",
    "merged",
    "needs_user",
}
# Statuses in which a task owns no running agent and waits for something else:
# a queue slot, a quota window, CI, a follow-up slot or a decision from Hugo.
# Counting them as running would let one idle task starve the whole queue.
NO_SLOT = TERMINAL | {
    "queued",
    "waiting_quota",
    "waiting_followup",
    "verifying",
    "quota_paused",
    "waiting",
}
SATISFIED = {"ready", "merged"}
DEAD = {"failed", "cancelled", "interrupted", "rolled_back", "stopped"}
DEFAULT_LIMIT = 2
MAX_LIMIT = 4


def limit(config):
    value = config.get("maxConcurrentTasks", DEFAULT_LIMIT)
    return max(1, min(MAX_LIMIT, value if isinstance(value, int) else DEFAULT_LIMIT))


def holds_slot(task):
    return task["last_status"] not in NO_SLOT


def blocker(task, tasks):
    """Why a queued task cannot start yet, or None. `dead` marks a dependency that will not complete."""
    by_key = {t["task_key"]: t for t in tasks}
    for key in json_list(task.get("depends_on")):
        dependency = by_key.get(key)
        if dependency is None or dependency["last_status"] in DEAD:
            return {"kind": "dead", "task": key}
        if dependency["last_status"] not in SATISFIED:
            return {"kind": "dependency", "task": key}
    group = task.get("serial_group")
    if group:
        for other in tasks:
            if (
                other["task_key"] != task["task_key"]
                and other.get("serial_group") == group
                and holds_slot(other)
            ):
                return {"kind": "serial_group", "task": other["task_key"]}
    return None


def json_list(value):
    if not value:
        return []
    try:
        result = json.loads(value)
    except (TypeError, ValueError):
        return []
    return [v for v in result if isinstance(v, str)] if isinstance(result, list) else []


def backoff(failures):
    """Seconds until the next attempt after consecutive observation failures."""
    return min(30 * 2 ** max(failures, 1), 600)
