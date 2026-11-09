"""Use only existing subscriptions and trustworthy quota observations."""

from datetime import datetime, timezone


def codex_selection(route):
    # T3's ProviderOptionSelections is an array of id/value pairs, not a map.
    return {
        "instanceId": "codex",
        "model": route["model"],
        "options": [
            {"id": "reasoningEffort", "value": route["effort"]},
            {"id": "serviceTier", "value": "default"},
        ],
    }


def exhausted(provider, now=None):
    now = now or datetime.now(timezone.utc)
    limits = provider.get("usageLimits") or {}
    try:
        checked = datetime.fromisoformat(limits["checkedAt"].replace("Z", "+00:00"))
        if not 0 <= (now - checked).total_seconds() <= 600:
            return False
    except (KeyError, ValueError, TypeError):
        return False
    for window in limits.get("windows", []):
        if window.get("usedPercent", 0) < 100:
            continue
        reset = window.get("resetsAt")
        if reset:
            try:
                if datetime.fromisoformat(reset.replace("Z", "+00:00")) <= now:
                    continue
            except (ValueError, TypeError):
                pass
        return True
    return False


def known_available(provider):
    limits = provider.get("usageLimits") or {}
    try:
        age = (
            datetime.now(timezone.utc)
            - datetime.fromisoformat(limits["checkedAt"].replace("Z", "+00:00"))
        ).total_seconds()
        windows = limits["windows"]
        return (
            provider.get("status") == "ready"
            and 0 <= age <= 600
            and bool(windows)
            and all(w["usedPercent"] < 100 for w in windows)
        )
    except (KeyError, ValueError, TypeError):
        return False


def select_provider(providers, tier, routes):
    indexed = {p["instanceId"]: p for p in providers}
    for provider_id in ("codex", "claudeAgent"):
        p = indexed.get(provider_id, {})
        if (
            not p.get("enabled")
            or not p.get("installed")
            or p.get("status") != "ready"
            or exhausted(p)
        ):
            continue
        if provider_id == "codex":
            return codex_selection(routes[tier])
        return {
            "instanceId": provider_id,
            "model": "claude-haiku-5-5" if tier == "routine" else "claude-sonnet-5-5",
            "options": [
                {
                    "id": "effort",
                    "value": {
                        "routine": "low",
                        "standard": "medium",
                        "complex": "high",
                    }[tier],
                }
            ],
        }
    return None
