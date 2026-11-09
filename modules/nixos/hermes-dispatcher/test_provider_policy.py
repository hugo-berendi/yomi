from datetime import datetime, timezone, timedelta
import unittest
from provider_policy import exhausted, select_provider


class ProviderPolicyTests(unittest.TestCase):
    def provider(self, name, used):
        return {
            "instanceId": name,
            "enabled": True,
            "installed": True,
            "status": "ready",
            "usageLimits": {
                "checkedAt": datetime.now(timezone.utc).isoformat(),
                "windows": [{"usedPercent": used}],
            },
        }

    def test_confirmed_limit_uses_existing_claude_subscription(self):
        providers = [self.provider("codex", 100), self.provider("claudeAgent", 40)]
        chosen = select_provider(
            providers, "standard", {"standard": {"model": "sol", "effort": "medium"}}
        )
        self.assertEqual(chosen["instanceId"], "claudeAgent")
        self.assertEqual(chosen["model"], "claude-sonnet-5-5")
        providers[1]["usageLimits"]["windows"][0]["usedPercent"] = 100
        self.assertIsNone(select_provider(providers, "standard", {}))

    def test_stale_or_unknown_quota_is_not_reported_as_exhausted(self):
        p = self.provider("codex", 100)
        p["usageLimits"]["checkedAt"] = (
            datetime.now(timezone.utc) - timedelta(hours=1)
        ).isoformat()
        self.assertFalse(exhausted(p))
        self.assertFalse(exhausted({}))

    def test_disabled_or_paid_provider_is_never_selected(self):
        p = self.provider("claudeAgent_claude_azure_foundry", 0)
        self.assertIsNone(select_provider([p], "standard", {}))
