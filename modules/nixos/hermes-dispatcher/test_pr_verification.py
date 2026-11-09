import unittest
from pr_verification import verify


class PrVerificationTests(unittest.TestCase):
    link = {
        "url": "https://github.com/owner/repo/pull/1",
        "repository": "owner/repo",
        "number": 1,
    }

    def check(self, details, threads=None):
        values = iter(details)

        def rpc(method, ref):
            return (
                next(values)
                if method == "pullRequests.detail"
                else {"reviewThreads": threads or [], "reviewThreadsTruncated": False}
            )

        return verify(rpc, "project", [self.link])

    def test_green_requires_stable_head_and_actual_successful_checks(self):
        detail = {
            "headSha": "abc",
            "url": self.link["url"],
            "state": "open",
            "isDraft": False,
            "mergeability": "mergeable",
            "checks": [{"name": "test", "status": "success", "required": True}],
        }
        self.assertEqual(self.check([detail, detail])["state"], "ready")
        self.assertEqual(
            self.check([detail, {**detail, "headSha": "def"}])["state"], "pending"
        )
        self.assertEqual(
            self.check([{**detail, "checks": []}] * 2)["state"], "unverified"
        )
        self.assertEqual(
            self.check([detail, detail], [{"isResolved": False}])["state"], "failed"
        )
